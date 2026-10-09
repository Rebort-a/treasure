import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';

Widget _app(MatchManager manager, {bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: MatchGameView(manager: manager, onExit: () {}),
    ),
  ),
);

Finder _entrance(int id) => find.descendant(
  of: find.byKey(ValueKey('piece-$id')),
  matching: find.byKey(const ValueKey('match-piece-entrance')),
);

double _offset(WidgetTester tester, int id) =>
    tester.widget<Transform>(_entrance(id)).transform.storage[13];

int _score(WidgetTester tester) => int.parse(
  tester.widget<Text>(find.byKey(const ValueKey('match-score'))).data!,
);

void _setScore(MatchManager manager, int score) {
  final board = manager.board!..score = score;
  manager.view.value = MatchView(board, BoardFrame(board, FramePhase.settled));
}

void main() {
  testWidgets('开始和同种子重开都先显示空棋盘，再从上方落入', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    await tester.pumpWidget(_app(manager));
    final original = jsonEncode(manager.board!.toJson());
    final id = manager.board!.pieces[16]!.id;

    for (var round = 0; round < 2; round++) {
      if (round > 0) {
        manager.restart(seed: 7);
        await tester.pump();
      }
      expect(manager.view.value!.frame.pieces.every((p) => p == null), isTrue);
      expect(_entrance(id), findsNothing);
      expect(manager.canInteract, isFalse);
      final move = manager.board!.legalMoves.first;
      manager.swap(move.$1, move.$2);
      expect(manager.board!.moveNumber, 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(manager.view.value!.frame.phase, FramePhase.fall);
      expect(
        manager.view.value!.frame.spawnedPieceIds.length,
        MatchBoard.cells,
      );
      final initial = _offset(tester, id);
      expect(initial, lessThan(-100));
      await tester.pump(const Duration(milliseconds: 90));
      expect(_offset(tester, id), greaterThan(initial));
      expect(manager.canInteract, isFalse);
      await tester.pump(const Duration(milliseconds: 130));
      expect(_offset(tester, id).abs(), lessThan(0.001));
      expect(manager.view.value!.frame.phase, FramePhase.settled);
      expect(manager.canInteract, isTrue);
      expect(jsonEncode(manager.board!.toJson()), original);
    }
  });

  testWidgets('分数递增经过中间值，连续加分衔接当前数字，重开直接归零', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    await tester.pumpWidget(_app(manager));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    expect(_score(tester), 0);

    _setScore(manager, 100);
    await tester.pump();
    expect(_score(tester), 0);
    await tester.pump(const Duration(milliseconds: 80));
    final intermediate = _score(tester);
    expect(intermediate, inExclusiveRange(0, 100));
    _setScore(manager, 200);
    await tester.pump();
    expect(_score(tester), intermediate);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_score(tester), inExclusiveRange(intermediate, 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_score(tester), 200);

    manager.restart(seed: 7);
    await tester.pump();
    expect(_score(tester), 0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    expect(_score(tester), 0);
  });

  testWidgets('减少动画时分数直接更新，重开棋子直接落位', (tester) async {
    final manager = MatchManager(generate: false)..reduceMotion = true;
    manager.restart(seed: 7);
    addTearDown(manager.dispose);
    await tester.pumpWidget(_app(manager, reduceMotion: true));
    expect(manager.busy.value, isFalse);
    expect(manager.view.value!.frame.pieces.every((p) => p != null), isTrue);
    _setScore(manager, 100);
    await tester.pump();
    expect(_score(tester), 100);
    manager.restart(seed: 7);
    await tester.pump();
    expect(_score(tester), 0);
    expect(manager.busy.value, isFalse);
    expect(_offset(tester, manager.board!.pieces[16]!.id), 0);
  });

  testWidgets('联机首次快照也入场，清空快照会取消旧局入场', (tester) async {
    final manager = MatchManager(generate: false);
    addTearDown(manager.dispose);
    final data = MatchBoard.random(seed: 7).toJson();
    manager.loadState(data);
    expect(manager.view.value!.frame.pieces.every((p) => p == null), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(manager.view.value!.frame.phase, FramePhase.fall);
    manager.resetNetworkRound();
    await tester.pump(const Duration(seconds: 1));
    expect(manager.view.value, isNull);
    expect(manager.busy.value, isFalse);
    manager.loadState(data);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    expect(manager.view.value!.frame.phase, FramePhase.settled);
    expect(manager.canInteract, isTrue);
  });

  testWidgets('发布者生成快照后回载也播放首次入场', (tester) async {
    final manager = MatchManager(generate: false);
    addTearDown(manager.dispose);
    final data = manager.saveState();
    manager.loadState(data);
    expect(manager.busy.value, isTrue);
    expect(manager.view.value!.frame.pieces.every((p) => p == null), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(manager.view.value!.frame.phase, FramePhase.fall);
    await tester.pump(const Duration(milliseconds: 220));
    expect(manager.canInteract, isTrue);
  });

  testWidgets('入场期间连续重开、释放管理器不遗留旧局通知和计时器', (tester) async {
    final manager = MatchManager(seed: 7);
    await tester.pump(const Duration(milliseconds: 100));
    manager.restart(seed: 9);
    expect(manager.view.value!.seed, 9);
    await tester.pump(const Duration(milliseconds: 100));
    manager.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
