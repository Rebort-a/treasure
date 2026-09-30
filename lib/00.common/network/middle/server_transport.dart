import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../config/network_config.dart';
import 'server_connection.dart';

/// 负责监听底层传输并将新连接转换为统一的服务端连接。
abstract interface class ServerTransport {
  int get port;

  Future<int> start(void Function(ServerConnection connection) onConnection);

  Future<void> close();
}

/// 根据当前平台和网络配置创建传输实现。
ServerTransport createServerTransport() {
  if (kIsWeb || networkMode == NetworkMode.webSocket) {
    return _WebSocketServerTransport();
  }
  return _TcpServerTransport();
}

class _TcpServerTransport implements ServerTransport {
  ServerSocket? _server;

  @override
  int get port => _server?.port ?? 0;

  @override
  Future<int> start(
    void Function(ServerConnection connection) onConnection,
  ) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server!.listen((socket) {
      onConnection(ServerConnection.tcp(socket));
    });
    return _server!.port;
  }

  @override
  Future<void> close() async {
    await _server?.close();
    _server = null;
  }
}

class _WebSocketServerTransport implements ServerTransport {
  HttpServer? _server;

  @override
  int get port => _server?.port ?? 0;

  @override
  Future<int> start(
    void Function(ServerConnection connection) onConnection,
  ) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        // 房间信息只通过发现广播和入房握手提供，不保留普通 HTTP 查询接口。
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      // WebSocketTransformer 会接管并关闭握手响应流。
      // ignore: close_sinks
      final socket = await WebSocketTransformer.upgrade(request);
      onConnection(ServerConnection.webSocket(socket));
    });
    return _server!.port;
  }

  @override
  Future<void> close() async {
    await _server?.close();
    _server = null;
  }
}
