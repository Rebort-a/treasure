import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/session/turn_game_session.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/00.common/network/network_room.dart';
import 'package:treasure/00.common/network/engine/network_engine.dart';

import 'support/network_room_harness.dart';
import 'support/match_game_driver.dart';

NetworkEngine _client(
  int port, {
  String? password,
  Duration timeout = const Duration(seconds: 2),
}) => NetworkEngine(
  userName: 'Alice',
  endpoint: RoomInfo(
    name: 'Test',
    type: 0,
    address: '127.0.0.1',
    port: port,
    password: password,
  ),
  handshakeTimeout: timeout,
  retryBaseDelay: const Duration(milliseconds: 5),
);

void _accept(WebSocket socket, int identity) {
  socket.add(
    NetworkMessage(
      id: 0,
      type: MessageType.accept,
      source: 'Authenticated room',
      content: jsonEncode({
        'clientId': identity,
        'roomType': 3,
        'members': {'$identity': 'Alice'},
        'key': null,
      }),
    ).toSocketData(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('构造引擎没有连接副作用，join 仅在认证成功后完成', () async {
    final h = RoomHarness(3, password: 'secret');
    await h.server.start();
    final room = _client(h.server.port, password: 'secret');
    try {
      expect(room.status.value.state, RoomConnectionState.idle);
      expect(room.identity, 0);
      expect(h.server.members, isEmpty);
      final joined = room.join();
      expect(identical(joined, room.join()), isTrue);
      expect(room.isJoined, isFalse);
      await joined;
      expect(room.isJoined, isTrue);
      expect(room.roomType, 3);
      expect(room.gameMode, RoomGameMode.turn);
      expect(room.members.value[room.identity], 'Alice');
      expect(h.server.members.length, 1);
    } finally {
      await room.close();
      room.dispose();
      await h.close();
    }
  });

  test('密码错误不产生成员、不重连，只返回结构化失败', () async {
    final h = RoomHarness(3, password: 'secret');
    await h.server.start();
    final room = _client(h.server.port, password: 'wrong');
    try {
      await expectLater(
        room.join(),
        throwsA(
          isA<RoomJoinException>().having(
            (e) => e.reason,
            'reason',
            RoomFailure.invalidPassword,
          ),
        ),
      );
      expect(room.identity, 0);
      expect(room.isJoined, isFalse);
      expect(room.status.value.failure, RoomFailure.invalidPassword);
      expect(h.server.members, isEmpty);
    } finally {
      room.dispose();
      await h.close();
    }
  });

  test('连接建立但未收到认证结果时超时，不能把传输连接当成入房成功', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
    });
    final room = _client(
      server.port,
      timeout: const Duration(milliseconds: 150),
    );
    try {
      await expectLater(
        room.join(),
        throwsA(
          isA<RoomJoinException>().having(
            (e) => e.reason,
            'reason',
            RoomFailure.timeout,
          ),
        ),
      );
      expect(room.isJoined, isFalse);
      expect(room.identity, 0);
      expect(room.status.value.failure, RoomFailure.timeout);
    } finally {
      room.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    }
  });

  test('重连必须再次认证，期间不能发送；原对局结束而房间聊天保留', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final handshakes = <WebSocket>[];
    final incoming = <String>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((data) {
        final bytes = data is String ? utf8.encode(data) : data as List<int>;
        final message = NetworkMessage.fromSocketData(bytes);
        if (message?.type == MessageType.connect) {
          handshakes.add(socket);
          if (handshakes.length == 1) _accept(socket, 1);
        } else {
          incoming.add(utf8.decode(bytes));
        }
      });
    });
    final room = _client(server.port);
    TurnGameSession? game;
    try {
      await room.join();
      sockets.first.add(
        NetworkMessage(
          id: 2,
          type: MessageType.text,
          source: 'Bob',
          content: '已有聊天',
        ).toSocketData(),
      );
      await waitFor(
        () => room.messageList.value.any((m) => m.content == '已有聊天'),
      );
      game = startGame(
        TurnGameSession(
          room: room,
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        ),
      );
      await sockets.first.close();
      await waitFor(() => handshakes.length == 2);
      expect(room.identity, 0);
      expect(room.isJoined, isFalse);
      expect(room.status.value.state, RoomConnectionState.authenticating);
      expect(game.ended.value, isTrue);
      room.sendText('未认证不能发');
      _accept(sockets.last, 3);
      await waitFor(() => room.isJoined);
      expect(room.identity, 3);
      expect(incoming.any((m) => m.contains('未认证不能发')), isFalse);
      expect(room.messageList.value.any((m) => m.content == '已有聊天'), isTrue);
      expect(game.ended.value, isTrue);
    } finally {
      game?.dispose();
      await room.close();
      room.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    }
  });
}
