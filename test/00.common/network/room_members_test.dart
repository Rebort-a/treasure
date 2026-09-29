import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/network_message.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('输入框发送的纯表情和混合文字均走房间 text 消息', () async {
    final h = RoomHarness(0);
    await h.server.start();
    try {
      final sender = await h.join('Alice');
      final receiver = await h.join('Bob');
      sender.sendText('🙂');
      sender.sendText('你好 👨‍👩‍👧‍👦');
      await waitFor(
        () =>
            receiver.messageList.value
                .where((message) => message.type == MessageType.text)
                .length ==
            2,
      );
      final messages = receiver.messageList.value
          .where((message) => message.type == MessageType.text)
          .toList();
      expect(messages.map((message) => message.content), [
        '🙂',
        '你好 👨‍👩‍👧‍👦',
      ]);
    } finally {
      await h.close();
    }
  });

  test('accept 返回身份、房间类型和初始成员表', () async {
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
      expect(data['gameMode'], 'real');
      expect(data['members'], {'${data['clientId']}': 'A'});
      expect(data['key'], 'room-key');
      expect(h.server.members.length, 1);
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
      expect(message.type, MessageType.accept);
      expect(jsonDecode(message.content)['error'], 'invalidPassword');
      expect(h.server.members.length, 0);
    } finally {
      await socket?.close();
      await incoming?.cancel();
      await h.close();
    }
  });

  test('客户端从 accept 初始化房间，随后通过通知和退出事件更新成员', () async {
    final h = RoomHarness(6, password: 'secret', key: 'room-key');
    await h.server.start();
    try {
      expect(h.server.members.length, 0);
      final room = await h.join('A', password: 'secret');
      expect(room.roomType, 6);
      expect(room.encryptionKey, 'room-key');
      await waitFor(() => room.members.value.length == 1);
      final other = await h.join('B', password: 'secret');
      await waitFor(() => room.members.value.length == 2);
      expect(room.members.value.values, containsAll(['A', 'B']));
      expect(other.members.value.values, containsAll(['A', 'B']));
      expect(h.server.members.length, 2);
      await other.close();
      await waitFor(() => room.members.value.length == 1);
      expect(room.members.value.values, contains('A'));
      await room.close();
      await waitFor(() => h.server.members.length == 0);
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
      expect(room.roomType, 3);
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
          recipientIds: {b.identity},
        );
        final restored = NetworkMessage.fromJsonString(message.toJsonString())!;
        expect(restored.recipientIds, {b.identity});
        final receivedB = <String>[];
        final receivedC = <String>[];
        b.addMessageListener((m) => receivedB.add(m.content));
        c.addMessageListener((m) => receivedC.add(m.content));
        a.sendNetworkMessage(
          MessageType.text,
          'private',
          recipientIds: {b.identity},
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
