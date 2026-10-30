import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/15.memory_card/base.dart';
import 'package:treasure/15.memory_card/manager.dart';
import 'package:treasure/15.memory_card/page.dart';

void main() {
  testWidgets('重开后旧配对不能清除新局选择或提前解除配对锁', (tester) async {
    final manager = MemoryManager();
    addTearDown(manager.dispose);
    await manager.flipCard(0);
    final different = manager.cards.value.indexWhere(
      (card) => card.pattern != manager.cards[0].pattern,
    );
    final oldOperation = manager.flipCard(different);
    await tester.pump(const Duration(milliseconds: 300));
    manager.resetGame();
    await manager.flipCard(0);
    final currentOperation = manager.flipCard(1);
    await tester.pump(const Duration(milliseconds: 300));
    await oldOperation;
    expect(manager.firstIndex.value, 0);
    expect(manager.isMatching.value, isTrue);
    await manager.flipCard(2);
    expect(manager.cards[2].state, CardState.hidden);
    await tester.pump(const Duration(seconds: 1));
    await currentOperation;
    manager.leavePage();
  });

  testWidgets('匹配成功的延迟操作不能清除重开后的第一张牌', (tester) async {
    final manager = MemoryManager();
    addTearDown(manager.dispose);
    final second = manager.cards.value.indexWhere(
      (card) =>
          card != manager.cards[0] && card.pattern == manager.cards[0].pattern,
    );
    await manager.flipCard(0);
    final operation = manager.flipCard(second);
    await tester.pump(const Duration(milliseconds: 500));
    manager.resetGame();
    await manager.flipCard(0);
    await tester.pump(const Duration(seconds: 1));
    await operation;
    expect(manager.firstIndex.value, 0);
    expect(manager.cards[0].state, CardState.revealed);
    expect(manager.matchedCount.value, 0);
    manager.leavePage();
  });

  testWidgets('离开后延迟配对失效且不再计时', (tester) async {
    final manager = MemoryManager();
    addTearDown(manager.dispose);
    await manager.flipCard(0);
    final operation = manager.flipCard(1);
    manager.leavePage();
    final elapsed = manager.elapsed.value;
    await tester.pump(const Duration(seconds: 2));
    await operation;
    expect(manager.cards[0].state, CardState.revealed);
    expect(manager.matchedCount.value, 0);
    expect(manager.elapsed.value, elapsed);
  });

  testWidgets('释放幂等且旧配对和外部操作不能再修改资源', (tester) async {
    final manager = MemoryManager();
    await manager.flipCard(0);
    final operation = manager.flipCard(1);
    final oldCard = manager.cards[0];
    manager.dispose();
    manager.dispose();
    manager.resetGame();
    manager.changeDifficulty(4);
    manager.leavePage();
    await manager.flipCard(2);
    await tester.pump(const Duration(seconds: 2));
    await operation;
    expect(oldCard.state, CardState.revealed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('页面重开解绑旧卡牌，卸载时终止计时和配对', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MemoryPage()));
    await tester.tap(find.byType(CardView).first);
    await tester.tap(find.byType(CardView).at(1));
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.tap(find.byType(CardView).first);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
