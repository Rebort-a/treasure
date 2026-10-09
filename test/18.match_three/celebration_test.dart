import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';
import 'package:treasure/18.match_three/upper/match_celebration.dart';

Map<String, dynamic> _winningState({int score = 0}) {
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
    ..['score'] = score;
  data['moveNumber'] = data['initialMoves'] - 3;
  return data;
}

Widget _app(MatchManager manager, {bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: MatchGameView(manager: manager, onExit: () {}),
    ),
  ),
);

final _confetti = find.byKey(const ValueKey('match-celebration'));

Future<void> _win(
  WidgetTester tester,
  MatchManager manager, {
  int score = 0,
}) async {
  manager.loadState(_winningState(score: score));
  manager.swap(10, 2);
  var sawBonus = false;
  for (var i = 0; i < 120 && manager.busy.value; i++) {
    expect(_confetti, findsNothing);
    expect(find.byKey(const ValueKey('round-replay')), findsNothing);
    sawBonus |= manager.bonusTime.value;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(sawBonus, isTrue);
  expect(manager.busy.value, isFalse);
  expect(manager.bonusTime.value, isFalse);
  expect(manager.view.value!.status, MatchStatus.won);
}

void main() {
  for (final score in [
    MatchCelebration.richScoreThreshold,
    MatchCelebration.richScoreThreshold + 1,
  ]) {
    testWidgets('丰富庆祝严格使用最终分数门槛：$score', (tester) async {
      final manager = MatchManager(generate: false);
      addTearDown(manager.dispose);
      final board = MatchBoard.fromJson(_winningState());
      board.playSwap(10, 2);
      board.score = score;
      manager.loadState(board.toJson());
      await tester.pumpWidget(_app(manager));
      expect(_confetti, findsOneWidget);
      expect(
        (tester.widget<CustomPaint>(_confetti).painter! as MatchConfettiPainter)
            .rich,
        score > MatchCelebration.richScoreThreshold,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final score in [0, MatchCelebration.richScoreThreshold]) {
    testWidgets('奖励结算后按本局分数撒花一次：初始分数 $score', (tester) async {
      final manager = MatchManager(seed: 7);
      addTearDown(manager.dispose);
      await tester.pumpWidget(_app(manager));
      await _win(tester, manager, score: score);
      expect(_confetti, findsOneWidget);
      expect(
        (tester.widget<CustomPaint>(_confetti).painter! as MatchConfettiPainter)
            .rich,
        manager.view.value!.score > MatchCelebration.richScoreThreshold,
      );
      expect(
        (tester.widget<CustomPaint>(_confetti).painter! as MatchConfettiPainter)
            .rich,
        score != 0,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: _confetti, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 3300));
      expect(_confetti, findsNothing);
      await tester.pumpWidget(_app(manager));
      manager.refreshView();
      await tester.pump();
      expect(_confetti, findsNothing);
      // 同一页面新局可以再次撒花。
      manager.restart(seed: 7);
      await tester.pump();
      await _win(tester, manager);
      expect(_confetti, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('减少动画时不撒花，切回动画也不补播旧局', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    await tester.pumpWidget(_app(manager, reduceMotion: true));
    await _win(tester, manager);
    expect(_confetti, findsNothing);
    await tester.pumpWidget(_app(manager));
    expect(_confetti, findsNothing);
  });

  testWidgets('重开和联机清空快照立即清除撒花', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    await tester.pumpWidget(_app(manager));
    await _win(tester, manager);
    // 特效不拦截顶部的本地重开按钮。
    await tester.tap(find.byKey(const ValueKey('match-restart')));
    await tester.pump();
    expect(_confetti, findsNothing);
    await _win(tester, manager);
    manager.resetNetworkRound();
    await tester.pump();
    expect(_confetti, findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('单机通关后共用棋盘重开按钮不被撒花拦截', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    await tester.pumpWidget(_app(manager));
    await _win(tester, manager);
    final replay = find.byKey(const ValueKey('round-replay'));
    expect(replay, findsOneWidget);
    expect(_confetti, findsOneWidget);
    await tester.ensureVisible(replay);
    await tester.pump();
    await tester.tap(replay);
    await tester.pump();
    expect(manager.view.value!.status, MatchStatus.playing);
    expect(manager.view.value!.score, 0);
    expect(replay, findsNothing);
    expect(_confetti, findsNothing);
  });

  testWidgets('失败结算不撒花', (tester) async {
    final manager = MatchManager(seed: 9);
    addTearDown(manager.dispose);
    final data = MatchBoard.random(seed: 9).toJson()..['movesLeft'] = 1;
    data['moveNumber'] = data['initialMoves'] - 1;
    manager.loadState(data);
    await tester.pumpWidget(_app(manager, reduceMotion: true));
    final move = manager.board!.legalMoves.first;
    manager.swap(move.$1, move.$2);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(manager.view.value!.status, MatchStatus.lost);
    expect(find.byKey(const ValueKey('round-replay')), findsOneWidget);
    await tester.pumpWidget(_app(manager));
    expect(_confetti, findsNothing);
    expect(find.byType(MatchCelebration), findsOneWidget);
  });
}
