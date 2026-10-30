import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/08.sudoku/page.dart';
import 'package:treasure/09.guess/page.dart';
import 'package:treasure/10.three_tiles/page.dart';
import 'package:treasure/08.sudoku/manager.dart' as sudoku;
import 'package:treasure/10.three_tiles/manager.dart' as tiles;
import 'package:treasure/11.spaceship/page.dart';
import 'package:treasure/12.soft/page.dart';

void main() {
  testWidgets('重开时旧棋盘的监听可在重建后安全解绑', (tester) async {
    final manager = sudoku.Manager();
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: manager.cells,
          builder: (context, cells, child) => ValueListenableBuilder(
            valueListenable: cells.first,
            builder: (context, cell, child) => const SizedBox(),
          ),
        ),
      ),
    );
    manager.resetGame();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    manager.dispose();

    final tileManager = tiles.Manager();
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: tileManager.cards,
          builder: (context, cards, child) => ValueListenableBuilder(
            valueListenable: cards.first,
            builder: (context, card, child) => const SizedBox(),
          ),
        ),
      ),
    );
    tileManager.restartGame();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tileManager.dispose();
  });
  for (final entry in <String, Widget Function()>{
    'sudoku': () => const SudokuPage(),
    'guess': () => const GuessPage(),
    'three tiles': () => const ThreeTilesPage(),
    'spaceship': () => const SpaceShipPage(),
    'soft': () => const SoftPage(),
  }.entries) {
    testWidgets('${entry.key} 重建保留本局，卸载后停止所有调度', (tester) async {
      Widget app() => MaterialApp(home: entry.value());
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 32));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
}
