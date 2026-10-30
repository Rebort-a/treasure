import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/service/player_settings.dart';
import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/00.common/style/theme.dart';

void main() {
  late Directory directory;
  final storage = StorageService.instance;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('treasure_settings_');
    storage.resetForTesting();
    storage.overrideBaseDir = directory;
    await storage.init();
    LanguageProvider.instance.resetForTesting();
    ThemeProvider.instance.resetForTesting();
    PlayerSettings.instance.resetForTesting();
  });

  tearDown(() async {
    LanguageProvider.instance.resetForTesting();
    ThemeProvider.instance.resetForTesting();
    PlayerSettings.instance.resetForTesting();
    storage.resetForTesting();
    await directory.delete(recursive: true);
  });

  test('损坏的配置字段回退默认值，不阻断其他合法配置加载', () async {
    final cases = <Map<String, dynamic>>[
      {
        'language': 'zh',
        'themeMode': ThemeMode.dark.index,
        'defaultName': ' Alice ',
      },
      {'language': AppLocale.zh.index, 'themeMode': [], 'defaultName': 7},
      {'language': -1, 'themeMode': 999, 'defaultName': null},
    ];
    for (final data in cases) {
      await storage.write('settings', data);
      PlayerSettings.instance.resetForTesting();
      await LanguageProvider.instance.load();
      await ThemeProvider.instance.load();
      await PlayerSettings.instance.load();
      expect(
        LanguageProvider.instance.locale.value,
        data['language'] == AppLocale.zh.index ? AppLocale.zh : AppLocale.en,
      );
      expect(
        ThemeProvider.instance.themeMode.value,
        data['themeMode'] == ThemeMode.dark.index
            ? ThemeMode.dark
            : ThemeMode.light,
      );
      expect(
        PlayerSettings.instance.defaultName.value,
        data['defaultName'] is String ? 'Alice' : '',
      );
    }
  });
}
