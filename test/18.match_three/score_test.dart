import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';

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
  test('目标与冰块进度来自当前帧，不提前跳到最终结算', () {
    final data = _winningState();
    (data['ice'] as List)[9] = 1;
    final board = MatchBoard.fromJson(data);
    final result = board.playSwap(10, 2)!;
    final swapView = MatchView(board, result.frames.first);
    expect(board.status, MatchStatus.won);
    expect(swapView.iceLeft, 1);
    expect(swapView.collected[0], 0);
    expect(swapView.collected[1], 1);
    final clear = result.frames.firstWhere(
      (frame) => frame.phase == FramePhase.clear,
    );
    final clearView = MatchView(board, clear);
    expect(clearView.iceLeft, 0);
    expect(clearView.collected[0], greaterThan(0));
    final finalView = MatchView(board, result.frames.last);
    expect(finalView.collected, board.collected);
    expect(finalView.iceLeft, board.iceLeft);
  });

  testWidgets('结算分数逐帧累加，动画结束才等于总分', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    final initialScore = manager.board!.score;
    manager.swap(10, 2);
    expect(manager.busy.value, isTrue);
    expect(manager.view.value!.score, initialScore);
    var previous = initialScore;
    var increases = 0;
    for (var step = 0; step < 120 && manager.busy.value; step++) {
      await tester.pump(const Duration(milliseconds: 150));
      final score = manager.view.value!.score;
      expect(score, greaterThanOrEqualTo(previous));
      if (score > previous) increases++;
      previous = score;
    }
    expect(manager.busy.value, isFalse);
    expect(manager.bonusTime.value, isFalse);
    expect(manager.view.value!.score, manager.board!.score);
    expect(increases, greaterThan(1));
  });

  testWidgets('减少动画模式奖励结束立即结算，无存储等待', (tester) async {
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
