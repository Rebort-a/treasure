import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'broadcast_discovery.dart';
import 'network_message.dart';
import 'network_room.dart';
import 'tcp_frame_codec.dart';
import '../config/network_config.dart';

class _WsClient {
  final dynamic socket;
  final int id;
  final TcpFrameDecoder? tcpDecoder;
  bool authorized = false;
  bool rejecting = false;
  Timer? authTimer;

  _WsClient(this.socket, this.id, {this.tcpDecoder});
}

class SocketServer {
  static const _discoveryInterval = Duration(seconds: 1);

  final Set<_WsClient> _clients = {};
  final Map<int, String> _members = {};
  final int roomType;
  final RoomGameMode gameMode;
  final int? maxGamePlayers;
  final membersNotifier = ValueNotifier<Map<int, String>>(const {});
  Map<int, String> get members => Map.unmodifiable(_members);
  int _idCounter = 0;
  ServerSocket? _tcpServer;
  HttpServer? _httpServer;
  Timer? _broadcastTimer;
  bool _isStopping = false;
  Future<int>? _starting;
  Future<void>? _stopping;

  final String roomName;
  final String? encryptionKey;
  final String? password;
  final int maxClients;

  SocketServer({
    required this.roomName,
    required this.roomType,
    this.gameMode = RoomGameMode.none,
    this.maxGamePlayers,
    this.encryptionKey,
    this.password,
    this.maxClients = 64,
  });

  bool get _useWebSocket => kIsWeb || networkMode == NetworkMode.webSocket;

  Future<int> start() {
    if (_isStopping) return Future.error(StateError('Room server has stopped'));
    return _starting ??= _start();
  }

  Future<int> _start() async {
    if (_useWebSocket) {
      return _startWebSocket();
    } else {
      return _startTcp();
    }
  }

  int get port =>
      _useWebSocket ? (_httpServer?.port ?? 0) : (_tcpServer?.port ?? 0);

  // ==================== TCP ====================

  Future<int> _startTcp() async {
    _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _tcpServer!.listen(_handleTcpConnect);
    _startBroadcast();
    return _tcpServer!.port;
  }

  void _handleTcpConnect(Socket socket) {
    if (_isStopping || _clients.length >= maxClients) {
      debugPrint('[Server] 拒绝连接：已达人数上限 $maxClients');
      socket.destroy();
      return;
    }
    _idCounter++;
    final client = _WsClient(socket, _idCounter, tcpDecoder: TcpFrameDecoder());
    _clients.add(client);
    _startAuthTimeout(client);
    debugPrint(
      '[Server] TCP client #${client.id} connected. Total: ${_clients.length}',
    );

    socket.listen(
      (data) {
        if (_clients.contains(client)) {
          try {
            for (final payload in client.tcpDecoder!.add(data)) {
              if (client.authorized) {
                _handleClientMessage(client, payload);
              } else {
                _authenticate(client, payload);
              }
            }
          } on FormatException catch (e) {
            debugPrint('[Server] TCP frame from #${client.id} invalid: $e');
            socket.destroy();
            _removeClient(client);
          }
        }
      },
      onDone: () => _removeClient(client),
      onError: (_) => _removeClient(client),
      cancelOnError: true,
    );
  }

  // ==================== WebSocket ====================

  Future<int> _startWebSocket() async {
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _httpServer!.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final ws = await WebSocketTransformer.upgrade(request);
        _handleWsConnect(ws);
        return;
      }
      // 房间信息只通过发现广播和入房握手提供，不再保留普通 HTTP 查询接口。
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    _startBroadcast();
    return _httpServer!.port;
  }

  void _handleWsConnect(WebSocket ws) {
    if (_isStopping || _clients.length >= maxClients) {
      debugPrint('[Server] 拒绝连接：已达人数上限 $maxClients');
      ws.close();
      return;
    }
    _idCounter++;
    final client = _WsClient(ws, _idCounter);
    _clients.add(client);
    _startAuthTimeout(client);
    debugPrint(
      '[Server] WS client #${client.id} connected. Total: ${_clients.length}',
    );

    ws.listen(
      (data) {
        _handleWsMessage(client, data);
      },
      onDone: () => _removeClient(client),
      onError: (_) => _removeClient(client),
    );
  }

  void _handleWsMessage(_WsClient sender, dynamic data) {
    try {
      List<int> bytes;
      if (data is String) {
        bytes = utf8.encode(data);
      } else if (data is List<int>) {
        bytes = data;
      } else if (data is TypedData) {
        bytes = Uint8List.view(data.buffer);
      } else {
        debugPrint(
          '[Server] Unknown type from #${sender.id}: ${data.runtimeType}',
        );
        return;
      }

      if (sender.authorized) {
        _handleClientMessage(sender, bytes);
      } else {
        _authenticate(sender, bytes);
      }
    } catch (e) {
      debugPrint('[Server] Error from #${sender.id}: $e');
    }
  }

  void _startAuthTimeout(_WsClient client) {
    client.authTimer = Timer(const Duration(seconds: 5), () {
      if (!client.authorized && _clients.contains(client)) {
        _removeClient(client);
      }
    });
  }

  void _authenticate(_WsClient client, List<int> bytes) {
    if (client.rejecting) return;
    if (_isStopping || !_clients.contains(client)) {
      _removeClient(client);
      return;
    }
    try {
      final request = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (request['connect'] == true &&
          request['password'] is String &&
          request['name'] is String &&
          request['password'] == (password ?? '')) {
        client.authorized = true;
        client.authTimer?.cancel();
        _members[client.id] = request['name'] as String;
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
              'gameMode': gameMode.name,
              'members': _members.map((id, name) => MapEntry('$id', name)),
              'key': encryptionKey,
            }),
          ).toSocketData(),
        );
        _memberEvent(MessageType.memberJoined, client.id, _members[client.id]!);
        return;
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
      ).toSocketData(),
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
    );
  }

  // ==================== 通用 ====================

  void _startBroadcast() {
    if (_isStopping) return;
    _broadcastTimer = Timer.periodic(_discoveryInterval, (_) {
      Broadcast.sendMessage(_discoveryMessage().toSocketData());
    });
  }

  void _sendTo(_WsClient client, List<int> data) {
    if (!_clients.contains(client)) return;
    try {
      if (client.socket is Socket) {
        client.socket.add(TcpFrameCodec.encode(data));
      } else {
        client.socket.add(data);
      }
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

  void _handleClientMessage(_WsClient sender, List<int> bytes) {
    if (_isStopping || !sender.authorized || !_clients.contains(sender)) return;
    final message = NetworkMessage.fromSocketData(
      bytes,
      encryptionKey: encryptionKey,
    );
    if (message == null || message.id != sender.id) return;
    // 房间成员不能伪造仅允许服务器发送的控制消息。
    if (const {
      MessageType.accept,
      MessageType.broadcast,
      MessageType.memberJoined,
      MessageType.memberLeft,
      MessageType.roomClosed,
    }.contains(message.type)) {
      return;
    }
    if (!message.hasValidRoute) return;
    if (message.type != MessageType.gameExit &&
        ((message.recipientId != null &&
                !_members.containsKey(message.recipientId)) ||
            (message.recipientIds?.any((id) => !_members.containsKey(id)) ??
                false))) {
      return;
    }
    if (message.type == MessageType.notify &&
        (RoomNotice.fromContent(message.content) == RoomNotice.joinedRoom ||
            RoomNotice.fromContent(message.content) == RoomNotice.leftRoom)) {
      return;
    }
    if (message.type == MessageType.search && gameMode == RoomGameMode.none) {
      return;
    }
    if (!message.isRoomMessage && gameMode == RoomGameMode.none) return;
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

  void _memberEvent(MessageType type, int id, String name) {
    _broadcastRaw(
      NetworkMessage(
        id: 0,
        source: roomName,
        type: type,
        content: jsonEncode({'memberId': id, 'name': name}),
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

  void _removeClient(_WsClient client) {
    if (!_clients.contains(client)) return;
    client.authTimer?.cancel();
    _clients.remove(client);
    final name = _members.remove(client.id);
    try {
      client.socket.close();
    } catch (_) {}
    // stop 期间不广播（socket 已被 stop 关闭）
    if (_isStopping) return;
    if (name != null) _publishMembers();
    if (client.authorized) {
      _memberEvent(MessageType.memberLeft, client.id, name ?? '');
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
      type: MessageType.roomClosed,
      source: roomName,
      content: '',
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
        await client.socket.close();
      } catch (_) {}
    }
    _clients.clear();
    _members.clear();
    _publishMembers();

    // UDP 广播房间关闭（await 确保遍历所有网卡发送完毕）
    if (port != 0) {
      await Broadcast.sendMessage(
        NetworkMessage(
          id: 0,
          type: MessageType.broadcast,
          source: roomName,
          content: RoomInfo.configToJsonString(
            port,
            roomType,
            RoomState.stop,
            encryptionKey: encryptionKey,
          ),
        ).toSocketData(),
      );
    }
    await _tcpServer?.close();
    await _httpServer?.close();
    _tcpServer = null;
    _httpServer = null;
    membersNotifier.dispose();
  }
}
