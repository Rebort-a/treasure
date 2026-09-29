import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/widget/input/soft_keyboard.dart';
import 'package:treasure/13.minecraft/upper/page.dart';

void main() {
  testWidgets('custom keyboard scales from its available width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CustomKeyboard(
                onInputContent: (_) {},
                onDeleteContent: () {},
                onHideKeyboard: () {},
                onCursorMove: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final button = tester.widget<KeyboardButton>(
      find.byType(KeyboardButton).first,
    );
    expect(button.buttonSize, closeTo(25.2, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Minecraft hotbar lays out with local orientation constraints', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MinecraftPage()));
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
