import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../model/notifiers.dart';
import '../../model/app_item_type.dart';
import '../protocol/network_message.dart';
import '../protocol/network_room.dart';
import 'base/game_engine.dart';
import 'net_real_engine.dart';
import 'net_turn_engine.dart';
import 'net_multi_turn_engine.dart';
import 'socket_client.dart';

enum RoomMatchPhase { idle, sending, matching, matched }

/// 认证后的房间消息处理器。连接归 SocketClient 所有，本类只负责聊天与匹配。
///
/// 游戏房间使用子类；子类与本类共享房间聊天记录，另持有独立的对局聊天记录。
class RoomChatEngine {
  static final Expando<RoomChatEngine> _engines = Expando<RoomChatEngine>();

  /// 仅在认证后按服务端确认的类型选引擎；同一连接始终对应同一个处理器。
  static RoomChatEngine forClient(SocketClient client) {
    final existing = _engines[client];
    if (existing != null) return existing;
    if (!client.isJoined) throw StateError('Room is not authenticated');
    return switch (client.gameMode) {
      RoomGameMode.none => RoomChatEngine(client),
      RoomGameMode.turn =>
        OnlineItemType.tryFromRoomType(client.roomType)?.cooperativeTurns ==
                true
            ? NetMultiTurnEngine(client)
            : NetTurnEngine(client),
      RoomGameMode.real => NetRealEngine(client),
    };
  }

  final SocketClient client;
  final messageList = ListNotifier<NetworkMessage>([]);
  final Set<void Function(NetworkMessage)> _gameListeners = {};
  final List<NetworkMessage> _pendingGameMessages = [];
  bool _waitingForGame = false;
  bool _disposed = false;

  /// 搜索状态属于房间引擎，不由连接或额外的短期对象持有。
  final matchPhase = ValueNotifier(RoomMatchPhase.idle);
  final LinkedHashSet<int> _searchCandidates = LinkedHashSet<int>();
  // 服务端先补发已有搜索者，再回环本人的搜索，按接收顺序记录本次准备先后。
  final LinkedHashSet<int> _searchOrder = LinkedHashSet<int>();
  final Set<int> _triedCandidates = {};
  Timer? _candidateTimer;
  Timer? _cooperativeOfferTimer;
  int? _candidateId;
  String? _candidateOfferId;
  String? _candidateGameId;
  bool _offered = false;
  MatchConfirmationPhase? _expectedConfirmation;
  final Set<String> _candidateDeliveries = {};
  final LinkedHashSet<(int, String, String)> _abortedOffers =
      LinkedHashSet<(int, String, String)>();
  int _nextGameId = 0;
  String? _matchedOfferId;
  String? _matchedGameId;
  int matchedOpponentId = 0;
  bool matchInitiated = false;

  /// 邀请事务标识；实时中途加入时不同邀请仍可属于同一个 gameId。
  String? get matchedOfferId => _matchedOfferId;

  /// 此次入局确认的对局 ID，由发起方提供、双方逐阶段校验。
  String? get matchedGameId => _matchedGameId;
  int get identity => client.identity;
  String get userName => client.userName;
  bool get isJoined => client.isJoined;
  int get roomType => client.roomType;
  String get roomName => client.roomName;
  RoomGameMode get gameMode => client.gameMode;
  ValueNotifier<Map<int, String>> get members => client.members;
  ValueNotifier<int> get identityNotifier => client.identityNotifier;
  ValueNotifier<RoomStatus> get status => client.status;
  bool get _cooperativeTurns =>
      OnlineItemType.tryFromRoomType(roomType)?.cooperativeTurns == true;

  RoomChatEngine(this.client) {
    if (!client.isJoined) throw StateError('Room is not authenticated');
    client.attachMessageProcessor(_receive);
    client.identityNotifier.addListener(_identityChanged);
    client.deliveryFailure.addListener(_deliveryFailed);
    client.deliveryConfirmed.addListener(_deliveryConfirmed);
    _engines[client] = this;
  }

  void _identityChanged() {
    if (identity == 0) cancelMatching();
  }

  void _receive(NetworkMessage message) {
    if (_disposed) return;
    _receiveMatching(message);
    if (message.isRoomMessage &&
        const {
          MessageType.notify,
          MessageType.text,
          MessageType.image,
          MessageType.file,
        }.contains(message.type)) {
      messageList.add(message);
    }

    // 匹配确认后、对局页面注册前到达的局内消息不能丢失。
    final notice = message.type == MessageType.notify
        ? RoomNotification.tryFromContent(message.content)
        : null;
    final pendingRoomEvent =
        (message.id == 0 &&
            (notice?.type == NoticeType.left ||
                notice?.type == NoticeType.close)) ||
        (message.type == MessageType.search && message.isRoomMessage);
    if (_waitingForGame &&
        (pendingRoomEvent ||
            (!message.isRoomMessage &&
                message.gameId == (_candidateGameId ?? _matchedGameId) &&
                const {
                  MessageType.resource,
                  MessageType.sync,
                  MessageType.action,
                  MessageType.exit,
                  MessageType.publish,
                  MessageType.text,
                }.contains(message.type)))) {
      _pendingGameMessages.add(message);
    }
    for (final listener in List.of(_gameListeners)) {
      if (_gameListeners.contains(listener)) listener(message);
    }
  }

  void startMatching() {
    if (!isJoined ||
        gameMode == RoomGameMode.none ||
        matchPhase.value != RoomMatchPhase.idle) {
      return;
    }
    _waitingForGame = false;
    _pendingGameMessages.clear();
    _candidateId = null;
    _candidateOfferId = null;
    _candidateGameId = null;
    _matchedOfferId = null;
    _matchedGameId = null;
    _offered = false;
    _expectedConfirmation = null;
    _searchCandidates.clear();
    _searchOrder.clear();
    _triedCandidates.clear();
    matchedOpponentId = 0;
    matchInitiated = false;
    matchPhase.value = RoomMatchPhase.sending;
    client.sendNetworkMessage(MessageType.search, '');
  }

  void cancelMatching() {
    _cooperativeOfferTimer?.cancel();
    _cooperativeOfferTimer = null;
    _dropCandidate(retryOthers: false);
    if (matchPhase.value != RoomMatchPhase.idle &&
        matchPhase.value != RoomMatchPhase.matched &&
        client.isJoined) {
      client.sendNetworkMessage(MessageType.cancelSearch, '');
    }
    _candidateTimer?.cancel();
    _candidateTimer = null;
    _candidateId = null;
    _candidateOfferId = null;
    _candidateGameId = null;
    _matchedOfferId = null;
    _matchedGameId = null;
    _offered = false;
    _expectedConfirmation = null;
    _searchCandidates.clear();
    _searchOrder.clear();
    _triedCandidates.clear();
    matchedOpponentId = 0;
    matchInitiated = false;
    if (matchPhase.value != RoomMatchPhase.idle) {
      matchPhase.value = RoomMatchPhase.idle;
    }
    _pendingGameMessages.clear();
    _waitingForGame = false;
  }

  void openMatchedGame() {
    if (matchPhase.value == RoomMatchPhase.matched) {
      matchPhase.value = RoomMatchPhase.idle;
    }
  }

  void _receiveMatching(NetworkMessage message) {
    if (message.type == MessageType.notify && message.id == 0) {
      final notice = RoomNotification.tryFromContent(message.content);
      if (notice?.type == NoticeType.close) {
        cancelMatching();
      } else if (notice?.type == NoticeType.left) {
        _removeCandidate(notice!.memberId!);
      }
      return;
    }
    if (message.type == MessageType.cancelSearch) {
      _removeCandidate(message.id);
      return;
    }
    final confirmation = message.type == MessageType.confirm
        ? MatchConfirmation.tryParse(message.content)
        : null;
    if (confirmation?.phase == MatchConfirmationPhase.abort &&
        message.recipientIds.contains(identity) &&
        message.gameId != null) {
      _rememberAbort(message.id, message.gameId!, confirmation!.offerId);
      if (message.id == _candidateId &&
          message.gameId == _candidateGameId &&
          confirmation.offerId == _candidateOfferId) {
        _dropCandidate(retryOthers: true, sendAbort: false);
      } else if (message.id == matchedOpponentId &&
          message.gameId == _matchedGameId &&
          confirmation.offerId == _matchedOfferId) {
        // 包括已经切换到对局组件的入局撤销，但不能误伤另一局。
        cancelMatching();
        onMatchAborted();
      }
      return;
    }
    if (matchPhase.value == RoomMatchPhase.idle ||
        matchPhase.value == RoomMatchPhase.matched) {
      return;
    }
    if (message.type == MessageType.search && message.isRoomMessage) {
      _searchOrder.add(message.id);
      if (message.id == identity) {
        matchPhase.value = RoomMatchPhase.matching;
      } else {
        _searchCandidates.add(message.id);
        // 重新搜索表示愿意重新接受请求，撤销先前的拒绝/超时记忆。
        _triedCandidates.remove(message.id);
      }
      _offerNextCandidate();
      return;
    }
    if (message.type == MessageType.reject &&
        message.recipientIds.contains(identity) &&
        message.id == _candidateId &&
        message.gameId == _candidateGameId &&
        message.content == 'busy:$_candidateOfferId') {
      _dropCandidate(retryOthers: true);
      return;
    }
    if (message.type == MessageType.match &&
        message.recipientIds.length == 1 &&
        message.id != identity &&
        message.recipientIds.contains(identity) &&
        message.messageId != null &&
        message.gameId != null &&
        !_abortedOffers.contains((
          message.id,
          message.gameId!,
          message.messageId!,
        )) &&
        matchPhase.value == RoomMatchPhase.matching) {
      if (_candidateId == message.id &&
          !_offered &&
          _candidateOfferId == message.messageId) {
        // 重复邀请由连接层去重；不重置已经推进的事务阶段。
        return;
      }
      if (_candidateId == message.id &&
          _offered &&
          _searchesBefore(identity, message.id)) {
        // 双向邀请中较早搜索者保持发起方，不能被后来搜索的小 ID 玩家抢占。
        return;
      }
      // 双方同时出价时按搜索先后确定发起方，另一方让出候选锁。
      if (_candidateId != null && (_candidateId != message.id || !_offered)) {
        client.sendNetworkMessage(
          MessageType.reject,
          'busy:${message.messageId}',
          recipientIds: {message.id},
          gameId: message.gameId,
        );
        return;
      }
      // 双向邀请时让出自己那次邀请，撤销其重试而不是撤销对方的新邀请。
      _cancelCandidateDeliveries();
      _candidateTimer?.cancel();
      _candidateId = message.id;
      _candidateOfferId = message.messageId;
      _candidateGameId = message.gameId;
      _offered = false;
      _expectedConfirmation = MatchConfirmationPhase.commit;
      _sendCandidateConfirmation(MatchConfirmationPhase.accept);
      return;
    }
    if (confirmation == null ||
        _candidateId == null ||
        message.id != _candidateId ||
        !message.recipientIds.contains(identity) ||
        message.gameId != _candidateGameId ||
        confirmation.offerId != _candidateOfferId ||
        confirmation.phase != _expectedConfirmation) {
      return;
    }
    final candidate = _candidateId!;
    // accept/commit 只预留；ready/start 确认双方仍持有同一邀请。
    // 发起方收到 joined 后提交，应答方等自己的 joined 被确认后才打开页面。
    switch (confirmation.phase) {
      case MatchConfirmationPhase.accept when _offered:
        _expectedConfirmation = MatchConfirmationPhase.ready;
        _sendCandidateConfirmation(MatchConfirmationPhase.commit);
      case MatchConfirmationPhase.commit when !_offered:
        _expectedConfirmation = MatchConfirmationPhase.start;
        _sendCandidateConfirmation(MatchConfirmationPhase.ready);
      case MatchConfirmationPhase.ready when _offered:
        _expectedConfirmation = MatchConfirmationPhase.joined;
        _sendCandidateConfirmation(MatchConfirmationPhase.start);
      case MatchConfirmationPhase.start when !_offered:
        _expectedConfirmation = MatchConfirmationPhase.joined;
        _waitingForGame = true;
        _sendCandidateConfirmation(MatchConfirmationPhase.joined);
      case MatchConfirmationPhase.joined when _offered:
        _completeMatch(candidate, initiated: true);
      default:
        break;
    }
  }

  void _sendCandidateConfirmation(MatchConfirmationPhase phase) {
    _cancelCandidateDeliveries();
    final id = client.sendNetworkMessage(
      MessageType.confirm,
      MatchConfirmation(phase, _candidateOfferId!).content,
      recipientIds: {_candidateId!},
      gameId: _candidateGameId,
    );
    if (id != null) _candidateDeliveries.add(id);
    _watchCandidate();
  }

  void _cancelCandidateDeliveries() {
    for (final id in _candidateDeliveries) {
      client.cancelDelivery(id, gameId: _candidateGameId);
    }
    _candidateDeliveries.clear();
  }

  void _rememberAbort(int memberId, String gameId, String offerId) {
    _abortedOffers.add((memberId, gameId, offerId));
    if (_abortedOffers.length > 256) {
      _abortedOffers.remove(_abortedOffers.first);
    }
  }

  void _deliveryConfirmed() {
    final message = client.deliveryConfirmed.value;
    if (!_offered &&
        _candidateId != null &&
        _expectedConfirmation == MatchConfirmationPhase.joined &&
        message?.gameId == _candidateGameId &&
        (message?.recipientIds.contains(_candidateId) ?? false) &&
        message?.type == MessageType.confirm &&
        message?.content == 'joined:$_candidateOfferId' &&
        _candidateDeliveries.contains(message?.messageId)) {
      _completeMatch(_candidateId!, initiated: false);
    }
  }

  void _offerNextCandidate() {
    if (_cooperativeTurns) {
      if (matchPhase.value != RoomMatchPhase.matching || _candidateId != null) {
        return;
      }
      // 合作局优先接受正在进行的队伍邀请；短暂汇集准备者，再由较早搜索者发起。
      // 否则四人同时准备容易先拆成两份互不相关的双人棋盘。
      _cooperativeOfferTimer ??= Timer(const Duration(milliseconds: 120), () {
        _cooperativeOfferTimer = null;
        _offerCandidateNow();
      });
      return;
    }
    _offerCandidateNow();
  }

  void _offerCandidateNow() {
    if (matchPhase.value != RoomMatchPhase.matching || _candidateId != null) {
      return;
    }
    if (_cooperativeTurns &&
        _searchCandidates.any(
          (id) =>
              _searchesBefore(id, identity) && !_triedCandidates.contains(id),
        )) {
      return;
    }
    for (final id in _searchCandidates) {
      if (id == identity || _triedCandidates.contains(id)) continue;
      _candidateId = id;
      _offered = true;
      _expectedConfirmation = MatchConfirmationPhase.accept;
      _candidateGameId =
          '$identity-${DateTime.now().microsecondsSinceEpoch}-${++_nextGameId}';
      _triedCandidates.add(id);
      _candidateOfferId = client.sendNetworkMessage(
        MessageType.match,
        '',
        recipientIds: {id},
        gameId: _candidateGameId,
      );
      if (_candidateOfferId != null) {
        _candidateDeliveries.add(_candidateOfferId!);
      }
      _watchCandidate();
      return;
    }
  }

  bool _searchesBefore(int first, int second) {
    final order = _searchOrder.toList();
    final firstIndex = order.indexOf(first);
    final secondIndex = order.indexOf(second);
    // 只有缺少搜索记录时才以 ID 兜底，正常匹配严格按本次搜索先后处理。
    if (firstIndex < 0 || secondIndex < 0) return first < second;
    return firstIndex < secondIndex;
  }

  void _watchCandidate() {
    _candidateTimer?.cancel();
    // 邀请还没得到响应时尽快换人；进入 accept/commit 阶段后，必须
    // 覆盖连接层完整的 ACK 重发窗口，否则 2 秒超时会先于重发把配对拆散。
    var timeout = const Duration(seconds: 2);
    if (!_offered || _expectedConfirmation != MatchConfirmationPhase.accept) {
      final confirmationTimeout =
          client.deliveryRetryWindow + const Duration(seconds: 1);
      if (confirmationTimeout > timeout) timeout = confirmationTimeout;
    }
    _candidateTimer = Timer(timeout, () {
      _dropCandidate(retryOthers: true);
    });
  }

  void _dropCandidate({required bool retryOthers, bool sendAbort = true}) {
    final old = _candidateId;
    if (old == null) return;
    final needsSearch =
        !_offered && _expectedConfirmation == MatchConfirmationPhase.joined;
    _cancelCandidateDeliveries();
    if (_candidateGameId != null && _candidateOfferId != null) {
      _rememberAbort(old, _candidateGameId!, _candidateOfferId!);
      if (sendAbort) {
        notifyMatchAbort(
          old,
          _candidateGameId!,
          _candidateOfferId!,
          _pendingGameMessages,
        );
      }
    }
    _candidateTimer?.cancel();
    _candidateTimer = null;
    _candidateId = null;
    _candidateOfferId = null;
    _candidateGameId = null;
    _offered = false;
    _expectedConfirmation = null;
    _pendingGameMessages.clear();
    _waitingForGame = false;
    _triedCandidates.add(old);
    if (retryOthers) {
      if (needsSearch) client.sendNetworkMessage(MessageType.search, '');
      _offerNextCandidate();
    }
  }

  void _removeCandidate(int id) {
    _searchCandidates.remove(id);
    _searchOrder.remove(id);
    _triedCandidates.remove(id);
    if (_candidateId == id) _dropCandidate(retryOthers: true);
    if (_cooperativeTurns) _offerNextCandidate();
  }

  void _completeMatch(int opponent, {required bool initiated}) {
    _cooperativeOfferTimer?.cancel();
    _cooperativeOfferTimer = null;
    _candidateTimer?.cancel();
    _candidateTimer = null;
    _cancelCandidateDeliveries();
    _matchedOfferId = _candidateOfferId;
    _matchedGameId = _candidateGameId;
    _candidateId = null;
    _candidateOfferId = null;
    _candidateGameId = null;
    if (_cooperativeTurns && initiated) {
      // 首次匹配期间到达的其他准备请求，移交给即将启动的多人发布者处理。
      // 这些成员还没入局，仍需走完整的预留/提交事务，不能直接放进名单。
      for (final id in _searchCandidates) {
        if (id == identity ||
            id == opponent ||
            !members.value.containsKey(id)) {
          continue;
        }
        _pendingGameMessages.add(
          NetworkMessage(
            id: id,
            source: members.value[id]!,
            type: MessageType.search,
            content: '',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    }
    _searchCandidates.clear();
    _searchOrder.clear();
    _triedCandidates.clear();
    matchedOpponentId = opponent;
    matchInitiated = initiated;
    _waitingForGame = true;
    matchPhase.value = RoomMatchPhase.matched;
  }

  void _deliveryFailed() {
    final message = client.deliveryFailure.value;
    if (message == null || !message.needsAck) return;
    if (_candidateOfferId != null &&
        message.gameId == _candidateGameId &&
        message.recipientIds.contains(_candidateId) &&
        _candidateDeliveries.contains(message.messageId)) {
      _dropCandidate(retryOthers: true);
    }
  }

  /// 游戏子类结束被撤销的入局；房间连接和大厅聊天继续保留。
  void onMatchAborted() {}

  /// 默认撤销给邀请方；实时子类还能从暂存资源的路由找到其他已知参与者。
  void notifyMatchAbort(
    int inviterId,
    String gameId,
    String offerId,
    Iterable<NetworkMessage> pendingMessages,
  ) => client.sendNetworkMessage(
    MessageType.confirm,
    MatchConfirmation(MatchConfirmationPhase.abort, offerId).content,
    recipientIds: {inviterId},
    gameId: gameId,
  );

  void addGameMessageListener(void Function(NetworkMessage) listener) {
    _gameListeners.add(listener);
    if (!_waitingForGame) return;
    _waitingForGame = false;
    final pending = List<NetworkMessage>.of(_pendingGameMessages);
    _pendingGameMessages.clear();
    for (final message in pending) {
      if (_gameListeners.contains(listener)) listener(message);
    }
  }

  void removeGameMessageListener(void Function(NetworkMessage) listener) =>
      _gameListeners.remove(listener);

  /// 房间页面卸载时结束借用连接的对局；纯聊天室无需处理，不关闭连接或销毁 Manager。
  /// 应用只调用房间入口，无需依赖内部的局内生命周期 mixin。
  void finishActiveGame() {
    if (this case GameEngine game) game.finishGame();
  }

  void sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      client.sendNetworkMessage(MessageType.text, trimmed);
    }
  }

  void sendImageMessage(String data, {String? fileName, String? blurHash}) =>
      client.sendNetworkMessage(
        MessageType.image,
        jsonEncode({
          'data': data,
          if (fileName != null) 'name': fileName,
          if (blurHash != null) 'hash': blurHash,
        }),
      );

  void sendFileMessage(String name, int size, String data) =>
      client.sendNetworkMessage(
        MessageType.file,
        jsonEncode({'name': name, 'size': size, 'data': data}),
      );

  /// 引擎销毁只取消订阅；页面所有者决定何时关闭连接。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    client.identityNotifier.removeListener(_identityChanged);
    client.detachMessageProcessor(_receive);
    _gameListeners.clear();
    _pendingGameMessages.clear();
    _candidateTimer?.cancel();
    _cooperativeOfferTimer?.cancel();
    _cancelCandidateDeliveries();
    client.deliveryFailure.removeListener(_deliveryFailed);
    client.deliveryConfirmed.removeListener(_deliveryConfirmed);
    matchPhase.dispose();
    messageList.dispose();
    _engines[client] = null;
  }
}
