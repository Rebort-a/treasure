import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/audio_preferences.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/00.common/widget/button/scale_button.dart';

class _Store implements JsonStore {
  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async => {};

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {}
}

void main() {
  testWidgets('长按连发的震动独立开关且即时生效，松手和销毁均停止连发', (tester) async {
    final preferences = AudioPreferences(store: _Store());
    await preferences.ready;
    preferences.setSoundEnabled(false);
    preferences.setVoiceEnabled(false);
    preferences.setMusicEnabled(false);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate')
          haptics.add(call.arguments);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScaleButton(
              size: const Size(80, 80),
              audioPreferences: preferences,
              onPressed: () => presses++,
            ),
          ),
        ),
      ),
    );
    final button = find.byType(ScaleButton);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(presses, 1);
    expect(haptics, isEmpty);

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(haptics, isNotEmpty);
    expect(
      haptics.every((value) => value == 'HapticFeedbackType.mediumImpact'),
      isTrue,
    );
    final beforeMute = haptics.length;
    final beforeRepeat = presses;
    preferences.setVibrationEnabled(false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(haptics, hasLength(beforeMute));
    expect(presses, greaterThan(beforeRepeat));
    preferences.setVibrationEnabled(true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(haptics.length, greaterThan(beforeMute));

    await gesture.up();
    await tester.pumpAndSettle();
    final afterRelease = (presses, haptics.length);
    await tester.pump(const Duration(milliseconds: 300));
    expect((presses, haptics.length), afterRelease);

    final held = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
    await held.up();
    final afterDispose = (presses, haptics.length);
    await tester.pump(const Duration(milliseconds: 300));
    expect((presses, haptics.length), afterDispose);
    await preferences.dispose();
  });
}
