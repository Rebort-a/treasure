import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';

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
    ..['movesLeft'] = 3
    ..['score'] = 0;
  data['moveNumber'] = data['initialMoves'] - 3;
  return data;
}

void main() {
  testWidgets('通关结算结束后可重开，结算期间不开放重开入口', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    await tester.pumpWidget(
      MaterialApp(
        home: MatchGameView(manager: manager, onExit: () {}),
      ),
    );
    final replay = find.byKey(const ValueKey('round-replay'));
    manager.swap(10, 2);
    expect(manager.busy.value, isTrue);
    for (var step = 0; step < 120 && manager.busy.value; step++) {
      expect(replay, findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(manager.busy.value, isFalse);
    expect(manager.bonusTime.value, isFalse);
    expect(manager.view.value!.status, MatchStatus.won);
    expect(manager.view.value!.score, manager.board!.score);
    await tester.pump();
    expect(replay, findsOneWidget);
    await tester.ensureVisible(replay);
    await tester.tap(replay);
    await tester.pump();
    expect(manager.view.value!.status, MatchStatus.playing);
    expect(manager.view.value!.score, 0);
    expect(replay, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
    await tester.pump();
  });

  testWidgets('减少动画模式仍能结算、重开和清空联机状态', (tester) async {
    final manager = MatchManager(seed: 7)..reduceMotion = true;
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    manager.swap(10, 2);
    for (var step = 0; step < 20 && manager.busy.value; step++) {
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(manager.busy.value, isFalse);
    expect(manager.view.value!.status, MatchStatus.won);
    expect(manager.view.value!.score, manager.board!.score);
    manager.restart(seed: 7);
    expect(manager.view.value!.score, 0);
    manager.resetNetworkRound();
    expect(manager.view.value, isNull);
  });

  testWidgets('奖励结算中重开取消旧局通知', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    manager.swap(10, 2);
    await tester.pump(const Duration(milliseconds: 200));
    manager.restart(seed: 9);
    await tester.pump(const Duration(seconds: 30));
    expect(manager.view.value!.seed, 9);
    expect(manager.view.value!.score, 0);
    expect(manager.busy.value, isFalse);
    expect(manager.bonusTime.value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
