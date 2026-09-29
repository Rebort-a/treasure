import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/network_message.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('房间、私聊和群组各按自己的接收范围转发', () async {
    final h = RoomHarness(6);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final c = await h.join('C');
      final seenA = <NetworkMessage>[];
      final seenB = <NetworkMessage>[];
      final seenC = <NetworkMessage>[];
      a.addMessageListener(seenA.add);
      b.addMessageListener(seenB.add);
      c.addMessageListener(seenC.add);

      a.sendNetworkMessage(MessageType.text, 'room');
      await waitFor(
        () => [
          seenA,
          seenB,
          seenC,
        ].every((messages) => messages.any((m) => m.content == 'room')),
      );

      a.sendNetworkMessage(MessageType.match, 'offer', recipientId: b.identity);
      await waitFor(
        () =>
            seenA.any((m) => m.content == 'offer') &&
            seenB.any((m) => m.content == 'offer'),
      );
      expect(seenC.where((m) => m.content == 'offer'), isEmpty);

      a.sendNetworkMessage(
        MessageType.action,
        'move',
        recipientIds: {a.identity, b.identity},
      );
      await waitFor(
        () =>
            seenA.any((m) => m.content == 'move') &&
            seenB.any((m) => m.content == 'move'),
      );
      expect(seenC.where((m) => m.content == 'move'), isEmpty);
      expect(seenA.singleWhere((m) => m.content == 'move').recipientIds, {
        a.identity,
        b.identity,
      });
    } finally {
      await h.close();
    }
  });

  test('不合法的消息路由不会退化为房间广播', () {
    NetworkMessage message(
      MessageType type, {
      int? recipientId,
      Set<int>? recipientIds,
    }) => NetworkMessage(
      id: 1,
      type: type,
      source: 'A',
      content: '',
      recipientId: recipientId,
      recipientIds: recipientIds,
    );

    expect(message(MessageType.search).hasValidRoute, isTrue);
    expect(message(MessageType.search, recipientId: 2).hasValidRoute, isFalse);
    expect(message(MessageType.match).hasValidRoute, isFalse);
    expect(
      message(MessageType.match, recipientIds: {1, 2}).hasValidRoute,
      isFalse,
    );
    expect(message(MessageType.confirm, recipientId: 2).hasValidRoute, isTrue);
    expect(
      message(MessageType.action, recipientIds: {}).hasValidRoute,
      isFalse,
    );
    expect(
      message(MessageType.action, recipientIds: {1, 2}).hasValidRoute,
      isTrue,
    );
    expect(message(MessageType.resource, recipientId: 2).hasValidRoute, isTrue);
  });
}
