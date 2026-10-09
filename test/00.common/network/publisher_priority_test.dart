import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/network/client/net_real_engine.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/18.match_three/middle/net_manager.dart';

import 'support/match_game_driver.dart';
import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('实时先搜索的大 ID 玩家首次发布，小 ID 加入不抢占，退出后才竞选', () async {
    final h = RoomHarness(OnlineItemType.greedySnake.index);
    final engines = <NetRealEngine>[];
    final publications = <int, int>{};
    final received = <NetworkMessage>[];
    await h.server.start();
    try {
      final b = await h.join('B');
      final a = await h.join('A');
      final c = await h.join('C');
      expect(a.identity, greaterThan(b.identity));
      NetRealEngine configure(SocketClient room) {
        final engine = NetRealEngine.forClient(room);
        engine.configureGame(
          searchHandler: (_) {
            publications.update(
              engine.identity,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
            engine.sendGameMessage(MessageType.resource, '{}');
          },
          resourceHandler: (message) {
            received.add(message);
            engine.completeSynchronization();
          },
          syncHandler: (_) {},
          actionHandler: (_) {},
          exitHandler: (_) {},
        );
        engines.add(engine);
        return engine;
      }

      final first = configure(a);
      final second = configure(b);
      startGame(first);
      await waitFor(() => first.matchPhase.value == RoomMatchPhase.matching);
      startGame(second);
      await waitFor(
        () => [first, second].every((e) => e.gameStep.value == GameStep.action),
      );
      expect(first.matchInitiated, isTrue);
      expect(second.matchInitiated, isFalse);
      expect(received.first.id, a.identity);
      expect([first, second].every((e) => e.publisherId == a.identity), isTrue);
      expect(publications[b.identity], isNull);
      final third = configure(c);
      startGame(third);
      await waitFor(
        () => engines.every(
          (e) =>
              e.participants.length == 3 && e.gameStep.value == GameStep.action,
        ),
      );
      second.sendGameMessage(MessageType.publish, '');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(engines.every((e) => e.publisherId == a.identity), isTrue);
      expect(publications[b.identity], isNull);
      final session = first.gameId;
      first.leavePage();
      await waitFor(
        () => [second, third].every(
          (e) =>
              e.publisherId == b.identity &&
              e.gameStep.value == GameStep.action,
        ),
      );
      expect(publications[b.identity], 1);
      expect(second.gameId, session);
      expect(third.gameId, session);
    } finally {
      for (final engine in engines) {
        engine.releaseGame();
      }
      await h.close();
    }
  });

  test('三消先搜索的大 ID 玩家首次发布并先行动，轮转和后续竞选独立', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    final resources = <NetworkMessage>[];
    await h.server.start();
    try {
      final b = await h.join('B');
      final a = await h.join('A');
      final c = await h.join('C');
      expect(a.identity, greaterThan(b.identity));
      b.addMessageListener((message) {
        if (message.type == MessageType.resource) resources.add(message);
      });
      NetMatchManager create(SocketClient room) {
        final manager = NetMatchManager(room: room)..reduceMotion = true;
        games.add(manager);
        return manager;
      }

      final first = create(a);
      final second = create(b);
      startGame(first.turnEngine);
      await waitFor(
        () => first.turnEngine.matchPhase.value == RoomMatchPhase.matching,
      );
      startGame(second.turnEngine);
      await waitFor(() => games.every((g) => g.turnEngine.synchronized.value));
      expect(first.turnEngine.matchInitiated, isTrue);
      expect(second.turnEngine.matchInitiated, isFalse);
      expect(resources.first.id, a.identity);
      expect(
        games.every((g) => g.turnEngine.publisherId == a.identity),
        isTrue,
      );
      expect(
        games.every((g) => g.turnEngine.currentPlayer.value == a.identity),
        isTrue,
      );
      expect(first.canInteract, isTrue);
      expect(second.canInteract, isFalse);
      final move = first.board!.legalMoves.first;
      first.swap(move.$1, move.$2);
      await waitFor(
        () => games.every(
          (g) => g.board!.moveNumber == 1 && g.turnEngine.synchronized.value,
        ),
      );
      expect(
        games.every((g) => g.turnEngine.currentPlayer.value == b.identity),
        isTrue,
      );
      final third = create(c);
      startGame(third.turnEngine);
      await waitFor(
        () => games.every(
          (g) =>
              g.turnEngine.participants.length == 3 &&
              g.turnEngine.synchronized.value,
        ),
      );
      expect(
        games.every((g) => g.turnEngine.publisherId == a.identity),
        isTrue,
      );
      expect(
        games.every((g) => g.turnEngine.currentPlayer.value == b.identity),
        isTrue,
      );
      final session = first.turnEngine.gameId;
      first.turnEngine.leavePage();
      await waitFor(
        () => [second, third].every(
          (g) =>
              g.turnEngine.publisherId == b.identity &&
              g.turnEngine.synchronized.value,
        ),
      );
      expect(second.turnEngine.gameId, session);
      expect(second.board!.moveNumber, 1);
      expect(third.board!.moveNumber, 1);
      expect(second.turnEngine.currentPlayer.value, b.identity);
      second.turnEngine.completeRound();
      await waitFor(
        () => [
          second,
          third,
        ].every((g) => g.turnEngine.roundReplay!.finished.value),
      );
      // 快速重开也按准备先后决定首次发布和行动，不由协调者的小 ID 抢占。
      var readyEcho = false;
      c.addMessageListener((message) {
        if (message.id == c.identity &&
            message.type == MessageType.sync &&
            message.content.startsWith('@round-replay:') &&
            message.content.contains('"phase":"ready"')) {
          readyEcho = true;
        }
      });
      third.turnEngine.requestReplay();
      await waitFor(() => readyEcho);
      second.turnEngine.requestReplay();
      await waitFor(
        () => [second, third].every(
          (g) =>
              g.turnEngine.roundReplay!.round == 1 &&
              g.turnEngine.synchronized.value,
        ),
      );
      expect(
        [second, third].every(
          (g) =>
              g.turnEngine.publisherId == c.identity &&
              g.turnEngine.currentPlayer.value == c.identity,
        ),
        isTrue,
      );
      expect(second.canInteract, isFalse);
      expect(third.canInteract, isTrue);
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });
}
