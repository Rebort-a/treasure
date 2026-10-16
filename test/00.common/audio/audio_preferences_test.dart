import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/audio_preferences.dart';
import 'package:treasure/00.common/service/json_store.dart';

class _Store implements JsonStore {
  final data = <String, Map<String, dynamic>>{};
  Completer<Map<String, dynamic>>? reading;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async {
    if (fail) throw StateError('Storage unavailable');
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
  test('音效与音乐分别保存到全局设置，重新创建后恢复相同状态', () async {
    final store = _Store();
    final preferences = AudioPreferences(store: store);
    await preferences.ready;
    preferences.setSoundEnabled(false);
    preferences.setMusicEnabled(false);
    preferences.setMusicVolume(.58);
    await preferences.flush();
    expect(store.data, {
      '00.common/audio': {'enabled': false},
      '00.common/music': {'enabled': false, 'volume': .58},
    });
    final restored = AudioPreferences(store: store);
    await restored.ready;
    expect(restored.soundEnabled.value, isFalse);
    expect(restored.musicEnabled.value, isFalse);
    expect(restored.musicVolume.value, .58);
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
    preferences.setMusicEnabled(false);
    store.reading!.complete({'enabled': true, 'volume': .73});
    await preferences.ready;
    await preferences.flush();
    expect(preferences.soundEnabled.value, isFalse);
    expect(preferences.musicEnabled.value, isFalse);
    expect(preferences.musicVolume.value, .73);
    expect(store.data['00.common/music'], {'enabled': false, 'volume': .73});
    await preferences.dispose();
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
