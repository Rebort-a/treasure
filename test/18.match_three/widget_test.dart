import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';
import 'package:treasure/18.match_three/upper/match_board_widget.dart';

Widget _app(
  MatchManager manager, {
  bool reduceMotion = true,
  bool dark = false,
  double textScale = 1,
}) => MaterialApp(
  theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MatchGameView(manager: manager, onExit: () {}),
    ),
  ),
);

void main() {
  setUp(() => LanguageProvider.instance.resetForTesting());

  testWidgets('随机目标与棋盘可见，交换与重开均有效', (tester) async {
    final manager = MatchManager(seed: 100);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    expect(find.byType(MatchBoardWidget), findsOneWidget);
    expect(manager.board!.pieces.length, 64);
    final before = manager.board!.seed;
    final swap = manager.board!.legalMoves.first;
    await tester.ensureVisible(find.byKey(const ValueKey('match-board')));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('match-board')));
    final cell = rect.width / MatchBoard.side;
    Offset center(int index) =>
        rect.topLeft +
        Offset((index % 8 + 0.5) * cell, (index ~/ 8 + 0.5) * cell);
    await tester.tapAt(center(swap.$1));
    await tester.tapAt(center(swap.$2));
    await tester.pump();
    expect(manager.board!.moveNumber, 1);
    expect(manager.busy.value, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(manager.busy.value, isFalse);
    await tester.tap(find.byKey(const ValueKey('match-restart')));
    await tester.pump();
    expect(manager.board!.seed, isNot(before));
    expect(manager.board!.moveNumber, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滑动交换只推进一步，左右边界不会跨行', (tester) async {
    final manager = MatchManager(seed: 123);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    await tester.ensureVisible(find.byKey(const ValueKey('match-board')));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('match-board')));
    final cell = rect.width / 8;
    final swap = manager.board!.legalMoves.first;
    Offset center(int index) =>
        rect.topLeft +
        Offset((index % 8 + 0.5) * cell, (index ~/ 8 + 0.5) * cell);
    await tester.dragFrom(center(swap.$1), center(swap.$2) - center(swap.$1));
    await tester.pump();
    expect(manager.board!.moveNumber, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.dragFrom(center(7), Offset(cell, 0));
    await tester.pump();
    expect(manager.board!.moveNumber, 1);
  });

  testWidgets('无效交换不消耗步数，反馈结束后恢复操作', (tester) async {
    final manager = MatchManager(seed: 100);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    final board = manager.board!;
    final invalidSwap = [
      for (var index = 0; index < MatchBoard.cells; index++)
        if (index % MatchBoard.side < MatchBoard.side - 1 &&
            board.ice[index] == 0 &&
            board.ice[index + 1] == 0 &&
            !board.canSwap(index, index + 1))
          (index, index + 1),
      for (var index = 0; index < MatchBoard.cells - MatchBoard.side; index++)
        if (board.ice[index] == 0 &&
            board.ice[index + MatchBoard.side] == 0 &&
            !board.canSwap(index, index + MatchBoard.side))
          (index, index + MatchBoard.side),
    ].first;
    await tester.pumpWidget(_app(manager, reduceMotion: false));
    await tester.ensureVisible(find.byKey(const ValueKey('match-board')));
    await tester.pump();
    manager.swap(invalidSwap.$1, invalidSwap.$2);
    expect(manager.board!.moveNumber, 0);
    expect(manager.canInteract, isFalse);
    for (var step = 0; step < 20 && !manager.canInteract; step++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(manager.canInteract, isTrue);
    expect(manager.invalidSwapAnimating.value, isFalse);
    expect(manager.board!.moveNumber, 0);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('窄屏、大字体和深浅主题不溢出（深色：$dark）', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manager = MatchManager(seed: 99);
      addTearDown(manager.dispose);
      // 本测试聚焦稳定棋盘，先完成开局入场。
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpWidget(_app(manager, dark: dark, textScale: 2));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MatchBoardWidget), findsOneWidget);
    });
  }

  testWidgets('结算动画中卸载后不再写通知器或遗留 ticker', (tester) async {
    final manager = MatchManager(seed: 9);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager, reduceMotion: false));
    final swap = manager.board!.legalMoves.first;
    manager.swap(swap.$1, swap.$2);
    expect(manager.busy.value, isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('开局过程中重开及释放管理器不会遗留旧局通知或计时器', (tester) async {
    final manager = MatchManager(seed: 7);
    manager.restart(seed: 9);
    expect(manager.view.value!.seed, 9);
    manager.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });
}
