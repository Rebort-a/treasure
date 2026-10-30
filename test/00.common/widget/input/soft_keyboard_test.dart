import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/widget/input/soft_keyboard.dart';

void main() {
  testWidgets('自定义键盘输入会传递给使用者', (tester) async {
    final input = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CustomKeyboard(
                onInputContent: input.add,
                onDeleteContent: () {},
                onHideKeyboard: () {},
                onCursorMove: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(MaterialButton, 'a'));
    expect(input, ['a']);
    expect(tester.takeException(), isNull);
  });
}
