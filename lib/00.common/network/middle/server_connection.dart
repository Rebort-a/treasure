import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../base/tcp_frame_codec.dart';

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
