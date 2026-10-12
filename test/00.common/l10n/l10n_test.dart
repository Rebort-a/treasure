import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';

void main() {
  group('LanguageProvider', () {
    setUp(() async {
      StorageService.instance.resetForTesting();
      // 独立临时目录，避免与真实 .treasure/ 及并发测试共享同一份 settings.json
      StorageService.instance.overrideBaseDir = await Directory.systemTemp
          .createTemp('treasure_l10n_');
      await StorageService.instance.init();
      LanguageProvider.instance.resetForTesting();
    });

    tearDown(() async {
      final dir = StorageService.instance.overrideBaseDir;
      StorageService.instance.overrideBaseDir = null;
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('默认语言有效，切换后同步更新 Flutter locale', () async {
      final provider = LanguageProvider.instance;
      expect(provider.locale.value, AppLocale.en);
      expect(provider.flutterLocale, const Locale('en'));
      await provider.toggle();
      expect(provider.locale.value, AppLocale.zh);
      expect(provider.flutterLocale, const Locale('zh'));
    });

    test('语言设置持久化，重新加载不丢失用户选择', () async {
      final provider = LanguageProvider.instance;
      await provider.setLocale(AppLocale.zh);
      provider.resetForTesting();
      await provider.load();
      expect(provider.locale.value, AppLocale.zh);
      expect(provider.flutterLocale, const Locale('zh'));
    });

    test('文案门面随语言切换，参数文案和类型映射均可用', () async {
      final english = S.confirm;
      expect(english, isNotEmpty);
      expect(S.score(5), contains('5'));
      expect(S.roomTypeString('gobang'), isNotEmpty);
      expect(S.damageLog('a', 10, false, 5), isNotEmpty);
      await LanguageProvider.instance.setLocale(AppLocale.zh);
      expect(S.confirm, isNotEmpty);
      expect(S.confirm, isNot(english));
      expect(S.score(5), contains('5'));
      expect(S.roomTypeString('gobang'), isNotEmpty);
      expect(S.damageLog('a', 10, true, 5), isNotEmpty);
    });
  });
}
