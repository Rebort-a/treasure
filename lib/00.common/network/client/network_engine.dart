import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../model/app_item_type.dart';
import '../../model/chat_channel.dart';
import '../../model/notifiers.dart';
import '../../game/step.dart';
import '../protocol/network_message.dart';
import 'real_game_session.dart';
import 'turn_game_session.dart';
import 'client_transport.dart';
import '../protocol/network_room.dart';
import 'net_real_engine.dart';
import 'net_turn_engine.dart';

enum RoomMatchPhase { idle, sending, matching, matched }

enum RoomConnectionState {
  idle,
  connecting,
  authenticating,
  joined,
  reconnecting,
  closed,
  failed,
}

enum RoomFailure {
  invalidPassword,
  timeout,
  unavailable,
  cancelled,
  invalidResponse,
  roomClosed,
}

class RoomJoinException implements Exception {
  final RoomFailure reason;
  const RoomJoinException(this.reason);
  @override
  String toString() => 'RoomJoinException(${reason.name})';
}

class RoomStatus {
  final RoomConnectionState state;
  final int attempt;
  final RoomFailure? failure;
  const RoomStatus(this.state, {this.attempt = 0, this.failure});
}

/// 一条房间连接的所有者。只管理协议和状态，不依赖导航、弹窗或页面控件。
class NetworkEngine implements ChatChannel {
  final RoomInfo endpoint;
  @override
  final String userName;
  final Duration handshakeTimeout;
  final Duration retryBaseDelay;
  final int maxReconnectAttempts;
  final ClientTransport _transport;
  final status = ValueNotifier(const RoomStatus(RoomConnectionState.idle));
  final identityNotifier = ValueNotifier(0);
  final members = ValueNotifier<Map<int, String>>(const {});
  final matchPhase = ValueNotifier(RoomMatchPhase.idle);
  @override
  final messageList = ListNotifier<NetworkMessage>([]);
  @override
  int get identity => identityNotifier.value;
  String get roomName => _roomName;
  int get roomType => _roomType;
  RoomGameMode get gameMode =>
      OnlineItemType.tryFromRoomType(_roomType)?.gameMode ?? RoomGameMode.none;
  int get matchedOpponentId => _matchedOpponentId;
  bool get matchInitiated => _matchInitiated;
  String get encryptionKey => _encryptionKey;
  bool get isJoined =>
      !_closed &&
      identity != 0 &&
      status.value.state == RoomConnectionState.joined;

  late String _roomName = endpoint.name;
  int _roomType = 0;
  late String _encryptionKey = endpoint.encryptionKey;
  ClientConnection? _connection;
  Completer<void>? _authentication;
  Future<void>? _joining;
  Future<void>? _closing;
  Future<void> _writes = Future.value();
  Timer? _retryTimer;
  int _generation = 0;
  bool _closed = false;
  bool _disposed = false;
  bool _opening = false;
  final Set<void Function(NetworkMessage)> _listeners = {};
  final List<NetworkMessage> _pendingGameMessages = [];
  bool _waitingForGame = false;
  TurnGameSession? _manualTurnSession;
  RealGameSession? _manualRealSession;
  int? _matchCandidate;
  bool _matchOffered = false;
  int _matchedOpponentId = 0;
  bool _matchInitiated = false;

  NetworkEngine({
    required this.userName,
    required this.endpoint,
    this.handshakeTimeout = const Duration(seconds: 8),
    this.retryBaseDelay = const Duration(seconds: 1),
    this.maxReconnectAttempts = 5,
    ClientTransport? transport,
  }) : _transport = transport ?? createClientTransport();

  /// 已发现的房间类型决定连接引擎，认证后的 roomType 仍由服务端确认。
  factory NetworkEngine.forRoom({
    required String userName,
    required RoomInfo endpoint,
    ClientTransport? transport,
  }) {
    final mode =
        OnlineItemType.tryFromRoomType(endpoint.type)?.gameMode ??
        RoomGameMode.none;
    return switch (mode) {
      RoomGameMode.none => NetworkEngine(
        userName: userName,
        endpoint: endpoint,
        transport: transport,
      ),
      RoomGameMode.turn => NetTurnEngine(
        userName: userName,
        endpoint: endpoint,
        transport: transport,
      ),
      RoomGameMode.real => NetRealEngine(
        userName: userName,
        endpoint: endpoint,
        transport: transport,
      ),
    };
  }

  /// 手动输入地址时事先不知道房间类型，认证后沿用同一连接创建对应会话。
  TurnGameSession createTurnGameForUnknownRoom({
    required TurnResourceMode resourceMode,
    required void Function() searchHandler,
    required void Function(GameStep, NetworkMessage) resourceHandler,
    required void Function(bool, NetworkMessage) actionHandler,
    required void Function() exitHandler,
  }) {
    if (!isJoined ||
        OnlineItemType.tryFromRoomType(endpoint.type) !=
            OnlineItemType.onlyChat ||
        gameMode != RoomGameMode.turn) {
      throw StateError('Turn room is not authenticated');
    }
    if (_manualTurnSession case final game? when !game.ended.value) {
      throw StateError('Turn game is already active in this room');
    }
    final game = TurnGameSession(
      room: this,
      resourceMode: resourceMode,
      searchHandler: searchHandler,
      resourceHandler: resourceHandler,
      actionHandler: actionHandler,
      exitHandler: exitHandler,
    );
    _manualTurnSession = game;
    game.ended.addListener(() {
      if (game.ended.value && identical(_manualTurnSession, game)) {
        _manualTurnSession = null;
      }
    });
    return game;
  }

  RealGameSession createRealGameForUnknownRoom({
    int? maxPlayers,
    required void Function(int) searchHandler,
    required void Function(NetworkMessage) resourceHandler,
    required void Function(NetworkMessage) syncHandler,
    required void Function(NetworkMessage) actionHandler,
    required void Function(int) exitHandler,
  }) {
    if (!isJoined ||
        OnlineItemType.tryFromRoomType(endpoint.type) !=
            OnlineItemType.onlyChat ||
        gameMode != RoomGameMode.real) {
      throw StateError('Real-time room is not authenticated');
    }
    if (_manualRealSession case final game? when !game.ended.value) {
      throw StateError('Real-time game is already active in this room');
    }
    final game = RealGameSession(
      room: this,
      maxPlayers: maxPlayers,
      searchHandler: searchHandler,
      resourceHandler: resourceHandler,
      syncHandler: syncHandler,
      actionHandler: actionHandler,
      exitHandler: exitHandler,
    );
    _manualRealSession = game;
    game.ended.addListener(() {
      if (game.ended.value && identical(_manualRealSession, game)) {
        _manualRealSession = null;
      }
    });
    return game;
  }

  /// 房间负责进入游戏前的搜索和确认；页面只接收已经确认的匹配结果。
  void startMatching() {
    if (!isJoined ||
        gameMode == RoomGameMode.none ||
        matchPhase.value != RoomMatchPhase.idle) {
      return;
    }
    _waitingForGame = false;
    _pendingGameMessages.clear();
    _matchCandidate = null;
    _matchOffered = false;
    _matchedOpponentId = 0;
    _matchInitiated = false;
    matchPhase.value = RoomMatchPhase.sending;
    sendNetworkMessage(MessageType.search, '');
  }

  void cancelMatching() {
    _matchCandidate = null;
    _matchOffered = false;
    if (matchPhase.value != RoomMatchPhase.idle) {
      matchPhase.value = RoomMatchPhase.idle;
    }
    _matchedOpponentId = 0;
    _matchInitiated = false;
    _pendingGameMessages.clear();
    _waitingForGame = false;
  }

  /// 导航确认后复位匹配卡片；对手身份仍保留，供游戏页面初始化。
  void openMatchedGame() {
    if (matchPhase.value == RoomMatchPhase.matched) {
      matchPhase.value = RoomMatchPhase.idle;
    }
  }

  void _handleMatching(NetworkMessage message) {
    if (matchPhase.value == RoomMatchPhase.idle ||
        matchPhase.value == RoomMatchPhase.matched) {
      return;
    }
    if (message.type == MessageType.notify && message.id == 0) {
      final notification = RoomNotification.tryFromContent(message.content);
      if (notification == null) return;
      if (notification.type == NoticeType.close) {
        cancelMatching();
        return;
      }
      if (notification.type == NoticeType.left) {
        if (notification.memberId == _matchCandidate) {
          _matchCandidate = null;
          _matchOffered = false;
        }
        return;
      }
      if (notification.type == NoticeType.search) {
        final memberId = notification.memberId!;
        if (memberId == identity) {
          matchPhase.value = RoomMatchPhase.matching;
        } else if (matchPhase.value == RoomMatchPhase.matching &&
            _matchCandidate == null) {
          _matchCandidate = memberId;
          _matchOffered = true;
          sendNetworkMessage(MessageType.match, '', recipientId: memberId);
        }
        return;
      }
    }
    if (message.type == MessageType.match &&
        message.id != identity &&
        message.recipientId == identity &&
        matchPhase.value == RoomMatchPhase.matching &&
        _matchCandidate == null) {
      _matchCandidate = message.id;
      sendNetworkMessage(MessageType.confirm, '', recipientId: message.id);
      return;
    }
    if (message.type != MessageType.confirm || _matchCandidate == null) return;
    final opponent = _matchCandidate!;
    final confirmed = _matchOffered
        ? message.id == opponent && message.recipientId == identity
        : message.id == identity && message.recipientId == opponent;
    if (!confirmed) return;
    _matchedOpponentId = opponent;
    _matchInitiated = _matchOffered;
    _matchCandidate = null;
    _matchOffered = false;
    _waitingForGame = true;
    matchPhase.value = RoomMatchPhase.matched;
  }

  /// 显示加入/离开/匹配等服务端通知，并同步通知中携带的成员状态。
  void _handleRoomNotification(NetworkMessage message) {
    final notification = RoomNotification.tryFromContent(message.content);
    if (notification == null || message.id != 0) return;
    final memberId = notification.memberId;
    switch (notification.type) {
      case NoticeType.join:
        final next = Map<int, String>.of(members.value)
          ..[memberId!] = notification.memberName!;
        members.value = Map.unmodifiable(next);
      case NoticeType.left:
        final next = Map<int, String>.of(members.value)..remove(memberId);
        members.value = Map.unmodifiable(next);
      case NoticeType.search || NoticeType.close:
        break;
    }
  }

  /// 显式连接并等待认证；成功返回后才能把引擎交给聊天室。
  Future<void> join() {
    if (_joining case final pending?) return pending;
    final completion = Completer<void>();
    _joining = completion.future;
    _join().then(
      (_) => completion.complete(),
      onError: (Object error, StackTrace stack) =>
          completion.completeError(error, stack),
    );
    return completion.future;
  }

  Future<void> _join() async {
    try {
      await _open();
    } on RoomJoinException catch (error) {
      if (!_closed) await close(reason: error.reason);
      rethrow;
    }
  }

  Future<void> _open({int attempt = 0}) async {
    if (_closed) throw const RoomJoinException(RoomFailure.cancelled);
    final generation = ++_generation;
    _opening = true;
    status.value = RoomStatus(RoomConnectionState.connecting, attempt: attempt);
    ClientConnection? connection;
    try {
      final pending = _transport.connect(endpoint.address, endpoint.port);
      // Future.timeout 不会取消底层连接；迟到的连接必须立即关闭。
      unawaited(
        pending.then((lateConnection) {
          if (_closed || generation != _generation) {
            unawaited(lateConnection.close());
          }
        }, onError: (Object _) {}),
      );
      connection = await pending.timeout(handshakeTimeout);
      if (_closed || generation != _generation) {
        await connection.close();
        throw const RoomJoinException(RoomFailure.cancelled);
      }
      _connection = connection;
      final authentication = Completer<void>();
      _authentication = authentication;
      final accepted = authentication.future.timeout(handshakeTimeout);
      unawaited(accepted.catchError((Object _) {}));
      status.value = RoomStatus(
        RoomConnectionState.authenticating,
        attempt: attempt,
      );
      connection.listen(
        onData: (data) {
          if (generation == _generation && !_closed) _receive(data);
        },
        onDone: () {
          if (generation == _generation && !_closed) _disconnected();
        },
        onError: (_) {
          if (generation == _generation && !_closed) _disconnected();
        },
      );
      connection.send(
        NetworkMessage(
          id: 0,
          type: MessageType.connect,
          source: userName,
          content: jsonEncode({'password': endpoint.password ?? ''}),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ).toPlainSocketData(),
      );
      await accepted;
      if (_closed || generation != _generation || identity == 0) {
        throw const RoomJoinException(RoomFailure.cancelled);
      }
      _opening = false;
      _authentication = null;
      status.value = const RoomStatus(RoomConnectionState.joined);
    } catch (error) {
      if (generation == _generation) {
        _generation++;
        _connection = null;
        _authentication = null;
        _opening = false;
        if (!_disposed) identityNotifier.value = 0;
      }
      await connection?.close();
      if (error is RoomJoinException) rethrow;
      throw RoomJoinException(
        error is TimeoutException
            ? RoomFailure.timeout
            : RoomFailure.unavailable,
      );
    }
  }

  void _receive(List<int> bytes) {
    final message = identity == 0
        ? NetworkMessage.fromPlainSocketData(bytes)
        : NetworkMessage.fromSocketData(bytes, encryptionKey: _encryptionKey);
    if (message == null) return;
    if (identity == 0) {
      if (message.type != MessageType.accept || message.id != 0) return;
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        if (data['error'] != null) {
          _authentication?.completeError(
            const RoomJoinException(RoomFailure.invalidPassword),
          );
          return;
        }
        final id = data['clientId'] as int;
        if (id <= 0) throw const FormatException('invalid identity');
        final roster = (data['members'] as Map<String, dynamic>).map(
          (id, name) => MapEntry(int.parse(id), name as String),
        );
        if (!roster.containsKey(id) ||
            roster.keys.any((member) => member <= 0)) {
          throw const FormatException('invalid member roster');
        }
        _roomType = data['roomType'] as int;
        _roomName = message.source;
        final key = data['key'];
        if (key is! String || key.isEmpty || key != endpoint.encryptionKey) {
          throw const FormatException('invalid encryption key');
        }
        _encryptionKey = key;
        members.value = Map.unmodifiable(roster);
        identityNotifier.value = id;
        _authentication?.complete();
      } catch (_) {
        if (_authentication case final pending? when !pending.isCompleted) {
          pending.completeError(
            const RoomJoinException(RoomFailure.invalidResponse),
          );
        }
      }
      return;
    }

    if (message.type == MessageType.notify) {
      if (message.id != 0) return;
      final notification = RoomNotification.tryFromContent(message.content);
      if (notification == null) return;
      _handleRoomNotification(message);
      if (notification.type == NoticeType.close) {
        messageList.add(message);
        _dispatch(message);
        unawaited(close(reason: RoomFailure.roomClosed));
        return;
      }
    }
    if (message.isPrivateMessage &&
        message.id != identity &&
        message.recipientId != identity) {
      return;
    }
    if (message.isGroupMessage &&
        !(message.recipientIds?.contains(identity) ?? false)) {
      return;
    }
    if (message.isRoomMessage &&
        const {
          MessageType.notify,
          MessageType.text,
          MessageType.image,
          MessageType.file,
        }.contains(message.type)) {
      messageList.add(message);
    }
    _dispatch(message);
  }

  void _disconnected() {
    cancelMatching();
    _pendingGameMessages.clear();
    _waitingForGame = false;
    identityNotifier.value = 0;
    if (_opening) {
      if (_authentication case final pending? when !pending.isCompleted) {
        pending.completeError(const RoomJoinException(RoomFailure.unavailable));
      }
      return;
    }
    final old = _connection;
    _connection = null;
    _generation++;
    unawaited(old?.close() ?? Future.value());
    _retry(1);
  }

  void _retry(int attempt) {
    if (_closed) return;
    if (attempt > maxReconnectAttempts) {
      unawaited(close(reason: RoomFailure.unavailable));
      return;
    }
    status.value = RoomStatus(
      RoomConnectionState.reconnecting,
      attempt: attempt,
    );
    final exponent = (attempt - 1).clamp(0, 4);
    _retryTimer = Timer(retryBaseDelay * (1 << exponent), () async {
      if (_closed) return;
      try {
        await _open(attempt: attempt);
      } on RoomJoinException catch (error) {
        if (_closed) return;
        if (error.reason == RoomFailure.invalidPassword) {
          await close(reason: error.reason);
        } else {
          _retry(attempt + 1);
        }
      }
    });
  }

  void addMessageListener(void Function(NetworkMessage) listener) =>
      _listeners.add(listener);
  void removeMessageListener(void Function(NetworkMessage) listener) =>
      _listeners.remove(listener);
  void _dispatch(NetworkMessage message) {
    _handleMatching(message);
    final notification = message.type == MessageType.notify
        ? RoomNotification.tryFromContent(message.content)
        : null;
    final pendingRoomEvent =
        message.id == 0 &&
        (notification?.type == NoticeType.left ||
            notification?.type == NoticeType.close ||
            notification?.type == NoticeType.search);
    if (_waitingForGame &&
        (pendingRoomEvent ||
            (!message.isRoomMessage &&
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
    for (final listener in List.of(_listeners)) {
      if (_listeners.contains(listener)) listener(message);
    }
  }

  /// 页面创建游戏引擎时接管确认后、监听注册前抵达的局内消息。
  void addGameMessageListener(void Function(NetworkMessage) listener) {
    _listeners.add(listener);
    if (!_waitingForGame) return;
    _waitingForGame = false;
    final pending = List<NetworkMessage>.of(_pendingGameMessages);
    _pendingGameMessages.clear();
    for (final message in pending) {
      if (_listeners.contains(listener)) listener(message);
    }
  }

  @override
  void sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) sendNetworkMessage(MessageType.text, trimmed);
  }

  void sendNetworkMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
  }) {
    if (!isJoined) return;
    if (type == MessageType.notify) {
      throw ArgumentError('Room notifications are server-generated');
    }
    final message = NetworkMessage(
      id: identity,
      source: userName,
      type: type,
      content: content,
      recipientId: recipientId,
      recipientIds: recipientIds,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    if (!message.hasValidRoute) throw ArgumentError('Invalid message route');
    final connection = _connection;
    final generation = _generation;
    _writes = _writes
        .then((_) async {
          if (generation != _generation || connection == null) return;
          connection.send(message.toSocketData(encryptionKey: _encryptionKey));
          await connection.flush();
        })
        .catchError((Object _) {
          if (!_closed && generation == _generation) _disconnected();
        });
  }

  void sendImageMessage(String data, {String? fileName, String? blurHash}) =>
      sendNetworkMessage(
        MessageType.image,
        jsonEncode({
          'data': data,
          if (fileName != null) 'name': fileName,
          if (blurHash != null) 'hash': blurHash,
        }),
      );
  void sendFileMessage(String name, int size, String data) =>
      sendNetworkMessage(
        MessageType.file,
        jsonEncode({'name': name, 'size': size, 'data': data}),
      );

  Future<void> close({RoomFailure? reason}) {
    if (_closing case final pending?) return pending;
    final completion = Completer<void>();
    _closing = completion.future;
    _close(reason).then(
      (_) => completion.complete(),
      onError: (Object error, StackTrace stack) =>
          completion.completeError(error, stack),
    );
    return completion.future;
  }

  Future<void> _close(RoomFailure? reason) async {
    cancelMatching();
    _pendingGameMessages.clear();
    _waitingForGame = false;
    final drainWrites = identity != 0 && reason == null;
    _closed = true;
    _retryTimer?.cancel();
    if (_authentication case final pending? when !pending.isCompleted) {
      pending.completeError(const RoomJoinException(RoomFailure.cancelled));
    }
    _authentication = null;
    identityNotifier.value = 0;
    status.value = RoomStatus(
      reason == null ? RoomConnectionState.closed : RoomConnectionState.failed,
      failure: reason,
    );
    final connection = _connection;
    if (drainWrites) {
      // 正常离房尽量发送完已有消息，但不能因失效连接无限阻塞退出。
      try {
        await _writes.timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
    _generation++;
    _connection = null;
    await connection?.close();
  }

  /// 仅由房间所有者释放；游戏引擎只取消订阅，不能销毁房间。
  void dispose() {
    if (_disposed) return;
    _manualTurnSession?.dispose();
    _manualRealSession?.dispose();
    unawaited(close());
    _disposed = true;
    _listeners.clear();
    matchPhase.dispose();
    status.dispose();
    identityNotifier.dispose();
    members.dispose();
    messageList.dispose();
  }
}
