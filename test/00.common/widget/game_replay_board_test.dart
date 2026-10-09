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
    final panel = find.byKey(const ValueKey('game-replay-panel'));
    expect(panel, findsNothing);
    await tester.tap(board);
    expect(boardTaps, 1);
    update(() => finished = true);
    await tester.pump();
    expect(tester.getSize(board), size);
    expect(tester.getTopLeft(board), position);
    expect(tester.getSize(panel), const Size.square(96));
    expect(tester.getCenter(panel), tester.getCenter(board));
    // 实际绘制蒙版的 ColoredBox 也只能占用图标底板，不覆盖整个棋盘。
    final background = find.descendant(
      of: panel,
      matching: find.byType(ColoredBox),
    );
    expect(tester.getSize(background), const Size.square(96));
    // 避开居中重开按钮，点击棋盘左上角。
    await tester.tapAt(position + const Offset(12, 12));
    expect(boardTaps, 1);
    await tester.tap(find.text('outside'));
    expect(outsideTaps, 1);
    await tester.tap(find.byKey(const ValueKey('round-replay')));
    await tester.pump();
    expect(replays, 1);
    expect(find.byKey(const ValueKey('round-replay')), findsNothing);
    expect(panel, findsNothing);
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

  for (final boardSize in [160.0, 360.0]) {
    testWidgets('重开和等待底板尺寸固定，不跟随棋盘缩放：$boardSize', (tester) async {
      for (final mode in ['finished', 'waiting', 'preparing']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Center(
                  child: GameReplayBoard(
                    finished: mode == 'finished',
                    waiting: mode == 'waiting',
                    preparing: mode == 'preparing',
                    onReplay: () {},
                    child: SizedBox.square(
                      key: const ValueKey('board'),
                      dimension: boardSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final board = find.byKey(const ValueKey('board'));
        final panel = find.byKey(const ValueKey('game-replay-panel'));
        expect(tester.getSize(board), Size.square(boardSize));
        expect(tester.getSize(panel), const Size.square(96));
        expect(tester.getCenter(panel), tester.getCenter(board));
        if (mode == 'finished') {
          expect(
            tester.getSize(find.byIcon(Icons.replay_circle_filled)),
            const Size.square(96),
          );
          expect(
            tester
                .widget<IconButton>(find.byKey(const ValueKey('round-replay')))
                .iconSize,
            96,
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
