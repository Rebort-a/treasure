import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/13.minecraft/upper/page.dart';
import 'package:treasure/13.minecraft/upper/widget.dart';
import 'package:treasure/13.minecraft/base/block.dart';
import 'package:treasure/13.minecraft/middle/manager.dart';
import 'package:treasure/00.common/widget/component/game_audio_scope.dart';

void main() {
  testWidgets('快捷栏选择与数量离散更新，场景通知不重建输入层', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const MaterialApp(home: MinecraftPage()));
    await tester.pump();
    final manager =
        tester.widget<GameAudioScope>(find.byType(GameAudioScope)).source
            as Manager;
    final keyboard = tester.widget<KeyboardListener>(
      find.byType(KeyboardListener),
    );
    final scene = manager.scene.value;
    manager.selectedSlot = 1;
    manager.addInventory(BlockType.glass, 2);
    expect(identical(manager.scene.value, scene), isTrue);
    await tester.pump();
    final bar = tester.widget<Hotbar>(find.byType(Hotbar));
    expect(bar.selectedSlot, 1);
    expect(bar.getCount(BlockType.glass), 26);
    expect(
      identical(
        keyboard,
        tester.widget<KeyboardListener>(find.byType(KeyboardListener)),
      ),
      isTrue,
    );
    final revision = manager.hotbarRevision.value;
    manager.notifyListeners();
    await tester.pump();
    expect(manager.hotbarRevision.value, revision);
    expect(
      identical(
        keyboard,
        tester.widget<KeyboardListener>(find.byType(KeyboardListener)),
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Minecraft 页面可正常构建和卸载', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MinecraftPage()));
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
