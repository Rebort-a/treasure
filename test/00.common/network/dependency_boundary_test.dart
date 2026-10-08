import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 解析项目内的文件引用，统一使用 URI 消除相对路径和平台分隔符差异。
Iterable<String> _dependencies(File file, Directory lib) sync* {
  final directives = RegExp(
    r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""",
    multiLine: true,
  );
  for (final match in directives.allMatches(file.readAsStringSync())) {
    final reference = match.group(1)!;
    if (reference.startsWith('package:treasure/')) {
      yield lib.uri
          .resolve(reference.substring('package:treasure/'.length))
          .toString();
    } else if (Uri.parse(reference).scheme.isEmpty) {
      yield file.uri.resolve(reference).toString();
    }
  }
}

void main() {
  test('应用不直接依赖客户端 base 内部实现', () {
    final lib = Directory('lib').absolute;
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.uri.toString().contains('/lib/00.common/')) {
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
      for (final file
          in directory.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
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
