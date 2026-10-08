import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../config/network_config.dart';
import '../../protocol/tcp_frame_codec.dart';

typedef ClientDataCallback = void Function(List<int> data);
typedef ClientDoneCallback = void Function();
typedef ClientErrorCallback = void Function(Object error);

/// 客户端传输连接；向房间引擎提供完整消息，不暴露底层连接类型。
abstract interface class ClientConnection {
  factory ClientConnection.tcp(Socket socket) = _TcpClientConnection;

  void listen({
    required ClientDataCallback onData,
    required ClientDoneCallback onDone,
    required ClientErrorCallback onError,
  });

  void send(List<int> data);
  Future<void> flush();
  Future<void> close();
}

class _TcpClientConnection implements ClientConnection {
  final Socket _socket;
  final TcpFrameDecoder _decoder = TcpFrameDecoder();
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _closeFuture;

  _TcpClientConnection(this._socket);

  @override
  void listen({
    required ClientDataCallback onData,
    required ClientDoneCallback onDone,
    required ClientErrorCallback onError,
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
  Future<void> flush() => _socket.flush();

  @override
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    try {
      await _socket.close();
    } finally {
      await _subscription?.cancel();
      _socket.destroy();
    }
  }
}

/// WebSocket 客户端连接适配器；第三方依赖仅在本文件导入。
class WebSocketClientConnection implements ClientConnection {
  final WebSocketChannel _channel;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _closeFuture;

  WebSocketClientConnection._(this._channel);

  static Future<WebSocketClientConnection> connect(
    String host,
    int port,
  ) async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));
    await channel.ready;
    return WebSocketClientConnection._(channel);
  }

  @override
  void listen({
    required ClientDataCallback onData,
    required ClientDoneCallback onDone,
    required ClientErrorCallback onError,
  }) {
    _subscription = _channel.stream.listen(
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
  void send(List<int> data) => _channel.sink.add(Uint8List.fromList(data));

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    try {
      await _channel.sink.close();
    } finally {
      await _subscription?.cancel();
    }
  }
}

/// 创建客户端连接的传输方式；具体连接生命周期由 [ClientConnection] 管理。
abstract interface class ClientTransport {
  Future<ClientConnection> connect(String host, int port);
}

/// 根据当前平台和网络配置创建客户端传输实现。
ClientTransport createClientTransport() {
  if (kIsWeb || networkMode == NetworkMode.webSocket) {
    return _WebSocketClientTransport();
  }
  return _TcpClientTransport();
}

class _TcpClientTransport implements ClientTransport {
  @override
  Future<ClientConnection> connect(String host, int port) async {
    // ignore: close_sinks — socket lifecycle managed by ClientConnection.close()
    final socket = await Socket.connect(host, port);
    return ClientConnection.tcp(socket);
  }
}

class _WebSocketClientTransport implements ClientTransport {
  @override
  Future<ClientConnection> connect(String host, int port) =>
      WebSocketClientConnection.connect(host, port);
}
