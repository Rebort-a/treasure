import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/audio_preferences.dart';
import 'package:treasure/00.common/service/json_store.dart';

class _Store implements JsonStore {
  final data = <String, Map<String, dynamic>>{};
  Completer<Map<String, dynamic>>? reading;
  bool fail = false;
  final failedReads = <String>{};

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async {
    if (fail || failedReads.contains(name)) {
      throw StateError('Storage unavailable');
    }
    return reading == null
        ? Map.of(data['$project/$name'] ?? {})
        : await reading!.future;
  }

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> value, {
    String project = '00.common',
  }) async {
    if (fail) throw StateError('Storage unavailable');
    data['$project/$name'] = Map.of(value);
  }
}

void main() {
  test('音效、语音、音乐与震动独立保存，重新创建后恢复相同状态', () async {
    final store = _Store();
    final preferences = AudioPreferences(store: store);
    await preferences.ready;
    preferences.setSoundEnabled(false);
    preferences.setVoiceEnabled(false);
    preferences.setMusicEnabled(false);
    preferences.setMusicVolume(.58);
    preferences.setVibrationEnabled(false);
    await preferences.flush();
    expect(store.data, {
      '00.common/audio': {'enabled': false},
      '00.common/voice': {'enabled': false},
      '00.common/music': {'enabled': false, 'volume': .58},
      '00.common/vibration': {'enabled': false},
    });
    final restored = AudioPreferences(store: store);
    await restored.ready;
    expect(restored.soundEnabled.value, isFalse);
    expect(restored.voiceEnabled.value, isFalse);
    expect(restored.musicEnabled.value, isFalse);
    expect(restored.musicVolume.value, .58);
    expect(restored.vibrationEnabled.value, isFalse);
    restored.setMusicVolume(2);
    restored.setMusicVolume(double.nan);
    expect(restored.musicVolume.value, 1);
    await preferences.dispose();
    await restored.dispose();
  });

  test('迟到读取不覆盖用户操作，未修改的音量仍恢复并保存', () async {
    final store = _Store()..reading = Completer<Map<String, dynamic>>();
    final preferences = AudioPreferences(store: store);
    preferences.setSoundEnabled(false);
    preferences.setVoiceEnabled(false);
    preferences.setMusicEnabled(false);
    preferences.setVibrationEnabled(false);
    store.reading!.complete({'enabled': true, 'volume': .73});
    await preferences.ready;
    await preferences.flush();
    expect(preferences.soundEnabled.value, isFalse);
    expect(preferences.voiceEnabled.value, isFalse);
    expect(preferences.musicEnabled.value, isFalse);
    expect(preferences.musicVolume.value, .73);
    expect(preferences.vibrationEnabled.value, isFalse);
    expect(store.data['00.common/music'], {'enabled': false, 'volume': .73});
    await preferences.dispose();
  });

  test('首次拆分语音沿用旧静音状态，之后音效开关不影响语音及其下次恢复', () async {
    for (final legacySound in [null, false, true]) {
      final store = _Store();
      if (legacySound != null) {
        store.data['00.common/audio'] = {'enabled': legacySound};
      }
      final preferences = AudioPreferences(store: store);
      await preferences.ready;
      final expectedVoice = legacySound ?? true;
      expect(preferences.voiceEnabled.value, expectedVoice);
      preferences.setSoundEnabled(!expectedVoice);
      await preferences.dispose();
      final restored = AudioPreferences(store: store);
      await restored.ready;
      expect(restored.soundEnabled.value, !expectedVoice);
      expect(restored.voiceEnabled.value, expectedVoice);
      await restored.dispose();
    }
  });

  test('音效或语音读取失败时不写入猜测的迁移值，避免覆盖已有偏好', () async {
    for (final failed in ['audio', 'voice']) {
      final store = _Store()
        ..data['00.common/audio'] = {'enabled': false}
        ..failedReads.add(failed);
      if (failed == 'voice') {
        store.data['00.common/voice'] = {'enabled': true};
      }
      final preferences = AudioPreferences(store: store);
      await preferences.ready;
      await preferences.flush();
      expect(
        store.data['00.common/voice'],
        failed == 'voice' ? {'enabled': true} : isNull,
      );
      await preferences.dispose();
    }
  });

  test('存储异常保留可操作的会话设置，失败不会阻断后续保存', () async {
    final store = _Store()..fail = true;
    final preferences = AudioPreferences(store: store);
    await preferences.ready;
    preferences.setSoundEnabled(false);
    await preferences.flush();
    expect(preferences.soundEnabled.value, isFalse);
    store.fail = false;
    preferences.setSoundEnabled(true);
    preferences.setMusicVolume(.4);
    await preferences.flush();
    expect(store.data['00.common/audio'], {'enabled': true});
    expect(store.data['00.common/music']!['volume'], .4);
    await preferences.dispose();
    preferences.setSoundEnabled(false);
  });
}
