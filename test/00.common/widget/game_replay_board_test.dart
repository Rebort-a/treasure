import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/widget/component/game_replay_board.dart';

void main() {
  testWidgets('结束延时期间恢复游戏或退出页面会取消结算显示', (tester) async {
    var finished = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return GameReplayBoard(
              finished: finished,
              onReplay: () {},
              child: const SizedBox(width: 240, height: 240),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    update(() => finished = false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('round-replay')), findsNothing);
    update(() => finished = true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('结束后阻止棋盘操作，不影响外部控件，重开恢复操作', (tester) async {
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
    final position = tester.getTopLeft(board);
    await tester.tap(board);
    expect(boardTaps, 1);
    update(() => finished = true);
    await tester.pump();
    // 避开居中重开按钮，点击棋盘左上角。
    await tester.tapAt(position + const Offset(12, 12));
    expect(boardTaps, 1);
    await tester.tap(find.text('outside'));
    expect(outsideTaps, 1);
    expect(find.byKey(const ValueKey('round-replay')), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('round-replay')));
    await tester.pump();
    expect(replays, 1);
    expect(find.byKey(const ValueKey('round-replay')), findsNothing);
    await tester.tap(board);
    expect(boardTaps, 2);
  });

  for (final preparing in [false, true]) {
    testWidgets('等待或准备期间不允许重复点击重开：准备中 $preparing', (tester) async {
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
      expect(find.byKey(const ValueKey('round-replay')), findsNothing);
      await tester.tapAt(tester.getCenter(find.byType(GameReplayBoard)));
      expect(replays, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
