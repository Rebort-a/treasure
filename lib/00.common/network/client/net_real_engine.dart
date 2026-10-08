import 'dart:async';
import 'dart:convert';

import '../../game/step.dart';
import '../protocol/network_message.dart';
import 'game_engine.dart';
import 'room_chat_engine.dart';
import 'socket_client.dart';

/// 只保存发布者尚未提交的入局事务，不是独立连接或对局会话。
class _PendingJoin {
  final String offerId;
  MatchConfirmationPhase expected = MatchConfirmationPhase.accept;
  final Set<String> deliveries = {};
  Timer? timer;

  _PendingJoin(this.offerId);
}

/// 实时引擎直接维护参与者、发布者和资源同步，不再创建对局会话。
class NetRealEngine extends RoomChatEngine with GameEngine {
  int? _maxPlayers;
  void Function(int) _searchHandler = _noSearch;
  void Function(NetworkMessage) _resourceHandler = _noMessage;
  void Function(NetworkMessage) _syncHandler = _noMessage;
  void Function(NetworkMessage) _actionHandler = _noMessage;
  void Function(int) _exitHandler = _noSearch;
  final Map<int, String> _participants = {};
  final Map<int, _PendingJoin> _pendingJoins = {};
  final Map<int, String> _completedJoins = {};
  final Set<int> _publishVotes = {};
  int _rosterRevision = 0;
  int? publisherId;
  bool _awaitingResource = false;
  bool _disposed = false;
  Map<int, String> get participants => Map.unmodifiable(_participants);

  NetRealEngine(super.client);

  static NetRealEngine forClient(SocketClient client) {
    final engine = RoomChatEngine.forClient(client);
    if (engine is! NetRealEngine) {
      throw StateError('Real-time room is not authenticated');
    }
    return engine;
  }

  static void _noSearch(int id) {}
  static void _noMessage(NetworkMessage message) {}

  void configureGame({
    int? maxPlayers,
    required void Function(int) searchHandler,
    required void Function(NetworkMessage) resourceHandler,
    required void Function(NetworkMessage) syncHandler,
    required void Function(NetworkMessage) actionHandler,
    required void Function(int) exitHandler,
  }) {
    prepareGame();
    _maxPlayers = maxPlayers;
    _searchHandler = searchHandler;
    _resourceHandler = resourceHandler;
    _syncHandler = syncHandler;
    _actionHandler = actionHandler;
    _exitHandler = exitHandler;
    _participants.clear();
    _pendingJoins.clear();
    _completedJoins.clear();
    _publishVotes.clear();
    _rosterRevision = 0;
    publisherId = null;
    _awaitingResource = false;
    client.deliveryFailure.addListener(_invitationFailed);
  }

  void _invitationFailed() {
    final message = client.deliveryFailure.value;
    if (message == null || !isActive || message.gameId != gameId) return;
    final joining = _pendingJoins[message.recipientId];
    if (joining != null && joining.deliveries.contains(message.messageId)) {
      _cancelJoin(message.recipientId!, joining);
    }
  }

  @override
  void startFromRoom() {
    final opponent = matchedOpponentId;
    final matchGame = matchedGameId;
    if (opponent <= 0 || matchGame == null) return;
    startMatched(
      opponentId: opponent,
      publisherId: matchInitiated ? identity : opponent,
      isPublisher: matchInitiated,
      gameId: matchGame,
    );
  }

  void startMatched({
    required int opponentId,
    required int publisherId,
    required bool isPublisher,
    required String gameId,
  }) {
    if (isActive || ended.value) return;
    this.publisherId = publisherId;
    _rosterRevision = 1;
    _participants
      ..clear()
      ..addAll({
        identity: members.value[identity] ?? userName,
        opponentId: members.value[opponentId] ?? '',
      });
    _awaitingResource = true;
    gameStep.value = isPublisher ? GameStep.frontWait : GameStep.rearWait;
    activateAfterMatch(gameId: gameId);
    if (!isActive) return;
    readyToOpen.value = true;
    if (isPublisher) _searchHandler(opponentId);
  }

  @override
  void sendGameMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
  }) {
    if (!isActive ||
        recipientId != null ||
        type == MessageType.image ||
        type == MessageType.file) {
      return;
    }
    if (type == MessageType.resource) {
      if (publisherId != identity) return;
      content = jsonEncode({
        'players': _participants.keys.toList(),
        'revision': _rosterRevision,
        'admissions': {
          for (final entry in _completedJoins.entries)
            entry.key.toString(): entry.value,
        },
        'data': content,
      });
    }
    final targets = recipientIds ?? _participants.keys.toSet();
    if (targets.isEmpty ||
        targets.any((id) => !_participants.containsKey(id))) {
      return;
    }
    super.sendGameMessage(type, content, recipientIds: targets);
  }

  @override
  void handleGameMessage(NetworkMessage message) {
    if (!isActive) return;
    // 搜索回环交给当前发布者决定是否邀请；这与大厅匹配的通知不同。
    if (message.type == MessageType.search) {
      final memberId = message.id;
      if (publisherId == identity &&
          memberId != identity &&
          !_participants.containsKey(memberId) &&
          !_pendingJoins.containsKey(memberId) &&
          (_maxPlayers == null ||
              _participants.length + _pendingJoins.length < _maxPlayers!)) {
        final offerId = client.sendNetworkMessage(
          MessageType.match,
          '',
          recipientId: memberId,
          gameId: gameId,
        );
        if (offerId != null) {
          final joining = _PendingJoin(offerId)..deliveries.add(offerId);
          _pendingJoins[memberId] = joining;
          _watchJoin(memberId, joining);
        }
      }
      return;
    }
    if (message.type == MessageType.cancelSearch) {
      final joining = _pendingJoins[message.id];
      if (joining != null) _cancelJoin(message.id, joining);
      return;
    }
    // 私聊的入局控制和群发的游戏数据都必须属于本局。
    if (message.gameId != gameId) return;
    if (message.isPrivateMessage && message.recipientId == identity) {
      _handleJoinConfirmation(message);
      return;
    }
    if (!message.isGroupMessage ||
        !(message.recipientIds?.contains(identity) ?? false)) {
      return;
    }
    if (message.type == MessageType.exit) {
      if (message.id != identity) _removeMember(message.id);
      return;
    }
    if (message.type == MessageType.publish) {
      if (publisherId != null || !_participants.containsKey(message.id)) return;
      _publishVotes.add(message.id);
      if (_publishVotes.length == _participants.length) {
        publisherId = (_participants.keys.toList()..sort()).first;
        _publishVotes.clear();
        if (publisherId == identity) _searchHandler(identity);
      }
      return;
    }
    if (!_participants.containsKey(message.id)) return;
    if (message.type == MessageType.resource) {
      // 胜选资源可能先于最后一票到达；仅允许当前名单最小 ID 接管。
      // 活跃发布者不因新成员 ID 更小或收到其 action/sync 而被替换。
      final expectedPublisher =
          publisherId ?? (_participants.keys.toList()..sort()).first;
      if (message.id != expectedPublisher) return;
      final envelope = jsonDecode(message.content) as Map<String, dynamic>;
      final ids = (envelope['players'] as List<dynamic>).cast<int>();
      final revision = envelope['revision'];
      final admissions = (envelope['admissions'] as Map<String, dynamic>).map(
        (id, offer) => MapEntry(int.parse(id), offer as String),
      );
      if (!ids.contains(identity) ||
          !ids.contains(message.id) ||
          ids.any((id) => id <= 0) ||
          ids.length < 2 ||
          ids.toSet().length != ids.length ||
          revision is! int ||
          revision < _rosterRevision ||
          admissions.keys.any((id) => !ids.contains(id)) ||
          admissions.values.any((id) => id.isEmpty || id.length > 128) ||
          !ids.toSet().containsAll(message.recipientIds!)) {
        return;
      }
      // 同局内入局/撤销也会产生不同名单；旧资源重发不能把撤销的成员加回来。
      publisherId = expectedPublisher;
      _rosterRevision = revision;
      _completedJoins
        ..clear()
        ..addAll(admissions);
      _participants
        ..clear()
        ..addEntries(ids.map((id) => MapEntry(id, members.value[id] ?? '')));
      _awaitingResource = false;
      gameStep.value = GameStep.synchronizing;
      _resourceHandler(
        NetworkMessage(
          id: message.id,
          type: message.type,
          source: message.source,
          content: envelope['data'] as String,
          timestamp: message.timestamp,
          recipientIds: message.recipientIds,
          messageId: message.messageId,
          gameId: message.gameId,
        ),
      );
      return;
    }
    if (message.type == MessageType.sync) _syncHandler(message);
    if (message.type == MessageType.action &&
        gameStep.value == GameStep.action) {
      _actionHandler(message);
    }
    if (message.type == MessageType.text) gameMessageList.add(message);
  }

  void _handleJoinConfirmation(NetworkMessage message) {
    final joining = _pendingJoins[message.id];
    if (message.type == MessageType.reject) {
      if (joining != null && message.content == 'busy:${joining.offerId}') {
        _cancelJoin(message.id, joining);
      }
      return;
    }
    if (message.type != MessageType.confirm) return;
    final confirmation = MatchConfirmation.tryParse(message.content);
    if (confirmation == null) return;
    if (confirmation.phase == MatchConfirmationPhase.abort) {
      if (joining?.offerId == confirmation.offerId) {
        _cancelJoin(message.id, joining!, notify: false);
      } else if (_completedJoins[message.id] == confirmation.offerId) {
        // joined 曾到达，但它的 ACK 未到达新玩家：撤销这一名成员并重同步，
        // 不能结束原有玩家的对局，也不能留下一个不存在的同步参与者。
        _completedJoins.remove(message.id);
        _removeMember(message.id);
      }
      return;
    }
    if (publisherId != identity ||
        joining == null ||
        joining.offerId != confirmation.offerId ||
        joining.expected != confirmation.phase) {
      return;
    }
    switch (confirmation.phase) {
      case MatchConfirmationPhase.accept:
        joining.expected = MatchConfirmationPhase.ready;
        _sendJoinConfirmation(
          message.id,
          joining,
          MatchConfirmationPhase.commit,
        );
      case MatchConfirmationPhase.ready:
        joining.expected = MatchConfirmationPhase.joined;
        _sendJoinConfirmation(
          message.id,
          joining,
          MatchConfirmationPhase.start,
        );
      case MatchConfirmationPhase.joined:
        _clearJoinDeliveries(joining);
        joining.timer?.cancel();
        _pendingJoins.remove(message.id);
        _completedJoins[message.id] = joining.offerId;
        _participants[message.id] = members.value[message.id] ?? '';
        _rosterRevision++;
        _awaitingResource = true;
        gameStep.value = GameStep.synchronizing;
        // 只有收到应用层 joined 后才公布名单、生成资源；accept 不算入局。
        _searchHandler(message.id);
      default:
        break;
    }
  }

  void _sendJoinConfirmation(
    int memberId,
    _PendingJoin joining,
    MatchConfirmationPhase phase,
  ) {
    _clearJoinDeliveries(joining);
    final id = client.sendNetworkMessage(
      MessageType.confirm,
      MatchConfirmation(phase, joining.offerId).content,
      recipientId: memberId,
      gameId: gameId,
    );
    if (id != null) joining.deliveries.add(id);
    _watchJoin(memberId, joining);
  }

  void _watchJoin(int memberId, _PendingJoin joining) {
    joining.timer?.cancel();
    final retryWindow = client.deliveryRetryWindow + const Duration(seconds: 1);
    final timeout = joining.expected == MatchConfirmationPhase.accept
        ? const Duration(seconds: 2)
        : retryWindow > const Duration(seconds: 2)
        ? retryWindow
        : const Duration(seconds: 2);
    joining.timer = Timer(timeout, () {
      if (_pendingJoins[memberId] == joining) _cancelJoin(memberId, joining);
    });
  }

  void _clearJoinDeliveries(_PendingJoin joining) {
    for (final id in joining.deliveries) {
      client.cancelDelivery(id, gameId: gameId);
    }
    joining.deliveries.clear();
  }

  void _cancelJoin(int memberId, _PendingJoin joining, {bool notify = true}) {
    if (_pendingJoins[memberId] != joining) return;
    _pendingJoins.remove(memberId);
    joining.timer?.cancel();
    _clearJoinDeliveries(joining);
    if (notify) {
      client.sendNetworkMessage(
        MessageType.confirm,
        MatchConfirmation(
          MatchConfirmationPhase.abort,
          joining.offerId,
        ).content,
        recipientId: memberId,
        gameId: gameId,
      );
    }
  }

  void _cancelAllJoins() {
    for (final entry in _pendingJoins.entries.toList()) {
      _cancelJoin(entry.key, entry.value);
    }
  }

  @override
  void notifyMatchAbort(
    int inviterId,
    String gameId,
    String offerId,
    Iterable<NetworkMessage> pendingMessages,
  ) {
    final targets = {inviterId};
    for (final message in pendingMessages) {
      if (message.type == MessageType.resource &&
          message.id == inviterId &&
          message.gameId == gameId) {
        targets.addAll(message.recipientIds ?? {});
      }
    }
    targets.remove(identity);
    // 邀请方可能在最终 ACK 前退出；让资源中已知的其他成员也收到撤销，
    // 它们依据资源携带的邀请记录回滚，不依赖原发布者仍在线。
    for (final target in targets) {
      client.sendNetworkMessage(
        MessageType.confirm,
        MatchConfirmation(MatchConfirmationPhase.abort, offerId).content,
        recipientId: target,
        gameId: gameId,
      );
    }
  }

  void _removeMember(int id) {
    final joining = _pendingJoins[id];
    if (joining != null) _cancelJoin(id, joining);
    _completedJoins.remove(id);
    if (_participants.remove(id) == null) return;
    _rosterRevision++;
    final lostPublisher = publisherId == id;
    _awaitingResource = true;
    gameStep.value = GameStep.synchronizing;
    _exitHandler(id);
    if (lostPublisher) {
      _cancelAllJoins();
      publisherId = null;
      _publishVotes.clear();
      if (_participants.isNotEmpty) sendGameMessage(MessageType.publish, '');
    } else if (publisherId == identity && _participants.isNotEmpty) {
      _searchHandler(identity);
    }
  }

  @override
  void memberLeft(int memberId) => _removeMember(memberId);

  bool completeSynchronization() {
    if (!isActive || _awaitingResource || _participants.length < 2) {
      return false;
    }
    gameStep.value = GameStep.action;
    readyToOpen.value = true;
    return true;
  }

  @override
  void finishGame({bool sendExit = true}) {
    _cancelAllJoins();
    super.finishGame(sendExit: sendExit);
  }

  @override
  void releaseGame() {
    client.deliveryFailure.removeListener(_invitationFailed);
    super.releaseGame();
    _participants.clear();
    _pendingJoins.clear();
    _completedJoins.clear();
    _publishVotes.clear();
    publisherId = null;
    _searchHandler = _noSearch;
    _resourceHandler = _noMessage;
    _syncHandler = _noMessage;
    _actionHandler = _noMessage;
    _exitHandler = _noSearch;
  }

  @override
  void onMatchAborted() => finishGame();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disposeGameEngine();
    super.dispose();
  }
}
