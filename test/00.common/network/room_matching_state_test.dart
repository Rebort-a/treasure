import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('四人同时搜索只组成两对；忙碌拒绝后能尝试下一个人', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final c = await h.join('C');
      final d = await h.join('D');
      a.startMatching();
      b.startMatching();
      c.startMatching();
      d.startMatching();
      await waitFor(
        () => h.rooms.every(
          (room) => room.matchPhase.value == RoomMatchPhase.matched,
        ),
      );
      for (final room in h.rooms) {
        final opponent = h.rooms.singleWhere(
          (candidate) => candidate.identity == room.matchedOpponentId,
        );
        expect(opponent.matchedOpponentId, room.identity);
        expect(opponent.matchInitiated, !room.matchInitiated);
      }
      expect(
        h.rooms.map((room) {
          final ids = [room.identity, room.matchedOpponentId]..sort();
          return '${ids.first}-${ids.last}';
        }).toSet(),
        hasLength(2),
      );
    } finally {
      await h.close();
    }
  });

  test('第三人等待已锁定的两人时，新成员搜索仍能与第三人配对', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final c = await h.join('C');
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      b.startMatching();
      c.startMatching();
      await waitFor(
        () =>
            a.matchPhase.value == RoomMatchPhase.matched &&
            b.matchPhase.value == RoomMatchPhase.matched,
      );
      expect(c.matchPhase.value, RoomMatchPhase.matching);
      final d = await h.join('D');
      d.startMatching();
      await waitFor(
        () =>
            c.matchPhase.value == RoomMatchPhase.matched &&
            d.matchPhase.value == RoomMatchPhase.matched,
      );
      expect(c.matchedOpponentId, d.identity);
      expect(d.matchedOpponentId, c.identity);
    } finally {
      await h.close();
    }
  });

  test('迟到的旧确认不能提交另一轮邀请', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final inviter = await h.join('Inviter');
      final joiner = await h.join('Joiner');
      final seen = <NetworkMessage>[];
      inviter.addMessageListener(seen.add);
      joiner.startMatching();
      await waitFor(() => joiner.matchPhase.value == RoomMatchPhase.matching);
      final offerId = inviter.sendNetworkMessage(
        MessageType.match,
        '',
        recipientIds: {joiner.identity},
        gameId: 'test-game',
      )!;
      await waitFor(
        () => seen.any(
          (m) =>
              m.type == MessageType.confirm && m.content == 'accept:$offerId',
        ),
      );
      inviter.sendNetworkMessage(
        MessageType.confirm,
        'commit:previous-round',
        recipientIds: {joiner.identity},
        gameId: 'test-game',
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(joiner.matchPhase.value, RoomMatchPhase.matching);
      inviter.sendNetworkMessage(
        MessageType.confirm,
        'commit:$offerId',
        recipientIds: {joiner.identity},
        gameId: 'test-game',
      );
      await waitFor(
        () => seen.any(
          (m) => m.type == MessageType.confirm && m.content == 'ready:$offerId',
        ),
      );
      expect(joiner.matchPhase.value, RoomMatchPhase.matching);
      inviter.sendNetworkMessage(
        MessageType.confirm,
        'start:$offerId',
        recipientIds: {joiner.identity},
        gameId: 'test-game',
      );
      await waitFor(() => joiner.matchPhase.value == RoomMatchPhase.matched);
      expect(joiner.matchedOpponentId, inviter.identity);
    } finally {
      await h.close();
    }
  });
}
