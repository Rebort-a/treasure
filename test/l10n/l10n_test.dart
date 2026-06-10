import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:treasure/00.common/tool/storage_service.dart';
import 'package:treasure/00.common/l10n/l10n.dart';

void main() {
  group('LanguageProvider', () {
    setUp(() async {
      StorageService.instance.resetForTesting();
      await StorageService.instance.init();
      await StorageService.instance.delete('settings');
      LanguageProvider.instance.resetForTesting();
    });

    group('default state', () {
      test('default locale is AppLocale.en', () {
        expect(LanguageProvider.instance.locale.value, equals(AppLocale.en));
      });

      test('flutterLocale returns correct Locale', () {
        expect(
          LanguageProvider.instance.flutterLocale,
          equals(const Locale('en')),
        );
      });
    });

    group('toggle', () {
      test('toggle switches locale', () {
        LanguageProvider.instance.toggle();
        expect(LanguageProvider.instance.locale.value, equals(AppLocale.zh));
      });

      test('toggle twice restores original locale', () {
        final original = LanguageProvider.instance.locale.value;

        LanguageProvider.instance.toggle();
        LanguageProvider.instance.toggle();

        expect(LanguageProvider.instance.locale.value, equals(original));
      });

      test('flutterLocale updates after toggle', () {
        LanguageProvider.instance.toggle();
        expect(
          LanguageProvider.instance.flutterLocale,
          equals(const Locale('zh')),
        );
      });
    });

    group('setLocale', () {
      test('setLocale changes locale to specified value', () async {
        await LanguageProvider.instance.setLocale(AppLocale.zh);
        expect(LanguageProvider.instance.locale.value, equals(AppLocale.zh));
      });

      test('setLocale persists — reload restores value', () async {
        await LanguageProvider.instance.setLocale(AppLocale.zh);

        // 模拟重新加载
        LanguageProvider.instance.resetForTesting();
        await LanguageProvider.instance.load();

        expect(LanguageProvider.instance.locale.value, equals(AppLocale.zh));
      });
    });

    group('load', () {
      test('load with no saved data keeps default', () async {
        // resetForTesting + 无持久化数据
        LanguageProvider.instance.resetForTesting();
        await LanguageProvider.instance.load();

        expect(LanguageProvider.instance.locale.value, equals(AppLocale.en));
      });
    });
  });
}
