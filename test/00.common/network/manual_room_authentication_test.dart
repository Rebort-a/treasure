import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/base/client_abstract.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/00.common/network/server/server_abstract.dart';

import 'support/network_room_harness.dart';

class _TcpTransport implements ClientTransport {
  @override
  Future<ClientConnection> connect(String host, int port) async =>
      ClientConnection.tcp(await Socket.connect(host, port));
}

NetworkMessage _accept(int identity, Object? key) => NetworkMessage(
  id: 0,
  type: MessageType.accept,
  source: 'Server room',
  content: jsonEncode({
    'clientId': identity,
    'roomType': 3,
    'members': {'$identity': 'Alice'},
    if (key != null) 'key': key,
  }),
  timestamp: 1,
);

SocketClient _manual(int port, {ClientTransport? transport}) => SocketClient(
  userName: 'Alice',
  endpoint: RoomEndpoint(address: '127.0.0.1', port: port),
  transport: transport,
  handshakeTimeout: const Duration(seconds: 2),
  retryBaseDelay: const Duration(milliseconds: 5),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  for (final password in <String?>[null, 'secret']) {
    test('无预设密钥连接真实服务器，认证后能加密收发：password=$password', () async {
      final h = RoomHarness(3, password: password, key: 'server-only-key');
      await h.server.start();
      final room = SocketClient(
        userName: 'Alice',
        endpoint: RoomEndpoint(
          address: '127.0.0.1',
          port: h.server.port,
          password: password,
        ),
      );
      final messages = <NetworkMessage>[];
      room.addMessageListener(messages.add);
      try {
        expect(() => room.encryptionKey, throwsStateError);
        await room.join();
        expect(room.encryptionKey, 'server-only-key');
        expect(room.roomType, 3);
        room.sendNetworkMessage(MessageType.text, 'encrypted echo');
        await waitFor(() => messages.any((m) => m.content == 'encrypted echo'));
      } finally {
        await room.close();
        room.dispose();
        await h.close();
      }
    });
  }

  test('已发现房间仍拒绝密钥不一致的认证回执', () async {
    final h = RoomHarness(3, key: 'server-key');
    await h.server.start();
    final room = SocketClient(
      userName: 'Alice',
      endpoint: RoomInfo(
        name: 'Discovered room',
        type: 3,
        address: '127.0.0.1',
        port: h.server.port,
        encryptionKey: 'different-key',
      ),
    );
    try {
      await expectLater(
        room.join(),
        throwsA(
          isA<RoomJoinException>().having(
            (e) => e.reason,
            'reason',
            RoomFailure.invalidResponse,
          ),
        ),
      );
      expect(room.isJoined, isFalse);
      expect(() => room.encryptionKey, throwsStateError);
      await waitFor(() => h.server.members.isEmpty);
    } finally {
      room.dispose();
      await h.close();
    }
  });

  for (final key in <Object?>[null, '', 42]) {
    test('手动加入拒绝缺失、空或非字符串的服务器密钥：key=$key', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((_) => socket.add(_accept(1, key).toPlainSocketData()));
      });
      final room = _manual(server.port);
      try {
        await expectLater(
          room.join(),
          throwsA(
            isA<RoomJoinException>().having(
              (e) => e.reason,
              'reason',
              RoomFailure.invalidResponse,
            ),
          ),
        );
        expect(room.identity, 0);
        expect(room.members.value, isEmpty);
        expect(() => room.encryptionKey, throwsStateError);
      } finally {
        room.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      }
    });
  }

  test('原生 TCP 手动加入也从明文认证回执获取通信密钥', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final connections = <ServerConnection>[];
    final incoming = <NetworkMessage>[];
    server.listen((socket) {
      final connection = ServerConnection.tcp(socket);
      connections.add(connection);
      connection.listen(
        onData: (bytes) {
          final request = NetworkMessage.fromPlainSocketData(bytes);
          if (request?.type == MessageType.connect) {
            connection.send(_accept(1, 'tcp-key').toPlainSocketData());
          } else {
            final message = NetworkMessage.fromSocketData(
              bytes,
              encryptionKey: 'tcp-key',
            );
            if (message != null) {
              incoming.add(message);
              connection.send(message.toSocketData(encryptionKey: 'tcp-key'));
            }
          }
        },
        onDone: () {},
        onError: (_) {},
      );
    });
    final room = _manual(server.port, transport: _TcpTransport());
    final messages = <NetworkMessage>[];
    room.addMessageListener(messages.add);
    try {
      await room.join();
      expect(room.encryptionKey, 'tcp-key');
      room.sendNetworkMessage(MessageType.text, 'tcp encrypted');
      await waitFor(() => messages.any((m) => m.content == 'tcp encrypted'));
      expect(incoming.single.content, 'tcp encrypted');
    } finally {
      await room.close();
      room.dispose();
      for (final connection in connections) {
        await connection.close();
      }
      await server.close();
    }
  });

  test('手动加入重连重新认证并使用新密钥，不沿用旧通信密钥', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final incoming = <NetworkMessage>[];
    var handshakes = 0;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((data) {
        final bytes = data is String ? utf8.encode(data) : data as List<int>;
        final message = NetworkMessage.fromPlainSocketData(bytes);
        if (message?.type == MessageType.connect) {
          handshakes++;
          if (handshakes == 1) {
            socket.add(_accept(1, 'old-key').toPlainSocketData());
          }
        } else {
          final encrypted = NetworkMessage.fromSocketData(
            bytes,
            encryptionKey: 'new-key',
          );
          if (encrypted != null) incoming.add(encrypted);
        }
      });
    });
    final room = _manual(server.port);
    final messages = <NetworkMessage>[];
    room.addMessageListener(messages.add);
    try {
      await room.join();
      expect(room.encryptionKey, 'old-key');
      await sockets.first.close();
      await waitFor(() => handshakes == 2);
      expect(room.isJoined, isFalse);
      expect(() => room.encryptionKey, throwsStateError);
      room.sendNetworkMessage(MessageType.text, 'must not send');
      sockets.last.add(_accept(2, 'new-key').toPlainSocketData());
      await waitFor(() => room.isJoined);
      expect(room.encryptionKey, 'new-key');
      expect(room.endpoint, isNot(isA<RoomInfo>()));
      room.sendNetworkMessage(MessageType.text, 'new encrypted');
      await waitFor(() => incoming.isNotEmpty);
      expect(incoming.map((m) => m.content), ['new encrypted']);
      sockets.last.add(
        NetworkMessage(
          id: 2,
          type: MessageType.text,
          source: 'Alice',
          content: 'new encrypted reply',
          timestamp: 1,
        ).toSocketData(encryptionKey: 'new-key'),
      );
      await waitFor(
        () => messages.any((m) => m.content == 'new encrypted reply'),
      );
    } finally {
      await room.close();
      room.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    }
  });
}
