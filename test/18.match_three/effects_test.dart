import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/match_board_widget.dart';
import 'package:treasure/18.match_three/upper/match_clear_effects.dart';

Widget _app(MatchManager manager, {bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Center(
        child: SizedBox(
          width: 400,
          child: ValueListenableBuilder<MatchView?>(
            valueListenable: manager.view,
            builder: (_, view, __) =>
                MatchBoardWidget(manager: manager, view: view!),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('补块从棋盘上方落入，随后稳定在目标格', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    final board = manager.board!;
    await tester.pumpWidget(_app(manager));
    // 用一个全新 ID 模拟补块，避免复用旧棋子的入场时钟。
    const index = 16;
    const piece = Piece(10001, 2);
    board.pieces[index] = piece;
    manager.view.value = MatchView(
      board,
      BoardFrame(board, FramePhase.fall, const {}, {piece.id}),
    );
    await tester.pump();
    final entrance = find.descendant(
      of: find.byKey(const ValueKey('piece-10001')),
      matching: find.byKey(const ValueKey('match-piece-entrance')),
    );
    double offset() => tester.widget<Transform>(entrance).transform.storage[13];
    final initial = offset();
    expect(initial, lessThan(-100));
    await tester.pump(const Duration(milliseconds: 90));
    expect(offset(), greaterThan(initial));
    await tester.pump(const Duration(milliseconds: 120));
    expect(offset().abs(), lessThan(0.001));
    // 下一帧不重复入场。
    manager.view.value = MatchView(
      board,
      BoardFrame(board, FramePhase.settled),
    );
    await tester.pump();
    expect(offset().abs(), lessThan(0.001));
  });

  testWidgets('合法交换在结算前沿轨迹移动，不跳到目标格', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    final move = manager.board!.legalMoves.first;
    final id = manager.board!.pieces[move.$1]!.id;
    final piece = find.byKey(ValueKey('piece-$id'));
    final start = tester.getTopLeft(piece);
    manager.swap(move.$1, move.$2);
    await tester.pump();
    expect(tester.getTopLeft(piece), start);
    await tester.pump(const Duration(milliseconds: 90));
    final middle = tester.getTopLeft(piece);
    expect(middle, isNot(start));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getTopLeft(piece), isNot(middle));
    await tester.pumpWidget(const SizedBox());
    manager.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('四种特殊消除与破冰绘制不改规则状态，下一阶段撤下', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    final board = manager.board!;
    board.ice[0] = 1;
    manager.view.value = MatchView(
      board,
      BoardFrame(board, FramePhase.settled),
    );
    await tester.pumpWidget(_app(manager));
    for (var i = 0; i < 4; i++) {
      board.pieces[i] = Piece(i + 1000, i, PieceEffect.values[i + 1]);
    }
    board.ice[0] = 0;
    final before = board.toJson().toString();
    manager.view.value = MatchView(
      board,
      BoardFrame(board, FramePhase.clear, {0, 1, 2, 3}),
    );
    await tester.pump();
    final effect = find.byKey(const ValueKey('match-clear-effects'));
    expect(effect, findsOneWidget);
    final painter =
        tester.widget<CustomPaint>(effect).painter! as MatchClearPainter;
    expect(painter.crackedIce, {0});
    expect(painter.progress.value, 0);
    await tester.pump(const Duration(milliseconds: 90));
    expect(painter.progress.value, closeTo(0.5, 0.01));
    expect(board.toJson().toString(), before);
    expect(tester.takeException(), isNull);
    manager.view.value = MatchView(board, BoardFrame(board, FramePhase.fall));
    await tester.pump();
    expect(effect, findsNothing);
  });

  testWidgets('减少动画时不出现消除粒子，补块直接落位', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    final board = manager.board!;
    await tester.pumpWidget(_app(manager, reduceMotion: true));
    manager.view.value = MatchView(
      board,
      BoardFrame(board, FramePhase.clear, {0, 1, 2}),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('match-clear-effects')), findsNothing);
    const piece = Piece(10001, 2);
    board.pieces[16] = piece;
    manager.view.value = MatchView(
      board,
      BoardFrame(board, FramePhase.fall, const {}, {piece.id}),
    );
    await tester.pump();
    final entrance = find.descendant(
      of: find.byKey(const ValueKey('piece-10001')),
      matching: find.byKey(const ValueKey('match-piece-entrance')),
    );
    expect(tester.widget<Transform>(entrance).transform.storage[13], 0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('消除时卸载页面释放粒子时钟', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    manager.view.value = MatchView(
      manager.board!,
      BoardFrame(manager.board!, FramePhase.clear, {0, 1, 2}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
