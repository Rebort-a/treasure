import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/network_message.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('accept assigns ID and room type as a server message', () async {
    final h = RoomHarness(4, password: 'secret', key: 'room-key');
    await h.server.start();
    WebSocket? socket;
    StreamIterator<dynamic>? incoming;
    try {
      socket = await WebSocket.connect('ws://127.0.0.1:${h.server.port}');
      incoming = StreamIterator<dynamic>(socket);
      socket.add(
        jsonEncode({'connect': true, 'password': 'secret', 'name': 'A'}),
      );
      expect(await incoming.moveNext(), isTrue);
      final accepted = NetworkMessage.fromSocketData(
        incoming.current as List<int>,
      )!;
      expect(accepted.id, 0);
      expect(accepted.type, MessageType.accept);
      final data = jsonDecode(accepted.content) as Map<String, dynamic>;
      expect(data['clientId'], greaterThan(0));
      expect(data['roomType'], 4);
      expect(data['key'], 'room-key');
      expect(h.server.session.count, 1);
    } finally {
      await socket?.close();
      await incoming?.cancel();
      await h.close();
    }
  });

  test('wrong password is rejected before joining the member list', () async {
    final h = RoomHarness(3, password: 'secret', key: 'key');
    await h.server.start();
    WebSocket? socket;
    StreamIterator<dynamic>? incoming;
    try {
      socket = await WebSocket.connect('ws://127.0.0.1:${h.server.port}');
      incoming = StreamIterator<dynamic>(socket);
      socket.add(
        jsonEncode({'connect': true, 'password': 'wrong', 'name': 'A'}),
      );
      expect(await incoming.moveNext(), isTrue);
      final message = NetworkMessage.fromSocketData(
        incoming.current as List<int>,
      )!;
      expect(jsonDecode(message.content)['error'], 'invalidPassword');
      expect(h.server.session.count, 0);
    } finally {
      await socket?.close();
      await incoming?.cancel();
      await h.close();
    }
  });

  test('IP 加入从 accept 获取类型和密钥，成员快照随进出更新', () async {
    final h = RoomHarness(6, password: 'secret', key: 'room-key');
    await h.server.start();
    try {
      expect(h.server.session.count, 0);
      final room = await h.join('A', password: 'secret');
      expect(room.roomSession.value.game, 6);
      expect(room.encryptionKey, 'room-key');
      await waitFor(() => room.roomSession.value.count == 1);
      final other = await h.join('B', password: 'secret');
      await waitFor(() => room.roomSession.value.count == 2);
      expect(h.server.session.count, 2);
      await other.closeSocket();
      await waitFor(() => room.roomSession.value.count == 1);
      await room.closeSocket();
      await waitFor(() => h.server.session.count == 0);
    } finally {
      await h.close();
    }
  });

  test('普通 HTTP 请求不再暴露房间信息，WebSocket 握手仍可用', () async {
    final h = RoomHarness(3, key: 'room-key');
    final client = HttpClient();
    await h.server.start();
    try {
      final response = await (await client.getUrl(
        Uri.parse('http://127.0.0.1:${h.server.port}/'),
      )).close();
      expect(response.statusCode, HttpStatus.notFound);
      expect(await utf8.decoder.bind(response).join(), isEmpty);
      final room = await h.join('A');
      expect(room.roomSession.value.game, 3);
      expect(room.encryptionKey, 'room-key');
    } finally {
      client.close(force: true);
      await h.close();
    }
  });

  test(
    'targeted messages only reach their target; others reach the room',
    () async {
      final h = RoomHarness(3);
      await h.server.start();
      try {
        final a = await h.join('A');
        final b = await h.join('B');
        final c = await h.join('C');
        final message = NetworkMessage(
          id: a.identity,
          type: MessageType.text,
          source: 'A',
          content: 'private',
          targetId: b.identity,
          sessionId: 'game-run',
        );
        final restored = NetworkMessage.fromJsonString(message.toJsonString())!;
        expect(restored.targetId, b.identity);
        expect(restored.sessionId, 'game-run');
        final receivedB = <String>[];
        final receivedC = <String>[];
        b.addMessageListener((m) => receivedB.add(m.content));
        c.addMessageListener((m) => receivedC.add(m.content));
        a.sendNetworkMessage(
          MessageType.text,
          'private',
          targetId: b.identity,
          sessionId: 'game-run',
        );
        a.sendNetworkMessage(MessageType.text, 'public');
        await waitFor(
          () => receivedB.contains('public') && receivedC.contains('public'),
        );
        expect(receivedB, contains('private'));
        expect(receivedC, isNot(contains('private')));
        expect(b.messageList.value.any((m) => m.content == 'private'), isFalse);
        expect(b.messageList.value.any((m) => m.content == 'public'), isTrue);
      } finally {
        await h.close();
      }
    },
  );
}
