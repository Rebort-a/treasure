import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/sound_manager.dart';
import 'package:treasure/05.gobang/local_manager.dart' as gomoku;
import 'package:treasure/07.weiqi/local_manager.dart' as go;
import 'package:treasure/08.sudoku/base.dart' as sudoku;
import 'package:treasure/08.sudoku/manager.dart' as sudoku;
import 'package:treasure/15.memory_card/manager.dart';
import 'package:treasure/16.schulte/manager.dart';
import 'package:treasure/17.tank/local_manager.dart';

List<Sound> _listen(SoundEmitter source) {
  final events = <Sound>[];
  source.audioEvents.addListener(
    () => events.add(source.audioEvents.value!.sound),
  );
  return events;
}

void main() {
  test('五子棋实际落子才发声，重复动作、悔棋和重开不会误播胜利', () {
    final manager = gomoku.LocalManager();
    final events = _listen(manager);
    manager.placePiece(0);
    manager.placePiece(0);
    expect(events, [Sound.move]);
    manager.undo();
    manager.restart();
    expect(events, [Sound.move, Sound.reset]);
    manager.dispose();
    manager.emitSound(Sound.win);
    expect(events, hasLength(2));
  });

  test('围棋重复落子不重复发声，重开停止旧声音', () {
    final manager = go.GoLocalManager();
    final events = _listen(manager);
    manager.placePiece(0);
    manager.placePiece(0);
    expect(events, [Sound.move]);
    manager.restart();
    expect(events.last, Sound.reset);
    manager.dispose();
  });

  testWidgets('数独仅有效输入产生操作音，重复候选数字和重复锁定不误播', (tester) async {
    final manager = sudoku.Manager();
    await tester.pump();
    final events = _listen(manager);
    final index = manager.cells.value.indexWhere(
      (cell) => cell.type == sudoku.CellType.editable,
    );
    manager.selectCell(index);
    manager.addDigit(1);
    manager.addDigit(1);
    expect(events, [Sound.tap]);
    manager.lockCell();
    expect(events.last, anyOf(Sound.success, Sound.error));
    final count = events.length;
    manager.lockCell();
    expect(events, hasLength(count));
    manager.leavePage();
    manager.disposeAudioEvents();
    await tester.pump();
  });

  testWidgets('记忆翻牌匹配成功发声，重开取消旧异步匹配的声音', (tester) async {
    final manager = MemoryManager();
    final events = _listen(manager);
    final pattern = manager.cards[0].pattern;
    final other = manager.cards.value.indexWhere(
      (card) => card.pattern == pattern && !identical(card, manager.cards[0]),
    );
    await manager.flipCard(0);
    final matching = manager.flipCard(other);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 50));
    await matching;
    expect(events, [Sound.flip, Sound.flip, Sound.success]);
    final first = manager.cards.value.indexWhere(
      (card) => card.pattern != pattern,
    );
    final next = manager.cards.value.indexWhere(
      (card) =>
          card.pattern != pattern && !identical(card, manager.cards[first]),
    );
    await manager.flipCard(first);
    final pending = manager.flipCard(next);
    manager.resetGame();
    final count = events.length;
    await tester.pump(const Duration(seconds: 1));
    await pending;
    expect(events, hasLength(count));
    expect(events.last, Sound.reset);
    manager.leavePage();
    manager.disposeAudioEvents();
  });

  test('舒尔特正确、错误与完成各有反馈，完成后点击不再发声', () {
    final manager = SchulteManager();
    final events = _listen(manager);
    final regions = manager.board.value.regions;
    manager.onTapRegion(regions.indexWhere((region) => region.number != 1));
    expect(events.last, Sound.error);
    for (var number = 1; number <= regions.length; number++) {
      manager.onTapRegion(
        regions.indexWhere((region) => region.number == number),
      );
    }
    expect(events.where((event) => event == Sound.win), hasLength(1));
    final count = events.length;
    manager.onTapRegion(0);
    expect(events, hasLength(count));
    manager.dispose();
  });

  testWidgets('坦克射击跟随成功开火，不随渲染、冷却中的点击或快照重播', (tester) async {
    final manager = LocalTankManager();
    manager.suspendGame();
    final events = _listen(manager);
    manager.updatePlayerFire();
    manager.updatePlayerFire();
    expect(events, [Sound.shoot]);
    manager.fromJson(manager.toJson());
    expect(events, [Sound.shoot]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(events, [Sound.shoot]);
    manager.dispose();
  });
}
