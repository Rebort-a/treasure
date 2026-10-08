import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/06.greedy_snake/net_manager.dart' as snake;

import 'support/network_room_harness.dart';
import 'support/match_game_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('回合匹配仅在房间记录对手和先后手，游戏引擎按需启动', () async {
    final h = RoomHarness(3);
    await h.server.start();
    NetTurnEngine? first;
    NetTurnEngine? second;
    try {
      final a = await h.join('A');
      final b = await h.join('B');
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
      expect(a.matchInitiated, isTrue);
      expect(b.matchInitiated, isFalse);
      first = configureTurnEngine(
        room: a,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      )..startFromRoom();
      second = configureTurnEngine(
        room: b,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      )..startFromRoom();
      expect(first.playerType, TurnGamerType.front);
      expect(second.playerType, TurnGamerType.rear);
      expect(first.gameStep.value, GameStep.action);
      expect(second.gameStep.value, GameStep.action);
      a.openMatchedGame();
      b.openMatchedGame();
      expect(h.server.members.length, 2);
    } finally {
      first?.releaseGame();
      second?.releaseGame();
      await h.close();
    }
  });

  test('取消匹配只重置房间意向，重新广播后仍可匹配', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      a.cancelMatching();
      expect(a.matchPhase.value, RoomMatchPhase.idle);
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      b.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matched);
      expect(a.matchedOpponentId, b.identity);
    } finally {
      await h.close();
    }
  });

  test('实时匹配由房间确认发布者，进入对局后才创建游戏管理器', () async {
    final h = RoomHarness(4);
    await h.server.start();
    snake.NetManager? publisher;
    snake.NetManager? joiner;
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      expect(a.matchedOpponentId, 0);
      b.startMatching();
      await waitFor(
        () =>
            a.matchPhase.value == RoomMatchPhase.matched &&
            b.matchPhase.value == RoomMatchPhase.matched,
      );
      expect(a.matchInitiated, isTrue);
      expect(b.matchInitiated, isFalse);
      publisher = snake.NetManager(room: a)..realEngine.startFromRoom();
      joiner = snake.NetManager(room: b)..realEngine.startFromRoom();
      await waitFor(
        () =>
            publisher!.realEngine.gameStep.value == GameStep.action &&
            joiner!.realEngine.gameStep.value == GameStep.action,
      );
      expect(publisher.realEngine.publisherId, a.identity);
      expect(joiner.realEngine.publisherId, a.identity);
    } finally {
      publisher?.dispose();
      joiner?.dispose();
      await h.close();
    }
  });
}
