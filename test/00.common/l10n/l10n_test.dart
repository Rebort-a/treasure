import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:treasure/00.common/tool/storage_service.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';

void main() {
  group('LanguageProvider', () {
    setUp(() async {
      StorageService.instance.resetForTesting();
      // 独立临时目录，避免与真实 .treasure/ 及并发测试共享同一份 settings.json
      StorageService.instance.overrideBaseDir =
          await Directory.systemTemp.createTemp('treasure_l10n_');
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
      test('toggle switches locale', () async {
        await LanguageProvider.instance.toggle();
        expect(LanguageProvider.instance.locale.value, equals(AppLocale.zh));
      });

      test('toggle twice restores original locale', () async {
        final original = LanguageProvider.instance.locale.value;

        await LanguageProvider.instance.toggle();
        await LanguageProvider.instance.toggle();

        expect(LanguageProvider.instance.locale.value, equals(original));
      });

      test('flutterLocale updates after toggle', () async {
        await LanguageProvider.instance.toggle();
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

    // S 门面回归：验证委托到 ARB 生成的 AppLocalizations 正确，
    // 含 getter、带参方法、roomTypeString 路由、damageLog 拆分路由。
    group('S facade', () {
      test('en: returns English strings', () {
        LanguageProvider.instance.resetForTesting();
        expect(S.confirm, equals('Confirm'));
        expect(S.cancel, equals('Cancel'));
        expect(S.score(5), equals('Score: 5'));
        expect(S.roomTypeString('gobang'), equals('Gomoku'));
        expect(S.damageLog('a', 10, false, 5), contains('physical'));
      });

      test('zh: returns Chinese strings', () async {
        LanguageProvider.instance.resetForTesting();
        await LanguageProvider.instance.setLocale(AppLocale.zh);
        expect(S.confirm, equals('确认'));
        expect(S.score(5), equals('分数: 5'));
        expect(S.roomTypeString('gobang'), equals('五子棋'));
        expect(S.damageLog('a', 10, true, 5), contains('法术'));
        expect(S.damageLog('a', 10, false, 5), contains('物理'));
      });
    });
  });
}
