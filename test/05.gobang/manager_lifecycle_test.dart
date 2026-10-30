import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/05.gobang/local_manager.dart';
import 'package:treasure/05.gobang/intelligence.dart';

void main() {
  testWidgets('思考时切难度和重开不会保留旧锁或旧局动作', (tester) async {
    final manager = LocalManager();
    final mode = manager.aiEnabledListenable;
    final difficulty = manager.difficultyListenable;
    manager.toggleAi(true, faction: TurnGamerType.front);
    expect(manager.aiThinking.value, isTrue);
    manager.setDifficulty(AiDifficulty.easy);
    expect(manager.aiThinking.value, isTrue);
    manager.restart();
    expect(manager.aiThinking.value, isTrue);
    manager.toggleAi(false);
    expect(manager.aiThinking.value, isFalse);
    expect(identical(mode, manager.aiEnabledListenable), isTrue);
    expect(identical(difficulty, manager.difficultyListenable), isTrue);
    expect(difficulty.value, AiDifficulty.easy);
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
      () => manager.board.currentGamer.addListener(() {}),
      throwsFlutterError,
    );
    expect(
      () => manager.board.gameOverNotifier.addListener(() {}),
      throwsFlutterError,
    );
  });

  testWidgets('卸载使等待中的 AI 无效', (tester) async {
    final manager = LocalManager();
    manager.toggleAi(true, faction: TurnGamerType.front);
    manager.dispose();
    await tester.pump(const Duration(milliseconds: 100));
    expect(manager.board.moveHistory, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
