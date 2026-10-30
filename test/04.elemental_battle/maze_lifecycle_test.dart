import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/04.elemental_battle/upper/maze_manager.dart';
import 'package:treasure/04.elemental_battle/upper/maze_page.dart';

void main() {
  testWidgets('迷宫页面卸载后不再响应全局键盘或保留活动计时器', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MazePage()));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('迷宫所有者释放后子路由返回不能恢复活动', (tester) async {
    final manager = MazeManager();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    manager.navigateToStatusPage(context);
    await tester.pumpAndSettle();
    manager.dispose();
    manager.dispose();
    final y = manager.player.y;
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(seconds: 2));
    expect(manager.player.y, y);
    expect(tester.takeException(), isNull);
  });
}
