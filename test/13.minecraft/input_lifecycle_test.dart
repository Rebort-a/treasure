import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/13.minecraft/base/player.dart';
import 'package:treasure/13.minecraft/base/vector.dart';
import 'package:treasure/13.minecraft/middle/control_manager.dart';
import 'package:treasure/13.minecraft/middle/manager.dart';

void main() {
  testWidgets('失焦清除持续移动、待执行跳跃与破坏，重新聚焦后可以继续输入', (tester) async {
    final manager = Manager();
    final player = Player(position: Vector3.zero);
    final controls = ControlManager(player, manager);
    final other = FocusNode();
    var released = false;
    void release() {
      if (released) return;
      released = true;
      controls.dispose();
      other.dispose();
      manager.dispose();
    }

    addTearDown(release);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Focus(focusNode: controls.focusNode, child: const SizedBox()),
            Focus(focusNode: other, child: const SizedBox()),
          ],
        ),
      ),
    );
    controls.focusNode.requestFocus();
    await tester.pump();
    controls.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyW,
        logicalKey: LogicalKeyboardKey.keyW,
        timeStamp: Duration.zero,
      ),
    );
    controls.updatePlayerMovement(.016);
    expect(player.velocity.z, isNot(0));
    controls.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      ),
    );
    controls.startDestroy();
    manager.destroyProgress = .5;
    other.requestFocus();
    await tester.pump();
    player.velocity = Vector3.zero;
    player.isGrounded = true;
    controls.updatePlayerMovement(.016);
    expect(player.velocity, Vector3.zero);
    expect(player.isGrounded, isTrue);
    expect(manager.destroyProgress, 0);

    controls.focusNode.requestFocus();
    await tester.pump();
    controls.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyW,
        logicalKey: LogicalKeyboardKey.keyW,
        timeStamp: Duration.zero,
      ),
    );
    controls.updatePlayerMovement(.016);
    expect(player.velocity.z, isNot(0));
    await tester.pumpWidget(const SizedBox.shrink());
    release();
  });
}
