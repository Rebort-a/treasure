import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/10.three_tiles/base.dart';
import 'package:treasure/10.three_tiles/manager.dart';

void main() {
  testWidgets('难度改变重开，完成暴露结果且停止计时，退出后不能重启', (tester) async {
    final manager = Manager();
    addTearDown(manager.dispose);
    manager.changeDifficulty(Difficulty.easy);
    expect(manager.cards.length, 30);
    final removed = manager.cards.value.skip(1).toList();
    for (final card in removed) {
      manager.cards.remove(card);
      card.dispose();
    }
    final last = manager.cards.first;
    last.changeEnable(true);
    manager.selectCard(last);
    expect(manager.result.value, isTrue);
    final elapsed = manager.elapsed.value;
    await tester.pump(const Duration(seconds: 2));
    expect(manager.elapsed.value, elapsed);
    manager.restartGame();
    expect(manager.result.value, isNull);
    expect(manager.cards.length, 30);
    manager.leavePage();
    manager.changeDifficulty(Difficulty.hard);
    manager.restartGame();
    expect(manager.cards.isEmpty, isTrue);
    expect(manager.difficulty, Difficulty.easy);
    manager.dispose();
    await tester.pump();
    manager.dispose();
  });
}
