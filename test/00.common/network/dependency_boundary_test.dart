import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../scripts/source_dependencies.dart';

Iterable<String> _dependencies(File file, Directory lib) => sourceDependencies(
  file.readAsStringSync(),
  file.uri,
  lib.uri,
).map((uri) => uri.toString());

void main() {
  test('应用不直接依赖客户端 base 内部实现', () {
    final lib = Directory('lib').absolute;
    for (final file in dartFiles(lib)) {
      if (file.uri.toString().contains('/lib/00.common/')) {
        continue;
      }
      expect(
        _dependencies(file, lib).where(
          (dependency) =>
              dependency.contains('/lib/00.common/network/client/base/'),
        ),
        isEmpty,
        reason: '${file.path} 应通过客户端公开入口访问联机功能',
      );
    }
  });

  test('客户端、协议和服务端不反向依赖界面层', () {
    final lib = Directory('lib').absolute;
    for (final layer in ['client', 'protocol', 'server']) {
      final directory = Directory('lib/00.common/network/$layer');
      for (final file in dartFiles(directory.absolute)) {
        expect(
          _dependencies(file.absolute, lib).where(
            (dependency) =>
                dependency.contains('/lib/00.common/network/widget/') ||
                dependency.contains('/lib/00.common/widget/'),
          ),
          isEmpty,
          reason: '${file.path} 不应依赖界面或导航组件',
        );
      }
    }
  });
}
