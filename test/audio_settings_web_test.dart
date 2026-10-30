@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/audio_settings_store.dart';

@JS('localStorage')
external _Storage get _storage;

extension type _Storage(JSObject _) implements JSObject {
  external void removeItem(JSString key);
}

void main() {
  test('浏览器重新创建设置仓库后保留开关和音量，音乐与音效按项目隔离', () async {
    final project = 'audio_web_test_${DateTime.now().microsecondsSinceEpoch}';
    const first = AudioSettingsStore();
    try {
      await first.write('music', {
        'enabled': false,
        'volume': .42,
      }, project: project);
      await first.write('audio', {'enabled': true}, project: project);
      const restored = AudioSettingsStore();
      expect(await restored.read('music', project: project), {
        'enabled': false,
        'volume': .42,
      });
      expect(await restored.read('audio', project: project), {'enabled': true});
      expect(
        await restored.read('music', project: '${project}_other'),
        isEmpty,
      );
    } finally {
      for (final name in ['music', 'audio']) {
        _storage.removeItem('treasure/audio/$project/$name'.toJS);
      }
    }
  });
}
