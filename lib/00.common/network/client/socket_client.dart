import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../model/app_item_type.dart';
import '../protocol/network_message.dart';
import '../protocol/network_room.dart';
import 'base/client_abstract.dart';

enum RoomConnectionState {
  idle,
  connecting,
  authenticating,
  joined,
  reconnecting,
  closed,
  failed,
}

/// 入房失败的原因分类，供 UI 提示与重试策略区分。
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

class _PendingDelivery {
  final NetworkMessage message;
  final Set<int> awaiting;
  final int generation;
  int attempts = 0;
  Timer? timer;

  _PendingDelivery(this.message, this.awaiting, this.generation);
  void cancel() => timer?.cancel();
}

/// 一条房间连接的所有者。只管理协议和状态，不依赖导航、弹窗或页面控件。
class SocketClient {
  final ClientTransport _transport;

  final RoomInfo endpoint; // 房间信息
  final String userName; // 用户名称

  final Duration handshakeTimeout; // 握手超时时间
  final Duration retryBaseDelay; // 重连退避的基础延时
  final int maxReconnectAttempts; // 最大重试次数
  final Duration gameAckTimeout;
  final int maxGameResendAttempts;

  /// 连接状态机；页面据此显示「连接中 / 认证中 / 已入房 / 重连中」。
  final status = ValueNotifier(const RoomStatus(RoomConnectionState.idle));

  /// 已认证身份，0 表示未认证；断线与离房都会归零。
  final identityNotifier = ValueNotifier(0);

  /// 服务端权威成员表，仅由 id 为 0 的加入/离开通知增量维护。
  final members = ValueNotifier<Map<int, String>>(const {});

  /// 局内消息超过重发次数后通知所属引擎，避免悄悄继续不同步的对局。
  final deliveryFailure = ValueNotifier<NetworkMessage?>(null);

  /// 所有接收者均确认后的回执，供入局状态机完成最后一步交接。
  final deliveryConfirmed = ValueNotifier<NetworkMessage?>(null);

  /// 匹配等待覆盖同一套重发窗口，不在引擎中重复维护退避算法。
  Duration get deliveryRetryWindow {
    var total = Duration.zero;
    for (var attempt = 0; attempt <= maxGameResendAttempts; attempt++) {
      total += _retryDelay(attempt);
    }
    return total;
  }

  Duration _retryDelay(int attempt) =>
      gameAckTimeout * (1 << attempt.clamp(0, 4));

  static (String?, String) _deliveryKey(String? gameId, String messageId) =>
      (gameId, messageId);

  int get identity => identityNotifier.value;
  String get roomName => _roomName;
  int get roomType => _roomType;

  /// 由房间类型推导对局形态：回合制、实时或纯聊天房间。
  RoomGameMode get gameMode =>
      OnlineItemType.tryFromRoomType(_roomType)?.gameMode ?? RoomGameMode.none;
  String get encryptionKey => _encryptionKey;

  /// 三重条件同时成立才算入房：未关闭、已认证、状态机已进入 joined。
  bool get isJoined =>
      !_closed &&
      identity != 0 &&
      status.value.state == RoomConnectionState.joined;

  // 以下三项先取广播发现里的值，认证后以服务端 accept 回执为准。
  late String _roomName = endpoint.name;
  int _roomType = 0;
  late String _encryptionKey = endpoint.encryptionKey;

  /// 当前连接；每次重连都会替换，旧连接由代次判定为过期。
  ClientConnection? _connection;

  /// 本次握手的完成器：收到 accept、判定失败或超时都会终结它。
  Completer<void>? _authentication;

  /// 并发 join 共用同一 Future，重复调用不会重复建连。
  Future<void>? _joining;

  /// 并发 close 共用同一 Future，重复调用不会重复关闭。
  Future<void>? _closing;

  /// 写入队列：串行化 send 与 flush，保证消息按调用顺序写出。
  Future<void> _writes = Future.value();
  Timer? _retryTimer;

  /// 连接代次：隔离旧连接的回调、超时后迟到的连接和排队中的写入。
  int _generation = 0;

  /// 房间已关闭：不再建连，也不再收发消息。
  bool _closed = false;

  /// 已释放；dispose 之后 ValueNotifier 不可再用。
  bool _disposed = false;

  /// 处于握手窗口内；此期间的断线交给 _open 收尾，不触发重连。
  bool _opening = false;

  /// 主处理器在认证后由页面安装；安装前的消息按序暂存，不会因页面切换丢失。
  void Function(NetworkMessage)? _processor;
  final List<NetworkMessage> _earlyMessages = [];
  final Set<void Function(NetworkMessage)> _observers = {};
  final Map<(String?, String), _PendingDelivery> _pendingDeliveries = {};
  final LinkedHashSet<(int, String?, String)> _receivedGameIds =
      LinkedHashSet<(int, String?, String)>();
  int _nextMessageId = 0;

  SocketClient({
    required this.userName,
    required this.endpoint,
    this.handshakeTimeout = const Duration(seconds: 8),
    this.retryBaseDelay = const Duration(seconds: 1),
    this.maxReconnectAttempts = 5,
    this.gameAckTimeout = const Duration(milliseconds: 250),
    this.maxGameResendAttempts = 4,
    ClientTransport? transport,
  }) : _transport = transport ?? createClientTransport();

  /// 显示加入/离开/匹配等服务端通知，并同步通知中携带的成员状态。
  /// 成员名单只信任服务端 id 为 0 的通知，不能由普通客户端直接修改。
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

  /// 显式连接并等待认证；并发调用共用同一个结果，失败后关闭房间。
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

  /// 建连失败即关闭房间，避免留下半开连接与残留状态。
  Future<void> _join() async {
    try {
      await _open();
    } on RoomJoinException catch (error) {
      if (!_closed) await close(reason: error.reason);
      rethrow;
    }
  }

  Future<void> _open({int attempt = 0}) async {
    // 每次连接（包括重连）都有独立代次：超时或关闭后旧回调不能写入当前房间。
    if (_closed) throw const RoomJoinException(RoomFailure.cancelled);
    final generation = ++_generation;
    _opening = true;
    status.value = RoomStatus(RoomConnectionState.connecting, attempt: attempt);
    ClientConnection? connection;
    try {
      connection = await _connect();
      if (_closed || generation != _generation) {
        throw const RoomJoinException(RoomFailure.cancelled);
      }
      _connection = connection;
      final authentication = Completer<void>();
      _authentication = authentication;
      // 在发送请求前先监听，并注册超时结果，避免同步到达的回包丢失。
      final accepted = authentication.future.timeout(handshakeTimeout);
      unawaited(accepted.catchError((Object _) {}));
      status.value = RoomStatus(
        RoomConnectionState.authenticating,
        attempt: attempt,
      );
      _listen(connection, generation);
      _sendJoinRequest(connection);
      await accepted;
      if (_closed || generation != _generation || identity == 0) {
        throw const RoomJoinException(RoomFailure.cancelled);
      }
      _opening = false;
      _authentication = null;
      status.value = const RoomStatus(RoomConnectionState.joined);
    } catch (error) {
      // 只能清理本次连接，不能让过期的超时回调清掉更新的连接。
      if (generation == _generation) _resetConnection();
      try {
        await connection?.close();
      } catch (_) {
        // 保留原始的认证或连接失败原因。
      }
      if (error is RoomJoinException) rethrow;
      throw RoomJoinException(
        error is TimeoutException
            ? RoomFailure.timeout
            : RoomFailure.unavailable,
      );
    }
  }

  Future<ClientConnection> _connect() async {
    final pending = _transport.connect(endpoint.address, endpoint.port);
    var timedOut = false;
    // Future.timeout 不会取消底层连接；超时或关闭之后建立的 socket 必须回收。
    unawaited(
      pending.then((lateConnection) {
        if (timedOut) {
          unawaited(lateConnection.close());
        }
      }, onError: (Object _) {}),
    );
    try {
      return await pending.timeout(handshakeTimeout);
    } on TimeoutException {
      // 仅超时的连接由上述回调负责；已经交给 _open 的连接由 _open 关闭。
      timedOut = true;
      rethrow;
    }
  }

  /// 代次守卫：已关闭或已被更新的连接，其数据与断开事件一律忽略。
  void _listen(ClientConnection connection, int generation) {
    bool current() => !_closed && generation == _generation;
    connection.listen(
      onData: (data) {
        if (current()) _receive(data);
      },
      onDone: () {
        if (current()) _disconnected();
      },
      onError: (_) {
        if (current()) _disconnected();
      },
    );
  }

  /// 发送明文握手：id 固定为 0，昵称即 source，content 只带房间密码。
  void _sendJoinRequest(ClientConnection connection) {
    connection.send(
      NetworkMessage(
        id: 0,
        type: MessageType.connect,
        source: userName,
        content: jsonEncode({'password': endpoint.password ?? ''}),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ).toPlainSocketData(),
    );
  }

  /// 让当前连接彻底失效：代次自增作废在途回调，身份归零通知 UI 已离线。
  void _resetConnection() {
    _generation++;
    _connection = null;
    _authentication = null;
    _opening = false;
    if (!_disposed) identityNotifier.value = 0;
  }

  void _receive(List<int> bytes) {
    // 认证前只接受明文 accept；拿到服务端密钥后才按房间密钥解析后续消息。
    final message = identity == 0
        ? NetworkMessage.fromPlainSocketData(bytes)
        : NetworkMessage.fromSocketData(bytes, encryptionKey: _encryptionKey);
    if (message == null) return;
    if (identity == 0) {
      _accept(message);
      return;
    }

    if (message.type == MessageType.notify) {
      if (message.id != 0) return;
      final notification = RoomNotification.tryFromContent(message.content);
      if (notification == null) return;
      _handleRoomNotification(message);
      if (notification.type == NoticeType.close) {
        _deliver(message);
        unawaited(close(reason: RoomFailure.roomClosed));
        return;
      }
    }
    // 私聊只接受「我发出后的回环」与「发给我的」两种。
    if (message.isPrivateMessage &&
        message.id != identity &&
        message.recipientId != identity) {
      return;
    }
    // 群发只接受收件集合包含我的。
    if (message.isGroupMessage &&
        !(message.recipientIds?.contains(identity) ?? false)) {
      return;
    }
    if (message.type == MessageType.ack) {
      if (message.recipientId == identity && message.id != identity) {
        final key = _deliveryKey(message.gameId, message.content);
        final pending = _pendingDeliveries[key];
        if (pending != null &&
            pending.generation == _generation &&
            pending.awaiting.remove(message.id) &&
            pending.awaiting.isEmpty) {
          pending.cancel();
          _pendingDeliveries.remove(key);
          deliveryConfirmed.value = pending.message;
        }
      }
      return;
    }
    // 收到重发包也必须再次确认，但局内逻辑只能处理一次。
    if (message.needsAck && message.messageId != null) {
      if (message.id != identity) {
        sendNetworkMessage(
          MessageType.ack,
          message.messageId!,
          recipientId: message.id,
          gameId: message.gameId,
        );
      }
      final key = (message.id, message.gameId, message.messageId!);
      if (!_receivedGameIds.add(key)) return;
      if (_receivedGameIds.length > 4096) {
        _receivedGameIds.remove(_receivedGameIds.first);
      }
    }
    _deliver(message);
  }

  /// 认证包使用明文；确认密钥与成员名单有效后才启用加密消息解析。
  void _accept(NetworkMessage message) {
    if (message.type != MessageType.accept || message.id != 0) return;
    if (_authentication case final pending? when !pending.isCompleted) {
      try {
        final data = jsonDecode(message.content) as Map<String, dynamic>;
        if (data['error'] != null) {
          pending.completeError(
            const RoomJoinException(RoomFailure.invalidPassword),
          );
          return;
        }
        // 身份、名单与密钥之间必须自洽，密钥还要与广播发现得到的一致。
        final id = data['clientId'] as int;
        if (id <= 0) throw const FormatException('invalid identity');
        final roster = (data['members'] as Map<String, dynamic>).map(
          (id, name) => MapEntry(int.parse(id), name as String),
        );
        if (!roster.containsKey(id) ||
            roster.keys.any((member) => member <= 0)) {
          throw const FormatException('invalid member roster');
        }
        final key = data['key'];
        if (key is! String || key.isEmpty || key != endpoint.encryptionKey) {
          throw const FormatException('invalid encryption key');
        }
        // 一次性写入房间参数：此后收发都按服务端确认的类型与密钥进行。
        _roomType = data['roomType'] as int;
        _roomName = message.source;
        _encryptionKey = key;
        members.value = Map.unmodifiable(roster);
        identityNotifier.value = id;
        pending.complete();
      } catch (_) {
        if (!pending.isCompleted) {
          pending.completeError(
            const RoomJoinException(RoomFailure.invalidResponse),
          );
        }
      }
    }
  }

  void _disconnected() {
    // 认证中断交给 _open 处理；已入房的断线才进入重连。
    _clearDeliveries();
    _earlyMessages.clear();
    identityNotifier.value = 0;
    // 握手窗口内断线：只终结握手，由 _open 统一走失败清理，不触发重连。
    if (_opening) {
      if (_authentication case final pending? when !pending.isCompleted) {
        pending.completeError(const RoomJoinException(RoomFailure.unavailable));
      }
      return;
    }
    final old = _connection;
    _resetConnection();
    unawaited(old?.close() ?? Future.value());
    _retry(1);
  }

  void _retry(int attempt) {
    if (_closed) return;
    // 重试次数用尽即彻底失败，由 UI 提示用户手动重连。
    if (attempt > maxReconnectAttempts) {
      unawaited(close(reason: RoomFailure.unavailable));
      return;
    }
    status.value = RoomStatus(
      RoomConnectionState.reconnecting,
      attempt: attempt,
    );
    // 指数退避最多放大 16 倍，避免频繁敲击离线服务器。
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

  /// 主处理器同一时间只有一个；安装时补发认证后、页面创建前的消息。
  void attachMessageProcessor(void Function(NetworkMessage) processor) {
    if (!isJoined || _disposed || _processor != null) {
      throw StateError('Room processor is unavailable');
    }
    _processor = processor;
    final pending = List<NetworkMessage>.of(_earlyMessages);
    _earlyMessages.clear();
    for (final message in pending) {
      if (_processor == processor) processor(message);
    }
  }

  void detachMessageProcessor(void Function(NetworkMessage) processor) {
    if (_processor == processor) _processor = null;
  }

  /// 原始消息观察者不参与路由；供诊断和协议级消费者使用。
  void addMessageListener(void Function(NetworkMessage) listener) =>
      _observers.add(listener);
  void removeMessageListener(void Function(NetworkMessage) listener) =>
      _observers.remove(listener);

  void _deliver(NetworkMessage message) {
    final processor = _processor;
    if (processor == null) {
      _earlyMessages.add(message);
    } else {
      processor(message);
    }
    for (final observer in List.of(_observers)) {
      if (_observers.contains(observer)) observer(message);
    }
  }

  String? sendNetworkMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
    String? messageId,
    String? gameId,
  }) {
    if (!isJoined) return null;
    if (gameId != null && (gameId.isEmpty || gameId.length > 128)) {
      throw ArgumentError.value(gameId, 'gameId', 'Invalid game identity');
    }
    // 通知由服务端生成，客户端伪造属于调用方错误，直接抛出而非静默丢弃。
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
      gameId: gameId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      messageId:
          messageId ??
          ((const {
                    MessageType.match,
                    MessageType.confirm,
                    MessageType.reject,
                    MessageType.publish,
                    MessageType.resource,
                    MessageType.sync,
                    MessageType.action,
                    MessageType.exit,
                  }.contains(type) ||
                  (type == MessageType.text &&
                      (recipientId != null || recipientIds != null)))
              ? '$identity-${DateTime.now().microsecondsSinceEpoch}-${++_nextMessageId}'
              : null),
    );
    // 路由形态不合法（例如群发收件集合为空）属于调用方错误。
    if (!message.hasValidRoute) throw ArgumentError('Invalid message route');
    if (message.needsAck && message.messageId != null) {
      final expected = recipientIds == null
          ? {recipientId!}
          : Set<int>.of(recipientIds);
      expected.remove(identity);
      if (expected.isNotEmpty) {
        final delivery = _PendingDelivery(message, expected, _generation);
        _pendingDeliveries[_deliveryKey(gameId, message.messageId!)] = delivery;
        _scheduleRetry(delivery);
      }
    }
    _write(message);
    return message.messageId;
  }

  void _scheduleRetry(_PendingDelivery delivery) {
    final delay = _retryDelay(delivery.attempts);
    final key = _deliveryKey(
      delivery.message.gameId,
      delivery.message.messageId!,
    );
    delivery.timer = Timer(delay, () {
      if (_closed ||
          delivery.generation != _generation ||
          _pendingDeliveries[key] != delivery) {
        return;
      }
      if (delivery.attempts >= maxGameResendAttempts) {
        _pendingDeliveries.remove(key);
        deliveryFailure.value = delivery.message;
        return;
      }
      delivery.attempts++;
      _write(delivery.message);
      _scheduleRetry(delivery);
    });
  }

  /// 收到更强的应用层确认后撤销该包的传输重试；不等同于伪造 ACK。
  void cancelDelivery(String messageId, {String? gameId}) {
    _pendingDeliveries.remove(_deliveryKey(gameId, messageId))?.cancel();
  }

  void _clearDeliveries() {
    for (final delivery in _pendingDeliveries.values) {
      delivery.cancel();
    }
    _pendingDeliveries.clear();
    _receivedGameIds.clear();
  }

  void _write(NetworkMessage message) {
    final connection = _connection;
    final generation = _generation;
    // flush 串行化写入；重连时旧队列项不能被写到新连接上。
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

  /// 主动或被动离开房间；reason 为空表示正常离房，否则记录失败原因。
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
    _earlyMessages.clear();
    _clearDeliveries();
    final drainWrites = identity != 0 && reason == null;
    _closed = true;
    _retryTimer?.cancel();
    if (_authentication case final pending? when !pending.isCompleted) {
      pending.completeError(const RoomJoinException(RoomFailure.cancelled));
    }
    _authentication = null;
    identityNotifier.value = 0;
    // 正常离房与失败断开用不同状态，便于 UI 决定是否提示错误。
    status.value = RoomStatus(
      reason == null ? RoomConnectionState.closed : RoomConnectionState.failed,
      failure: reason,
    );
    final connection = _connection;
    if (drainWrites) {
      // 正常离房先尽量发送完已有消息；故障退出不等待，以免失效连接无限阻塞。
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
    unawaited(close());
    _disposed = true;
    _processor = null;
    _observers.clear();
    status.dispose();
    identityNotifier.dispose();
    members.dispose();
    deliveryFailure.dispose();
    deliveryConfirmed.dispose();
  }
}
