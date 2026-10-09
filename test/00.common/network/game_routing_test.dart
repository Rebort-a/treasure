import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('服务端原样转发玩家 search 消息', () async {
    final h = RoomHarness(0);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final received = <NetworkMessage>[];
      b.addMessageListener(received.add);

      a.sendNetworkMessage(MessageType.search, 'search');
      await waitFor(
        () => received.any((message) => message.type == MessageType.search),
      );
      // 消息类型、发起者身份与内容都保持原样，服务端只改写来源昵称。
      final forwarded = received.singleWhere(
        (message) => message.type == MessageType.search,
      );
      expect(forwarded.id, a.identity);
      expect(forwarded.source, 'A');
      expect(forwarded.content, 'search');
      expect(forwarded.isRoomMessage, isTrue);

      // 同一次搜索还会补发一条展示用通知，供聊天流显示。
      final notice = received.singleWhere(
        (message) =>
            message.type == MessageType.notify &&
            RoomNotification.tryFromContent(message.content)?.type ==
                NoticeType.search,
      );
      expect(notice.id, 0);
      expect(
        RoomNotification.tryFromContent(notice.content)?.memberId,
        a.identity,
      );
    } finally {
      await h.close();
    }
  });

  test('客户端不能发送服务器通知', () async {
    final h = RoomHarness(0);
    await h.server.start();
    try {
      final a = await h.join('A');
      expect(
        () => a.sendNetworkMessage(
          MessageType.notify,
          const RoomNotification(type: NoticeType.close).content,
        ),
        throwsArgumentError,
      );
    } finally {
      await h.close();
    }
  });

  test('空集合公开广播，非空集合严格投递且不隐式回环发送者', () async {
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

      a.sendNetworkMessage(
        MessageType.match,
        'offer',
        recipientIds: {b.identity},
      );
      await waitFor(() => seenB.any((m) => m.content == 'offer'));
      expect(seenA.where((m) => m.content == 'offer'), isEmpty);
      expect(seenC.where((m) => m.content == 'offer'), isEmpty);
      await waitFor(() => a.deliveryConfirmed.value?.content == 'offer');

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
      a.sendNetworkMessage(
        MessageType.text,
        'others only',
        recipientIds: {b.identity, c.identity},
      );
      await waitFor(
        () =>
            seenB.any((m) => m.content == 'others only') &&
            seenC.any((m) => m.content == 'others only'),
      );
      expect(seenA.where((m) => m.content == 'others only'), isEmpty);
      a.sendNetworkMessage(
        MessageType.text,
        'self only',
        recipientIds: {a.identity},
      );
      await waitFor(() => seenA.any((m) => m.content == 'self only'));
      expect(seenB.where((m) => m.content == 'self only'), isEmpty);
      expect(seenC.where((m) => m.content == 'self only'), isEmpty);
    } finally {
      await h.close();
    }
  });

  test('不合法的消息路由不会退化为房间广播', () {
    NetworkMessage message(
      MessageType type, {
      Set<int> recipientIds = const {},
    }) => NetworkMessage(
      id: 1,
      type: type,
      source: 'A',
      content: '',
      timestamp: 1,
      recipientIds: recipientIds,
    );

    expect(message(MessageType.search).hasValidRoute, isTrue);
    expect(
      message(MessageType.search, recipientIds: {2}).hasValidRoute,
      isFalse,
    );
    expect(message(MessageType.match).hasValidRoute, isFalse);
    expect(
      message(MessageType.match, recipientIds: {1, 2}).hasValidRoute,
      isFalse,
    );
    expect(
      message(MessageType.confirm, recipientIds: {2}).hasValidRoute,
      isTrue,
    );
    expect(
      message(MessageType.action, recipientIds: {}).hasValidRoute,
      isFalse,
    );
    expect(
      message(MessageType.action, recipientIds: {1, 2}).hasValidRoute,
      isTrue,
    );
    expect(
      message(MessageType.resource, recipientIds: {2}).hasValidRoute,
      isTrue,
    );
  });

  test('收件人不在册时整条消息被丢弃，exit 不再例外', () async {
    final h = RoomHarness(0);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final c = await h.join('C');
      final seenB = <NetworkMessage>[];
      b.addMessageListener(seenB.add);
      final cId = c.identity;

      await c.close();
      await waitFor(() => h.server.members.length == 2);

      // 收件人全部在册时正常送达。
      a.sendNetworkMessage(
        MessageType.exit,
        'game',
        recipientIds: {a.identity, b.identity},
      );
      await waitFor(() => seenB.any((m) => m.type == MessageType.exit));

      // 名单里混入已离开的 C：整条 exit 被丢弃，在册的 B 也收不到。
      a.sendNetworkMessage(
        MessageType.exit,
        'game',
        recipientIds: {a.identity, b.identity, cId},
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(seenB.where((m) => m.type == MessageType.exit), hasLength(1));
    } finally {
      await h.close();
    }
  });
}
