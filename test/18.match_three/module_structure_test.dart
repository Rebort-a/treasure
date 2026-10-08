import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _layers = {'base': 0, 'middle': 1, 'upper': 2};

void main() {
  final module = Directory('lib/18.match_three').absolute;
  final lib = Directory('lib').absolute;

  test('消消乐所有 Dart 文件都属于三层目录，不保留根目录入口', () {
    for (final file in module.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.uri.toString().substring(module.uri.toString().length);
      expect(
        path.split('/').length,
        greaterThanOrEqualTo(2),
        reason: file.path,
      );
      expect(_layers.keys, contains(path.split('/').first), reason: file.path);
    }
  });

  test('消消乐层间依赖只向下，支持相对引用和 package 引用', () {
    final directives = RegExp(
      r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""",
      multiLine: true,
    );
    for (final file in module.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final sourcePath = file.uri.toString().substring(
        module.uri.toString().length,
      );
      final sourceLayer = _layers[sourcePath.split('/').first]!;
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final reference = match.group(1)!;
        final Uri dependency;
        if (reference.startsWith('package:treasure/')) {
          dependency = lib.uri.resolve(
            reference.substring('package:treasure/'.length),
          );
        } else if (Uri.parse(reference).scheme.isEmpty) {
          dependency = file.uri.resolve(reference);
        } else {
          continue;
        }
        if (!dependency.toString().startsWith(module.uri.toString())) continue;
        final targetPath = dependency.toString().substring(
          module.uri.toString().length,
        );
        final targetLayer = _layers[targetPath.split('/').first];
        expect(targetLayer, isNotNull, reason: '${file.path} 引用了三层目录之外的文件');
        expect(
          targetLayer!,
          lessThanOrEqualTo(sourceLayer),
          reason: '${file.path} 不应向上依赖 $targetPath',
        );
      }
    }
  });
}
