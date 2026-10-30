import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/widget/component/game_audio_scope.dart';
import 'package:treasure/00.common/widget/component/game_replay_board.dart';
import 'package:treasure/14.tower_defense/base.dart';
import 'package:treasure/14.tower_defense/manager.dart';
import 'package:treasure/14.tower_defense/page.dart';

void main() {
  testWidgets('塔防结束锁定战场与建塔面板，重开按当前尺寸初始化', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TowerDefensePage()));
    await tester.pump();
    final scope = tester.widget<GameAudioScope>(find.byType(GameAudioScope));
    final manager = scope.source as Manager;
    final oldWidth = manager.map.width;
    manager.state.value = GameState.lost;
    await tester.pump();
    expect(
      tester.widget<GameReplayBoard>(find.byType(GameReplayBoard)).finished,
      isTrue,
    );
    final selected = manager.selectedFort.value;
    await tester.tapAt(const Offset(200, 200));
    expect(manager.selectedFort.value, selected);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.byKey(const ValueKey('round-replay')));
    await tester.pump();
    await tester.pump();
    expect(manager.state.value, GameState.preparing);
    expect(manager.map.width, greaterThan(oldWidth));
    expect(
      tester.widget<GameReplayBoard>(find.byType(GameReplayBoard)).finished,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
