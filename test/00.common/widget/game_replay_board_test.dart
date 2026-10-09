import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/widget/component/game_replay_board.dart';

void main() {
  testWidgets('共用重开层不改变布局，结束后只阻止棋盘操作', (tester) async {
    var finished = false;
    var boardTaps = 0;
    var outsideTaps = 0;
    var replays = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Column(
              children: [
                TextButton(
                  onPressed: () => outsideTaps++,
                  child: const Text('outside'),
                ),
                GameReplayBoard(
                  finished: finished,
                  onReplay: () {
                    replays++;
                    update(() => finished = false);
                  },
                  child: GestureDetector(
                    onTap: () => boardTaps++,
                    child: const SizedBox(
                      key: ValueKey('board'),
                      width: 240,
                      height: 240,
                      child: ColoredBox(color: Colors.green),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    final board = find.byKey(const ValueKey('board'));
    final size = tester.getSize(board);
    final position = tester.getTopLeft(board);
    await tester.tap(board);
    expect(boardTaps, 1);
    update(() => finished = true);
    await tester.pump();
    expect(tester.getSize(board), size);
    expect(tester.getTopLeft(board), position);
    // 避开居中重开按钮，点击棋盘左上角。
    await tester.tapAt(position + const Offset(12, 12));
    expect(boardTaps, 1);
    await tester.tap(find.text('outside'));
    expect(outsideTaps, 1);
    await tester.tap(find.byKey(const ValueKey('round-replay')));
    await tester.pump();
    expect(replays, 1);
    expect(find.byKey(const ValueKey('round-replay')), findsNothing);
    await tester.tap(board);
    expect(boardTaps, 2);
  });

  for (final preparing in [false, true]) {
    testWidgets('等待状态显示进度，不允许重复点击重开：准备中 $preparing', (tester) async {
      var replays = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: GameReplayBoard(
              finished: !preparing,
              waiting: !preparing,
              preparing: preparing,
              onReplay: () => replays++,
              child: const SizedBox(width: 240, height: 240),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('round-replay')), findsNothing);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.descendant(
                of: find.byType(GameReplayBoard),
                matching: find.byType(AbsorbPointer),
              ),
            )
            .absorbing,
        isTrue,
      );
      await tester.tapAt(tester.getCenter(find.byType(GameReplayBoard)));
      expect(replays, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
