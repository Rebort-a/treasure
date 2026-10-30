import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/16.schulte/manager.dart';

void main() {
  testWidgets('更改难度重开，依次完成后停止计时，退出后操作失效', (tester) async {
    final manager = SchulteManager();
    addTearDown(manager.dispose);
    manager.changeDifficulty(4);
    expect(manager.board.value.regions.length, 4);
    for (var number = 1; number <= 4; number++) {
      manager.onTapRegion(
        manager.board.value.regions.indexWhere((r) => r.number == number),
      );
    }
    expect(manager.gameOver.value, isTrue);
    final elapsed = manager.elapsed.value;
    await tester.pump(const Duration(seconds: 2));
    expect(manager.elapsed.value, elapsed);
    manager.resetGame();
    expect(manager.gameOver.value, isFalse);
    manager.leavePage();
    final board = manager.board.value;
    manager.changeDifficulty(8);
    manager.resetGame();
    manager.onTapRegion(0);
    expect(manager.board.value, same(board));
    expect(manager.nextNumber.value, 1);
    manager.dispose();
    manager.dispose();
  });
}
