import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('收到自己的 search 回环后才显示匹配；取消不广播', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final wire = <NetworkMessage>[];
      b.addMessageListener(wire.add);
      expect(a.matchPhase.value, RoomMatchPhase.idle);
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      await waitFor(() => wire.where(_isSearchMessage).length == 1);
      a.cancelMatching();
      expect(a.matchPhase.value, RoomMatchPhase.idle);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(wire.where(_isSearchMessage), hasLength(1));
      expect(wire.where((m) => m.type == MessageType.exit), isEmpty);

      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      b.startMatching();
      await waitFor(
        () =>
            a.matchPhase.value == RoomMatchPhase.matched &&
            b.matchPhase.value == RoomMatchPhase.matched,
      );
      expect(a.matchedOpponentId, b.identity);
      expect(b.matchedOpponentId, a.identity);
    } finally {
      await h.close();
    }
  });

  test('单聊 match 和 confirm 仅回环发送者与指定接收者', () async {
    final h = RoomHarness(3);
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
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      b.startMatching();
      await waitFor(
        () =>
            a.matchPhase.value == RoomMatchPhase.matched &&
            b.matchPhase.value == RoomMatchPhase.matched,
      );
      for (final type in [MessageType.match, MessageType.confirm]) {
        expect(seenA.where((m) => m.type == type), isNotEmpty);
        expect(seenB.where((m) => m.type == type), isNotEmpty);
        expect(seenC.where((m) => m.type == type), isEmpty);
      }
      expect(
        seenA
            .where(
              (m) =>
                  m.type == MessageType.match || m.type == MessageType.confirm,
            )
            .every((m) => m.id == a.identity || m.id == b.identity),
        isTrue,
      );
      expect(
        seenA.any(
          (m) =>
              m.type == MessageType.confirm && m.content.startsWith('commit:'),
        ),
        isTrue,
      );
    } finally {
      await h.close();
    }
  });
}

bool _isSearchMessage(NetworkMessage message) =>
    message.type == MessageType.search && message.isRoomMessage;
