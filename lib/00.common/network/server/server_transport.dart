import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../config/network_config.dart';
import '../protocol/tcp_frame_codec.dart';

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

typedef ServerDataCallback = void Function(List<int> data);
typedef ServerDoneCallback = void Function();
typedef ServerErrorCallback = void Function(Object error);

/// 服务端传输连接；向房间逻辑提供完整消息，不暴露底层 socket 类型。
abstract interface class ServerConnection {
  factory ServerConnection.tcp(Socket socket) = _TcpServerConnection;
  factory ServerConnection.webSocket(WebSocket socket) =
      _WebSocketServerConnection;

  void listen({
    required ServerDataCallback onData,
    required ServerDoneCallback onDone,
    required ServerErrorCallback onError,
  });

  void send(List<int> data);
  Future<void> close();
}

class _TcpServerConnection implements ServerConnection {
  final Socket _socket;
  final TcpFrameDecoder _decoder = TcpFrameDecoder();
  StreamSubscription<dynamic>? _subscription;

  _TcpServerConnection(this._socket);

  @override
  void listen({
    required ServerDataCallback onData,
    required ServerDoneCallback onDone,
    required ServerErrorCallback onError,
  }) {
    _subscription = _socket.listen(
      (chunk) {
        try {
          for (final message in _decoder.add(chunk)) {
            onData(message);
          }
        } on FormatException catch (error) {
          _socket.destroy();
          onError(error);
        }
      },
      onDone: onDone,
      onError: (Object error) => onError(error),
      cancelOnError: true,
    );
  }

  @override
  void send(List<int> data) => _socket.add(TcpFrameCodec.encode(data));

  @override
  Future<void> close() async {
    try {
      await _socket.close();
    } finally {
      await _subscription?.cancel();
      _socket.destroy();
    }
  }
}

class _WebSocketServerConnection implements ServerConnection {
  final WebSocket _socket;
  StreamSubscription<dynamic>? _subscription;

  _WebSocketServerConnection(this._socket);

  @override
  void listen({
    required ServerDataCallback onData,
    required ServerDoneCallback onDone,
    required ServerErrorCallback onError,
  }) {
    _subscription = _socket.listen(
      (dynamic message) {
        if (message is String) {
          onData(utf8.encode(message));
        } else if (message is List<int>) {
          onData(message);
        } else if (message is TypedData) {
          onData(
            Uint8List.view(
              message.buffer,
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
        } else {
          onError(FormatException('Unsupported WebSocket message type'));
        }
      },
      onDone: onDone,
      onError: (Object error) => onError(error),
    );
  }

  @override
  void send(List<int> data) => _socket.add(Uint8List.fromList(data));

  @override
  Future<void> close() async {
    try {
      await _socket.close();
    } finally {
      await _subscription?.cancel();
    }
  }
}
