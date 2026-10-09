import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/widget/component/game_replay_board.dart';
import 'package:treasure/03.animal_chess/foundation_widget.dart' as animal;
import 'package:treasure/03.animal_chess/local_manager.dart' as animal;
import 'package:treasure/03.animal_chess/local_page.dart';
import 'package:treasure/05.gobang/foundation_widget.dart' as gomoku;
import 'package:treasure/05.gobang/local_page.dart';
import 'package:treasure/07.weiqi/foundation_widget.dart' as go;
import 'package:treasure/07.weiqi/local_page.dart';
import 'package:treasure/15.memory_card/page.dart';

final _replay = find.byKey(const ValueKey('round-replay'));

void main() {
  setUp(() => LanguageProvider.instance.resetForTesting());

  testWidgets('单机斗兽棋投降后留在当前页，通过共用按钮重开', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LocalAnimalChessPage()));
    final page = tester.element(find.byType(LocalAnimalChessPage));
    final board = tester.widget<animal.FoundationalWidget>(
      find.byType(animal.FoundationalWidget),
    );
    final original = board.displayMap.value;
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.surrender));
    await tester.pumpAndSettle();
    expect(_replay, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<GameReplayBoard>(find.byType(GameReplayBoard)).finished,
      isTrue,
    );
    await tester.tap(_replay);
    await tester.pumpAndSettle();
    expect(_replay, findsNothing);
    expect(tester.element(find.byType(LocalAnimalChessPage)), same(page));
    expect(board.displayMap.value, isNot(same(original)));
  });

  testWidgets('单机五子棋自然胜利后重开不换页面，悔棋也能撤下蒙版', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LocalGomokuPage()));
    final page = tester.element(find.byType(LocalGomokuPage));
    final manager = tester
        .widget<gomoku.FoundationalWidget>(
          find.byType(gomoku.FoundationalWidget),
        )
        .manager;
    for (final index in [0, 15, 1, 16, 2, 17, 3, 18, 4]) {
      manager.placePiece(index);
    }
    await tester.pump();
    expect(_replay, findsOneWidget);
    final count = manager.board.moveHistory.length;
    manager.placePiece(100);
    expect(manager.board.moveHistory.length, count);
    manager.undo();
    await tester.pump();
    expect(_replay, findsNothing);
    manager.placePiece(4);
    await tester.pump();
    expect(_replay, findsOneWidget);
    await tester.tap(_replay);
    await tester.pumpAndSettle();
    expect(manager.board.gameOver, isFalse);
    expect(manager.board.moveHistory, isEmpty);
    expect(_replay, findsNothing);
    expect(tester.element(find.byType(LocalGomokuPage)), same(page));
  });

  testWidgets('单机围棋投降即显示共用重开层，重开清空棋盘', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GoLocalPage()));
    final page = tester.element(find.byType(GoLocalPage));
    final manager = tester
        .widget<go.GoFoundationWidget>(find.byType(go.GoFoundationWidget))
        .manager;
    manager.placePiece(0);
    manager.resign();
    await tester.pump();
    expect(_replay, findsOneWidget);
    expect(find.textContaining(S.sideWin(S.blackSide)), findsOneWidget);
    await tester.tap(_replay);
    await tester.pumpAndSettle();
    expect(manager.board.gameOver, isFalse);
    expect(manager.board.moveHistory, isEmpty);
    expect(_replay, findsNothing);
    expect(tester.element(find.byType(GoLocalPage)), same(page));
  });

  testWidgets('记忆翻牌复用公共蒙版而不是自行绘制重开按钮', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MemoryPage()));
    final finished =
        tester
                .widget<ValueListenableBuilder<bool>>(
                  find
                      .ancestor(
                        of: find.byType(GameReplayBoard),
                        matching: find.byType(ValueListenableBuilder<bool>),
                      )
                      .first,
                )
                .valueListenable
            as ValueNotifier<bool>;
    finished.value = true;
    await tester.pump();
    expect(find.byType(GameReplayBoard), findsOneWidget);
    expect(_replay, findsOneWidget);
    await tester.tap(_replay);
    await tester.pumpAndSettle();
    expect(finished.value, isFalse);
    expect(_replay, findsNothing);
  });

  testWidgets('斗兽棋投降后旧 AI 延迟不改棋盘，重开后不执行旧局动作', (tester) async {
    final manager = animal.LocalManager();
    addTearDown(manager.dispose);
    manager.toggleAiSwitch();
    manager.handleSurrender();
    final before = [
      for (final cell in manager.displayMap.value) cell.value.animal?.isHidden,
    ];
    await tester.pump(const Duration(milliseconds: 500));
    expect([
      for (final cell in manager.displayMap.value) cell.value.animal?.isHidden,
    ], before);
    manager.toggleAiSwitch();
    manager.initGame();
    await tester.pump(const Duration(milliseconds: 500));
    expect(manager.winner.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('斗兽棋 AI 思考时重开，旧局延迟不会多走一步', (tester) async {
    final manager = animal.LocalManager();
    addTearDown(manager.dispose);
    manager.toggleAiSwitch();
    manager.initGame();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      manager.displayMap.value
          .where((cell) => cell.value.animal?.isHidden == false)
          .length,
      1,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      manager.displayMap.value
          .where((cell) => cell.value.animal?.isHidden == false)
          .length,
      1,
    );
  });
}
