import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/network_config.dart';
import 'tcp_frame_codec.dart';

typedef DataCallback = void Function(List<int> data);
typedef DoneCallback = void Function();

class Connection {
  final dynamic _impl;

  Connection._(this._impl);

  static Future<Connection> connect(String host, int port) async {
    if (kIsWeb || networkMode == NetworkMode.webSocket) {
      final channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));
      await channel.ready;
      return Connection._(channel);
    } else {
      // ignore: close_sinks — socket lifecycle managed by close()
      final socket = await Socket.connect(host, port);
      return Connection._(socket);
    }
  }

  void listen({required DataCallback onData, required DoneCallback onDone}) {
    if (_impl is Socket) {
      final decoder = TcpFrameDecoder();
      _impl.listen(
        (List<int> chunk) {
          try {
            for (final payload in decoder.add(chunk)) {
              onData(payload);
            }
          } on FormatException {
            _impl.destroy();
            onDone();
          }
        },
        onDone: onDone,
        onError: (_) => onDone(),
        cancelOnError: true,
      );
    } else {
      _impl.stream.listen(
        (dynamic message) {
          if (message is List<int>) {
            onData(message);
          } else if (message is String) {
            onData(utf8.encode(message));
          }
        },
        onDone: onDone,
        onError: (_) => onDone(),
      );
    }
  }

  void send(List<int> data) {
    if (_impl is Socket) {
      _impl.add(TcpFrameCodec.encode(data));
    } else {
      // Web 端必须用 Uint8List 才能发送二进制帧
      _impl.sink.add(Uint8List.fromList(data));
    }
  }

  Future<void> flush() async {
    if (_impl is Socket) {
      await _impl.flush();
    }
  }

  Future<void> close() async {
    if (_impl is Socket) {
      try {
        await _impl.close();
      } catch (_) {}
    } else {
      await _impl.sink.close();
    }
  }
}
