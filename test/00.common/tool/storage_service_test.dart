import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:treasure/00.common/tool/storage_service.dart';

void main() {
  group('StorageService', () {
    setUp(() async {
      StorageService.instance.resetForTesting();
      // 独立临时目录，避免污染真实 .treasure/ 数据
      StorageService.instance.overrideBaseDir =
          await Directory.systemTemp.createTemp('treasure_storage_');
    });

    tearDown(() async {
      final dir = StorageService.instance.overrideBaseDir;
      StorageService.instance.overrideBaseDir = null;
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    group('init', () {
      test('initializes without throwing', () async {
        await expectLater(StorageService.instance.init(), completes);
      });

      test('is idempotent — double init does not throw', () async {
        await StorageService.instance.init();
        await expectLater(StorageService.instance.init(), completes);
      });
    });

    group('read / write', () {
      test('read nonexistent key returns empty map', () async {
        await StorageService.instance.init();
        final data = await StorageService.instance.read('__nonexistent__');
        expect(data, isEmpty);
      });

      test('write then read round-trips correctly', () async {
        await StorageService.instance.init();
        const key = '__test_roundtrip__';
        final expected = {'score': 42, 'name': 'test'};

        await StorageService.instance.write(key, expected);
        final actual = await StorageService.instance.read(key);

        expect(actual, equals(expected));

        // cleanup
        await StorageService.instance.delete(key);
      });

      test('read before init returns empty map', () async {
        // resetForTesting 已在 setUp 中调用，此时未 init
        final data = await StorageService.instance.read('any_key');
        expect(data, isEmpty);
      });
    });

    group('readList / writeList', () {
      test('readList nonexistent key returns empty list', () async {
        await StorageService.instance.init();
        final data = await StorageService.instance.readList('__nonexistent__');
        expect(data, isEmpty);
      });

      test('writeList then readList round-trips correctly', () async {
        await StorageService.instance.init();
        const key = '__test_list_roundtrip__';
        final expected = [
          1,
          'two',
          {'three': 3},
        ];

        await StorageService.instance.writeList(key, expected);
        final actual = await StorageService.instance.readList(key);

        expect(actual, equals(expected));

        // cleanup
        await StorageService.instance.delete(key);
      });
    });

    group('delete', () {
      test('delete removes file — subsequent read returns empty', () async {
        await StorageService.instance.init();
        const key = '__test_delete__';

        await StorageService.instance.write(key, {'alive': true});
        await StorageService.instance.delete(key);
        final data = await StorageService.instance.read(key);

        expect(data, isEmpty);
      });

      test('delete nonexistent file does not throw', () async {
        await StorageService.instance.init();
        await expectLater(
          StorageService.instance.delete('__never_existed__'),
          completes,
        );
      });
    });
  });
}
