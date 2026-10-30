import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/07.weiqi/base.dart';
import 'package:treasure/07.weiqi/local_manager.dart';
import 'package:treasure/07.weiqi/intelligence.dart';

void main() {
  testWidgets('切难度和重开更新同一模式源且取消旧局 AI', (tester) async {
    final manager = GoLocalManager();
    final mode = manager.aiEnabledListenable;
    final difficulty = manager.difficultyListenable;
    manager.toggleAi(true, faction: StoneState.black);
    manager.setDifficulty(GoAiDifficulty.easy);
    expect(manager.aiThinking.value, isTrue);
    manager.restart();
    expect(manager.aiThinking.value, isTrue);
    manager.toggleAi(false);
    expect(manager.aiThinking.value, isFalse);
    expect(mode.value, isFalse);
    expect(identical(mode, manager.aiEnabledListenable), isTrue);
    expect(identical(difficulty, manager.difficultyListenable), isTrue);
    expect(difficulty.value, GoAiDifficulty.easy);
    manager.placePiece(0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(manager.board.moveHistory.length, 1);
    manager.dispose();
    manager.dispose();
    expect(
      () => manager.board.grids.value.first.addListener(() {}),
      throwsFlutterError,
    );
    expect(
      () => manager.board.currentPlayer.addListener(() {}),
      throwsFlutterError,
    );
    expect(
      () => manager.board.gameOverNotifier.addListener(() {}),
      throwsFlutterError,
    );
  });

  testWidgets('卸载取消延迟 AI 且重复释放安全', (tester) async {
    final manager = GoLocalManager();
    manager.toggleAi(true, faction: StoneState.black);
    manager.dispose();
    manager.dispose();
    await tester.pump(const Duration(milliseconds: 100));
    expect(manager.board.moveHistory, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
