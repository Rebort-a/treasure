import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/client/network_engine.dart';
import 'package:treasure/06.greedy_snake/net_page.dart';
import 'package:treasure/06.greedy_snake/net_manager.dart' as snake;

import '../00.common/network/support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('实时游戏后手页面晚于资源创建，房间仍能交付资源并完成同步', () async {
    final h = RoomHarness(4);
    await h.server.start();
    snake.NetManager? front;
    snake.NetManager? rear;
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final seenByB = <NetworkMessage>[];
      b.addMessageListener(seenByB.add);
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      b.startMatching();
      await waitFor(
        () =>
            a.matchPhase.value == RoomMatchPhase.matched &&
            b.matchPhase.value == RoomMatchPhase.matched,
      );
      expect(NetGreedySnakePage(room: a), isA<NetGreedySnakePage>());
      front = snake.NetManager(room: a)..realSession.startFromRoom();
      await waitFor(
        () => seenByB.any((message) => message.type == MessageType.resource),
      );
      expect(a.matchInitiated, isTrue);
      expect(front.realSession.gameStep.value, GameStep.synchronizing);

      rear = snake.NetManager(room: b)..realSession.startFromRoom();
      await waitFor(
        () =>
            front!.realSession.gameStep.value == GameStep.action &&
            rear!.realSession.gameStep.value == GameStep.action,
      );
      expect(h.server.members.length, 2);
    } finally {
      front?.dispose();
      rear?.dispose();
      await h.close();
    }
  });
}
