import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/widget/component/game_replay_board.dart';
import 'package:treasure/17.tank/base.dart';
import 'package:treasure/17.tank/foundation_widget.dart';
import 'package:treasure/17.tank/local_manager.dart';

class _Manager extends LocalTankManager {
  int moves = 0;
  int exits = 0;

  @override
  void updatePlayerMove(double angle) {
    moves++;
    super.updatePlayerMove(angle);
  }

  @override
  void leavePage() => exits++;
}

void main() {
  testWidgets('单机结束保留结果、锁定输入，重开后恢复操作并能退出', (tester) async {
    final manager = _Manager();
    await tester.pumpWidget(
      MaterialApp(
        home: TankGameScreen(
          manager: manager,
          showStateButton: true,
          onRestart: manager.requestRestart,
        ),
      ),
    );
    manager.suspendGame();
    manager.gameResult.value = const TankGameResult(victory: true, score: 123);
    await tester.pump();
    expect(find.text('${S.victory}  123'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(manager.moves, 0);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.byKey(const ValueKey('round-replay')));
    await tester.pump();
    expect(manager.gameResult.value, isNull);
    expect(
      tester.widget<GameReplayBoard>(find.byType(GameReplayBoard)).finished,
      isFalse,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(manager.moves, 1);
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(manager.exits, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
  });

  testWidgets('无重开回调保留结果对话框与退出，不出现单机重开板', (tester) async {
    final manager = _Manager();
    await tester.pumpWidget(
      MaterialApp(
        home: TankGameScreen(manager: manager, showStateButton: false),
      ),
    );
    manager.suspendGame();
    manager.gameResult.value = const TankGameResult(victory: false, score: 8);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GameReplayBoard), findsNothing);
    expect(find.text('${S.defeat}  8'), findsOneWidget);
    expect(find.text(S.restart), findsNothing);
    await tester.tap(find.text(S.exit));
    await tester.pump();
    expect(manager.exits, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
  });
}
