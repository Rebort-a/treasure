import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/01.home/player_settings.dart';

void main() {
  test('default name persists without overwriting language or theme', () async {
    final dir = await Directory.systemTemp.createTemp('treasure_player_');
    final storage = StorageService.instance;
    storage.resetForTesting();
    storage.overrideBaseDir = dir;
    try {
      await storage.init();
      await storage.write('settings', {'language': 1, 'themeMode': 2});
      await PlayerSettings.instance.setDefaultName('  Alice  ');
      expect(PlayerSettings.instance.defaultName.value, 'Alice');
      final saved = await storage.read('settings');
      expect(saved['defaultName'], 'Alice');
      expect(saved['language'], 1);
      expect(saved['themeMode'], 2);

      PlayerSettings.instance.resetForTesting();
      await PlayerSettings.instance.load();
      expect(PlayerSettings.instance.defaultName.value, 'Alice');
      await PlayerSettings.instance.setDefaultName('  ');
      expect(PlayerSettings.instance.defaultName.value, isEmpty);
    } finally {
      PlayerSettings.instance.resetForTesting();
      storage.resetForTesting();
      await dir.delete(recursive: true);
    }
  });
}
