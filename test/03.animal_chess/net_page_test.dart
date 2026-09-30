import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/client/network_engine.dart';
import 'package:treasure/03.animal_chess/net_page.dart';
import 'package:treasure/03.animal_chess/net_manager.dart' as chess;

import '../00.common/network/support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('斗兽棋大厅不提前启动对局；后手引擎尚未创建时房间保留先手资源', () async {
    final h = RoomHarness(1);
    await h.server.start();
    chess.NetManager? front;
    chess.NetManager? rear;
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
      expect(NetAnimalChessPage(room: a), isA<NetAnimalChessPage>());
      front = chess.NetManager(room: a)..turnSession.startFromRoom();
      await waitFor(
        () => seenByB.any((message) => message.type == MessageType.resource),
      );
      expect(front.turnSession.gameStep.value, GameStep.action);
      expect(h.server.members.length, 2);

      rear = chess.NetManager(room: b)..turnSession.startFromRoom();
      await waitFor(
        () => rear!.turnSession.gameStep.value == GameStep.action,
      );
      expect(front.turnSession.ended.value, isFalse);
      expect(rear.turnSession.ended.value, isFalse);
    } finally {
      front?.dispose();
      rear?.dispose();
      await h.close();
    }
  });
}
