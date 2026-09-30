import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../broadcast_discovery.dart';
import '../protocol/network_message.dart';
import '../protocol/network_room.dart';
import 'server_transport.dart';

class _RoomClient {
  final ServerConnection connection;
  final int id;
  bool authorized = false;
  bool rejecting = false;
  Timer? authTimer;

  _RoomClient(this.connection, this.id);
}

class SocketServer {
  static const _discoveryInterval = Duration(seconds: 1);

  final String roomName;
  final int roomType;
  final Set<_RoomClient> _clients = {};
  final Map<int, String> _members = {};
  final int maxClients;
  final membersNotifier = ValueNotifier<Map<int, String>>(const {});
  int _idCounter = 0;
  bool _isStopping = false;

  Map<int, String> get members => Map.unmodifiable(_members);

  final ServerTransport _transport;
  Timer? _broadcastTimer;
  Future<int>? _starting;
  Future<void>? _stopping;

  final String encryptionKey;
  final String? password;

  SocketServer({
    required this.roomName,
    required this.roomType,
    required this.encryptionKey,
    this.password,
    this.maxClients = 64,
    ServerTransport? transport,
  }) : _transport = transport ?? createServerTransport() {
    if (encryptionKey.isEmpty) {
      throw ArgumentError.value(
        encryptionKey,
        'encryptionKey',
        'must not be empty',
      );
    }
  }

  Future<int> start() {
    if (_isStopping) return Future.error(StateError('Room server has stopped'));
    return _starting ??= _start();
  }

  Future<int> _start() async {
    final port = await _transport.start(_handleConnection);
    _startBroadcast();
    return port;
  }

  int get port => _transport.port;

  void _handleConnection(ServerConnection connection) {
    if (_isStopping || _clients.length >= maxClients) {
      debugPrint('[Server] 拒绝连接：已达人数上限 $maxClients');
      unawaited(connection.close());
      return;
    }
    _idCounter++;
    final client = _RoomClient(connection, _idCounter);
    _clients.add(client);
    _startAuthTimeout(client);
    debugPrint(
      '[Server] Client #${client.id} connected. Total: ${_clients.length}',
    );
    _listenClient(client);
  }

  void _listenClient(_RoomClient client) {
    client.connection.listen(
      onData: (bytes) {
        if (!_clients.contains(client)) return;
        if (client.authorized) {
          _handleClientMessage(client, bytes);
        } else {
          _authenticate(client, bytes);
        }
      },
      onDone: () => _removeClient(client),
      onError: (error) {
        debugPrint('[Server] Connection #${client.id} error: $error');
        _removeClient(client);
      },
    );
  }

  void _startAuthTimeout(_RoomClient client) {
    client.authTimer = Timer(const Duration(seconds: 5), () {
      if (!client.authorized && _clients.contains(client)) {
        _removeClient(client);
      }
    });
  }

  void _authenticate(_RoomClient client, List<int> bytes) {
    if (client.rejecting) return;
    if (_isStopping || !_clients.contains(client)) {
      _removeClient(client);
      return;
    }
    try {
      final request = NetworkMessage.fromPlainSocketData(bytes);
      if (request != null &&
          request.type == MessageType.connect &&
          request.id == 0 &&
          request.isRoomMessage &&
          request.source.trim().isNotEmpty) {
        final credentials = jsonDecode(request.content);
        if (credentials is Map<String, dynamic> &&
            credentials['password'] is String &&
            credentials['password'] == (password ?? '')) {
          client.authorized = true;
          client.authTimer?.cancel();
          _members[client.id] = request.source;
          _publishMembers();
          _sendTo(
            client,
            NetworkMessage(
              id: 0,
              type: MessageType.accept,
              source: roomName,
              content: jsonEncode({
                'clientId': client.id,
                'roomType': roomType,
                'members': _members.map((id, name) => MapEntry('$id', name)),
                'key': encryptionKey,
              }),
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ).toPlainSocketData(),
          );
          final name = _members[client.id]!;
          _notify(
            RoomNotification(
              type: NoticeType.join,
              memberId: client.id,
              memberName: name,
            ),
            source: name,
          );
          return;
        }
      }
    } catch (_) {
      // 拒绝无效握手，不向其暴露房间状态。
    }
    client.rejecting = true;
    _sendTo(
      client,
      NetworkMessage(
        id: 0,
        type: MessageType.accept,
        source: roomName,
        content: jsonEncode({'error': 'invalidPassword'}),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ).toPlainSocketData(),
    );
    // 先发送完错误消息，再关闭连接。
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      _removeClient(client);
    });
  }

  NetworkMessage _discoveryMessage() {
    return NetworkMessage(
      id: 0,
      type: MessageType.broadcast,
      source: roomName,
      content: RoomInfo.configToJsonString(
        port,
        roomType,
        RoomState.start,
        encryptionKey: encryptionKey,
        hasPassword: password != null,
        count: _members.length,
      ),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ==================== 通用 ====================

  void _startBroadcast() {
    if (_isStopping) return;
    _broadcastTimer = Timer.periodic(_discoveryInterval, (_) {
      Broadcast.sendMessage(_discoveryMessage().toPlainSocketData());
    });
  }

  void _sendTo(_RoomClient client, List<int> data) {
    if (!_clients.contains(client)) return;
    try {
      client.connection.send(data);
    } catch (e) {
      debugPrint('[Server] _sendTo #${client.id} failed: $e');
    }
  }

  void _broadcastRaw(List<int> data) {
    // TCP 已由长度前缀恢复消息边界，WebSocket 原生具有帧边界，两条路径
    // 均可在广播前安全校验完整消息。
    if (!_isValidMessage(data)) {
      debugPrint('[Server] 丢弃畸形消息，不转发');
      return;
    }
    for (final client in _clients) {
      if (client.authorized) _sendTo(client, data);
    }
  }

  void _publishMembers() {
    membersNotifier.value = members;
  }

  void _handleClientMessage(_RoomClient sender, List<int> bytes) {
    if (_isStopping || !sender.authorized || !_clients.contains(sender)) return;
    final message = NetworkMessage.fromSocketData(
      bytes,
      encryptionKey: encryptionKey,
    );
    if (message == null || message.id != sender.id) return;
    // 房间成员不能伪造仅允许服务器发送的控制消息。
    if (const {
      MessageType.accept,
      MessageType.connect,
      MessageType.broadcast,
      MessageType.notify,
    }.contains(message.type)) {
      return;
    }
    if (!message.hasValidRoute) return;
    if (message.type != MessageType.exit &&
        ((message.recipientId != null &&
                !_members.containsKey(message.recipientId)) ||
            (message.recipientIds?.any((id) => !_members.containsKey(id)) ??
                false))) {
      return;
    }
    if (message.type == MessageType.search) {
      final name = _members[sender.id]!;
      _notify(
        RoomNotification(
          type: NoticeType.search,
          memberId: sender.id,
          memberName: name,
        ),
        source: name,
      );
      return;
    }
    // 显示名称使用认证值，不能由客户端冒充其他成员。
    message.source = _members[sender.id]!;
    final forwarded = message.toSocketData(encryptionKey: encryptionKey);
    if (message.isPrivateMessage) {
      // 私聊严格先向发送者回环，再投递唯一接收者。
      _sendTo(sender, forwarded);
      final target = _clients
          .where(
            (client) => client.authorized && client.id == message.recipientId,
          )
          .firstOrNull;
      if (target != null && target != sender) _sendTo(target, forwarded);
      return;
    }
    final recipients = message.recipientIds;
    for (final client in _clients) {
      if (!client.authorized) continue;
      if (recipients == null || recipients.contains(client.id)) {
        _sendTo(client, forwarded);
      }
    }
  }

  void _notify(RoomNotification notification, {required String source}) {
    _broadcastRaw(
      NetworkMessage(
        id: 0,
        source: source,
        type: MessageType.notify,
        content: notification.content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ).toSocketData(encryptionKey: encryptionKey),
    );
  }

  /// 校验 data 能解密并解析为合法 NetworkMessage
  bool _isValidMessage(List<int> data) {
    try {
      return NetworkMessage.fromSocketData(
            data,
            encryptionKey: encryptionKey,
          ) !=
          null;
    } catch (_) {
      return false;
    }
  }

  void _removeClient(_RoomClient client) {
    if (!_clients.contains(client)) return;
    client.authTimer?.cancel();
    _clients.remove(client);
    final name = _members.remove(client.id);
    unawaited(client.connection.close());
    // stop 期间不广播（socket 已被 stop 关闭）
    if (_isStopping) return;
    if (name != null) _publishMembers();
    if (client.authorized && name != null) {
      _notify(
        RoomNotification(
          type: NoticeType.left,
          memberId: client.id,
          memberName: name,
        ),
        source: name,
      );
    }
  }

  Future<void> stop() {
    if (_stopping case final pending?) return pending;
    final completion = Completer<void>();
    _stopping = completion.future;
    _isStopping = true;
    _stop().then(
      (_) => completion.complete(),
      onError: (Object error, StackTrace stack) =>
          completion.completeError(error, stack),
    );
    return completion.future;
  }

  Future<void> _stop() async {
    // 启动期间也可取消，必须等待迟到的监听端口建立后再关闭。
    try {
      await _starting;
    } catch (_) {}
    _broadcastTimer?.cancel();

    final closedMessage = NetworkMessage(
      id: 0,
      type: MessageType.notify,
      source: roomName,
      content: const RoomNotification(type: NoticeType.close).content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ).toSocketData(encryptionKey: encryptionKey);

    // 通知房间关闭，与游戏退出消息分离。
    for (final client in List.of(_clients)) {
      client.authTimer?.cancel();
      if (client.authorized) _sendTo(client, closedMessage);
    }

    // 等消息发出后再关 socket
    if (_clients.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    for (final client in List.of(_clients)) {
      try {
        await client.connection.close();
      } catch (_) {}
    }
    _clients.clear();
    _members.clear();
    _publishMembers();

    // UDP 广播房间关闭（await 确保遍历所有网卡发送完毕）
    final serverPort = port;
    if (serverPort != 0) {
      await Broadcast.sendMessage(
        NetworkMessage(
          id: 0,
          type: MessageType.broadcast,
          source: roomName,
          content: RoomInfo.configToJsonString(
            serverPort,
            roomType,
            RoomState.stop,
            encryptionKey: encryptionKey,
          ),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ).toPlainSocketData(),
      );
    }
    await _transport.close();
    membersNotifier.dispose();
  }
}
