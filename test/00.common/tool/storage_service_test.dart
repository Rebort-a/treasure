import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:treasure/00.common/service/storage_service.dart';

void main() {
  group('StorageService', () {
    setUp(() async {
      StorageService.instance.resetForTesting();
      // 独立临时目录，避免污染真实 .treasure/ 数据
      StorageService.instance.overrideBaseDir = await Directory.systemTemp
          .createTemp('treasure_storage_');
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

      test('stores data inside its project directory', () async {
        await StorageService.instance.init();

        await StorageService.instance.write('progress', {
          'level': 2,
        }, project: '08.sudoku');

        final baseDir = StorageService.instance.overrideBaseDir!;
        expect(
          await File('${baseDir.path}/08.sudoku/progress.json').exists(),
          isTrue,
        );
        expect(
          await StorageService.instance.read('progress', project: '08.sudoku'),
          {'level': 2},
        );
        expect(
          await StorageService.instance.read(
            'progress',
            project: '11.spaceship',
          ),
          isEmpty,
        );
      });

      test('does not read files outside the project directory', () async {
        await StorageService.instance.init();
        final baseDir = StorageService.instance.overrideBaseDir!;
        await File('${baseDir.path}/settings.json')
            .writeAsString('{"language":"zh"}');

        expect(await StorageService.instance.read('settings'), isEmpty);
        expect(
          await File('${baseDir.path}/00.common/settings.json').exists(),
          isFalse,
        );
      });

      test('overwriting an existing key persists the latest value', () async {
        await StorageService.instance.init();
        const key = '__test_overwrite__';

        await StorageService.instance.write(key, {'version': 1});
        await StorageService.instance.write(key, {'version': 2});

        expect(await StorageService.instance.read(key), {'version': 2});
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

    group('串行更新与失败恢复', () {
      test('并发更新同一文档保留各字段，按调用顺序执行写入和删除', () async {
        final store = StorageService.instance;
        await store.init();
        await Future.wait([
          store.update('settings', (data) => data['language'] = 1),
          store.update('settings', (data) => data['themeMode'] = 2),
          store.update('settings', (data) => data['defaultName'] = 'Alice'),
        ]);
        expect(await store.read('settings'), {
          'language': 1,
          'themeMode': 2,
          'defaultName': 'Alice',
        });
        await Future.wait([
          store.write('settings', {'old': true}),
          store.delete('settings'),
          store.update('settings', (data) => data['fresh'] = true),
        ]);
        expect(await store.read('settings'), {'fresh': true});
      });

      test('同一文档的读取与替换按调用顺序完成，不竞争文件句柄', () async {
        final store = StorageService.instance;
        await store.init();
        await store.write('concurrent', {'value': 0});
        for (var value = 1; value <= 12; value++) {
          final before = store.read('concurrent');
          final writing = store.write('concurrent', {'value': value});
          final after = store.read('concurrent');
          expect(await before, {'value': value - 1});
          await writing;
          expect(await after, {'value': value});
        }
      });

      test('写入失败可感知，之后修复路径仍可保存', () async {
        final store = StorageService.instance;
        await store.init();
        final blocker = File('${store.overrideBaseDir!.path}/blocked');
        await blocker.writeAsString('not a directory');
        await expectLater(
          store.write('settings', {'value': 1}, project: 'blocked'),
          throwsA(isA<FileSystemException>()),
        );
        await blocker.delete();
        await store.write('settings', {'value': 2}, project: 'blocked');
        expect(await store.read('settings', project: 'blocked'), {'value': 2});
      });

      test('损坏文档更新失败不覆盖原文件，失败队列仍可继续', () async {
        final store = StorageService.instance;
        await store.init();
        await store.write('settings', {'value': 1});
        final file = File(
          '${store.overrideBaseDir!.path}/00.common/settings.json',
        );
        await file.writeAsString('broken');
        await expectLater(
          store.update('settings', (data) => data['other'] = 2),
          throwsFormatException,
        );
        expect(await file.readAsString(), 'broken');
        await store.write('settings', {'value': 3});
        expect(await store.read('settings'), {'value': 3});
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
