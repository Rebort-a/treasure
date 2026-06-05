import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'broadcast_discovery.dart';
import 'network_message.dart';
import 'network_room.dart';
import '../config/network_config.dart';

class _WsClient {
  final dynamic socket;
  final int id;

  _WsClient(this.socket, this.id);
}

class SocketServer {
  static const _discoveryInterval = Duration(seconds: 1);

  final Set<_WsClient> _clients = {};
  int _idCounter = 0;
  ServerSocket? _tcpServer;
  HttpServer? _httpServer;
  Timer? _broadcastTimer;
  bool _isStopping = false;

  final String roomName;
  final int roomType;
  final String? encryptionKey;

  SocketServer({
    required this.roomName,
    required this.roomType,
    this.encryptionKey,
  });

  bool get _useWebSocket => kIsWeb || networkMode == NetworkMode.webSocket;

  Future<int> start() async {
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
    _idCounter++;
    final client = _WsClient(socket, _idCounter);
    _clients.add(client);
    debugPrint(
      '[Server] TCP client #${client.id} connected. Total: ${_clients.length}',
    );

    socket.listen(
      (data) {
        if (_clients.contains(client)) {
          _broadcastRaw(data);
        }
      },
      onDone: () => _removeClient(client),
      onError: (_) => _removeClient(client),
      cancelOnError: true,
    );

    _sendTo(
      client,
      NetworkMessage(
        id: client.id,
        type: MessageType.accept,
        source: roomName,
        content: 'server',
      ).toSocketData(encryptionKey: encryptionKey),
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
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response
        ..headers.contentType = ContentType.json
        ..write(_roomInfoJson());
      await request.response.close();
    });
    _startBroadcast();
    return _httpServer!.port;
  }

  void _handleWsConnect(WebSocket ws) {
    _idCounter++;
    final client = _WsClient(ws, _idCounter);
    _clients.add(client);
    debugPrint(
      '[Server] WS client #${client.id} connected. Total: ${_clients.length}',
    );

    bool isFirstMessage = true;
    ws.listen(
      (data) {
        if (isFirstMessage) {
          isFirstMessage = false;
          _sendTo(
            client,
            NetworkMessage(
              id: client.id,
              type: MessageType.accept,
              source: roomName,
              content: 'server',
            ).toSocketData(encryptionKey: encryptionKey),
          );
          return;
        }
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
      _logMessage(sender.id, bytes);
      _broadcastRaw(bytes);
    } catch (e) {
      debugPrint('[Server] Error from #${sender.id}: $e');
    }
  }

  void _logMessage(int senderId, List<int> bytes) {
    try {
      final decrypted = encryptionKey != null && encryptionKey!.isNotEmpty
          ? NetworkMessage.xorCrypt(bytes, encryptionKey!)
          : bytes;
      debugPrint(
        '[Server] From #$senderId: ${utf8.decode(decrypted, allowMalformed: true)}',
      );
    } catch (e) {
      debugPrint('[Server] From #$senderId: <decode error> $e');
    }
  }

  String _roomInfoJson() {
    return NetworkMessage(
      id: 0,
      type: MessageType.broadcast,
      source: roomName,
      content: RoomInfo.configToJsonString(
        port,
        roomType,
        RoomState.start,
        encryptionKey: encryptionKey,
      ),
    ).toJsonString();
  }

  // ==================== 通用 ====================

  void _startBroadcast() {
    _broadcastTimer = Timer.periodic(_discoveryInterval, (_) {
      Broadcast.sendMessage(
        NetworkMessage(
          id: 0,
          type: MessageType.broadcast,
          source: roomName,
          content: RoomInfo.configToJsonString(
            port,
            roomType,
            RoomState.start,
            encryptionKey: encryptionKey,
          ),
        ).toSocketData(),
      );
    });
  }

  void _sendTo(_WsClient client, List<int> data) {
    if (!_clients.contains(client)) return;
    try {
      client.socket.add(data);
    } catch (e) {
      debugPrint('[Server] _sendTo #${client.id} failed: $e');
    }
  }

  void _broadcastRaw(List<int> data) {
    for (final client in _clients) {
      _sendTo(client, data);
    }
  }

  void _removeClient(_WsClient client) {
    if (!_clients.contains(client)) return;
    _clients.remove(client);
    try {
      client.socket.close();
    } catch (_) {}
    // stop 期间不广播（socket 已被 stop 关闭）
    if (_isStopping) return;
    _broadcastRaw(
      NetworkMessage(
        id: client.id,
        type: MessageType.exit,
        source: roomName,
        content: 'exit',
      ).toSocketData(encryptionKey: encryptionKey),
    );
  }

  Future<void> stop() async {
    _isStopping = true;
    _broadcastTimer?.cancel();

    final exitMsg = NetworkMessage(
      id: 0,
      type: MessageType.exit,
      source: roomName,
      content: 'exit',
    ).toSocketData(encryptionKey: encryptionKey);

    // 发 exit 消息
    for (final client in List.of(_clients)) {
      try {
        client.socket.add(exitMsg);
      } catch (_) {}
    }

    // 等消息发出后再关 socket
    await Future.delayed(const Duration(milliseconds: 100));
    for (final client in List.of(_clients)) {
      try {
        await client.socket.close();
      } catch (_) {}
    }
    _clients.clear();

    // UDP 广播房间关闭（await 确保遍历所有网卡发送完毕）
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
    _tcpServer?.close();
    _httpServer?.close();
    _tcpServer = null;
    _httpServer = null;
  }
}
