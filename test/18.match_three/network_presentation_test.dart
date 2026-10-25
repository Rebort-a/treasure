import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/net_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';

import '../00.common/network/support/match_game_driver.dart';
import '../00.common/network/support/network_room_harness.dart';

Map<String, dynamic> _winningState() {
  final data = MatchBoard.random(seed: 7).toJson()
    ..['pieces'] = [
      for (var index = 0; index < MatchBoard.cells; index++)
        [
          index + 1,
          {0: 0, 1: 0, 2: 1, 3: 0, 10: 0}[index] ??
              (index ~/ MatchBoard.side * 2 + index % MatchBoard.side) %
                  MatchBoard.kinds,
          PieceEffect.none.index,
        ],
    ]
    ..['nextId'] = MatchBoard.cells + 1
    ..['ice'] = List.filled(MatchBoard.cells, 0)
    ..['targets'] = {'0': 1, '1': 1}
    ..['collected'] = [0, 1, 0, 0, 0, 0]
    ..['movesLeft'] = 3;
  data['moveNumber'] = data['initialMoves'] - 3;
  return data;
}

void main() {
  testWidgets('非本人回合点击可提醒队友，相邻点击和滑动都不交换', (tester) async {
    HttpOverrides.global = null;
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await tester.runAsync(() async {
      await h.server.start();
      for (final name in ['First', 'Second']) {
        games.add(
          NetMatchManager(room: await h.join(name))..reduceMotion = true,
        );
      }
      for (final game in games) {
        startGame(game.turnEngine);
      }
      await waitFor(() => games.every((g) => g.turnEngine.synchronized.value));
    });
    try {
      final observer = games.firstWhere((g) => !g.turnEngine.canAct);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: MatchGameView(
            manager: observer,
            engine: observer.turnEngine,
            onExit: () {},
          ),
        ),
      );
      final board = find.byKey(const ValueKey('match-board'));
      await tester.ensureVisible(board);
      await tester.pump();
      final rect = tester.getRect(board);
      final cell = rect.width / MatchBoard.side;
      Offset center(int index) =>
          rect.topLeft +
          Offset(
            (index % MatchBoard.side + 0.5) * cell,
            (index ~/ MatchBoard.side + 0.5) * cell,
          );
      final hint = find.byKey(const ValueKey('match-hint'));
      for (final index in [0, 1]) {
        await tester.tapAt(center(index));
        await tester.runAsync(
          () => waitFor(() => games.every((g) => g.hint.value == index)),
        );
        await tester.pump();
        expect(hint, findsOneWidget);
        expect(observer.selected.value, isNull);
      }
      await tester.dragFrom(center(0), Offset(cell, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(games.every((g) => g.board!.moveNumber == 0), isTrue);
      expect(hint, findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (final game in games) {
        game.dispose();
      }
      await tester.runAsync(h.close);
    }
  });

  testWidgets('联机撒花随奖励开场出现，队友提前结束不能让重开抢在结算前出现', (tester) async {
    HttpOverrides.global = null;
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await tester.runAsync(() async {
      await h.server.start();
      final first = NetMatchManager(room: await h.join('First'))
        ..reduceMotion = true;
      final second = NetMatchManager(room: await h.join('Second'))
        ..reduceMotion = true;
      games.addAll([first, second]);
      startGame(first.turnEngine);
      startGame(second.turnEngine);
      await waitFor(() => games.every((g) => g.turnEngine.synchronized.value));
    });
    try {
      final actor = games.firstWhere((g) => g.turnEngine.canAct);
      final other = games.firstWhere((g) => g != actor);
      final data = _winningState()
        ..['score'] = 100050
        ..['playerScores'] = {
          '${actor.turnEngine.identity}': 50,
          '${other.turnEngine.identity}': 100000,
        };
      final replayBoard = MatchBoard.fromJson(data);
      final replayResult = replayBoard.playSwap(10, 2)!;
      final normalScore =
          replayResult.frames
              .firstWhere((frame) => frame.phase == FramePhase.bonus)
              .score -
          100050;
      actor.loadState(data);
      await tester.pumpWidget(
        MaterialApp(
          home: MatchGameView(
            manager: actor,
            engine: actor.turnEngine,
            onExit: () {},
          ),
        ),
      );
      // 模拟发布者应用动作后、最终资源回环前的刷新窗口。
      expect(actor.applyNetworkAction({'from': 10, 'to': 2}), isTrue);
      actor.refreshView();
      expect(actor.board!.status, MatchStatus.won);
      expect(actor.roundSettled, isFalse);
      expect(actor.turnEngine.roundReplay!.finished.value, isFalse);
      final celebration = find.byKey(const ValueKey('match-celebration'));
      await tester.pump();
      expect(celebration, findsNothing);
      actor.loadState(actor.saveState());
      expect(actor.busy.value, isTrue);
      expect(actor.personalScore, 50 + normalScore);
      expect(actor.personalRank, 2);

      // 队友先收到结束消息，本机仍应等自己的奖励结算结束。
      await tester.runAsync(() async {
        other.turnEngine.completeRound();
        await waitFor(() => actor.turnEngine.roundReplay!.finished.value);
      });
      await tester.pump();
      final replay = find.byKey(const ValueKey('round-replay'));
      var sawBonusOpening = false;
      for (var i = 0; i < 120 && actor.busy.value; i++) {
        expect(replay, findsNothing);
        if (!sawBonusOpening) expect(celebration, findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        if (actor.bonusTime.value) {
          if (!sawBonusOpening) {
            expect(celebration, findsOneWidget);
            sawBonusOpening = true;
          }
          expect(find.text(S.matchYourRank(2)), findsOneWidget);
          expect(find.text('${actor.personalScore}'), findsOneWidget);
        }
      }
      expect(sawBonusOpening, isTrue);
      expect(actor.busy.value, isFalse);
      expect(actor.bonusTime.value, isFalse);
      expect(actor.roundSettled, isTrue);
      expect(actor.showPersonalScore.value, isTrue);
      expect(find.text(S.matchYourRank(2)), findsOneWidget);
      expect(actor.personalScore, 50 + normalScore);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(replay, findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (final game in games) {
        game.dispose();
      }
      await tester.runAsync(h.close);
    }
  });
}
