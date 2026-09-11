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

  _WsClient(this.socket, this.id, {this.tcpDecoder});
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
  final int maxClients;

  SocketServer({
    required this.roomName,
    required this.roomType,
    this.encryptionKey,
    this.maxClients = 8,
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
    if (_clients.length >= maxClients) {
      debugPrint('[Server] 拒绝连接：已达人数上限 $maxClients');
      socket.destroy();
      return;
    }
    _idCounter++;
    final client = _WsClient(socket, _idCounter, tcpDecoder: TcpFrameDecoder());
    _clients.add(client);
    debugPrint(
      '[Server] TCP client #${client.id} connected. Total: ${_clients.length}',
    );

    socket.listen(
      (data) {
        if (_clients.contains(client)) {
          try {
            for (final payload in client.tcpDecoder!.add(data)) {
              _broadcastRaw(payload);
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
    if (_clients.length >= maxClients) {
      debugPrint('[Server] 拒绝连接：已达人数上限 $maxClients');
      ws.close();
      return;
    }
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

      _broadcastRaw(bytes);
    } catch (e) {
      debugPrint('[Server] Error from #${sender.id}: $e');
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
      _sendTo(client, data);
    }
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
      _sendTo(client, exitMsg);
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
    await _tcpServer?.close();
    await _httpServer?.close();
    _tcpServer = null;
    _httpServer = null;
  }
}
