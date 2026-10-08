import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/source_dependencies.dart';

void main() {
  final lib = Directory('lib').absolute;
  final files = dartFiles(lib).toList();
  final layers = {'base': 0, 'middle': 1, 'upper': 2};

  Iterable<Uri> dependencies(File file) =>
      sourceDependencies(file.readAsStringSync(), file.uri, lib.uri);

  String relative(Uri uri) =>
      uri.toString().substring(lib.uri.toString().length);

  test('游戏模块相互独立，不依赖首页、聊天入口或其他游戏', () {
    for (final file in files) {
      final module = relative(file.uri).split('/').first;
      final number = RegExp(r'^(\d+)\.').firstMatch(module)?.group(1);
      if (number == null || int.parse(number) < 3) continue;
      for (final dependency in dependencies(file)) {
        if (!dependency.toString().startsWith(lib.uri.toString())) continue;
        final target = relative(dependency).split('/').first;
        expect(
          target,
          anyOf(module, '00.common'),
          reason: '${file.path} 跨模块依赖了 $dependency',
        );
      }
    }
  });

  for (final module in [
    '04.elemental_battle',
    '13.minecraft',
    '18.match_three',
  ]) {
    test('$module 三层依赖只向下', () {
      for (final file in files) {
        final path = relative(file.uri).split('/');
        if (path.first != module || !layers.containsKey(path[1])) continue;
        for (final dependency in dependencies(file)) {
          if (!dependency.toString().startsWith(lib.uri.toString())) continue;
          final target = relative(dependency).split('/');
          if (target.first != module) continue;
          expect(
            layers[target[1]],
            isNotNull,
            reason: '${file.path} 引用了三层目录外的 $dependency',
          );
          expect(
            layers[target[1]]!,
            lessThanOrEqualTo(layers[path[1]]!),
            reason: '${file.path} 向上依赖了 $dependency',
          );
        }
      }
    });
  }

  test('五行数据和逻辑层不依赖 Material、Widgets 或公共界面组件', () {
    for (final file in files) {
      final path = relative(file.uri);
      if (!path.startsWith('04.elemental_battle/base/') &&
          !path.startsWith('04.elemental_battle/middle/')) {
        continue;
      }
      for (final dependency in dependencies(file)) {
        final target = dependency.toString();
        expect(
          target == 'dart:ui' ||
              (target.startsWith('package:flutter/') &&
                  target != 'package:flutter/foundation.dart') ||
              target.startsWith(
                lib.uri.resolve('00.common/widget/').toString(),
              ),
          isFalse,
          reason: '${file.path} 的界面依赖应移动到 upper：$target',
        );
      }
    }
  });

  test('三消内核不依赖 Flutter、存储或网络实现', () {
    for (final file in dartFiles(
      Directory('lib/18.match_three/base').absolute,
    )) {
      for (final dependency in dependencies(file)) {
        expect(
          dependency.scheme == 'dart' && dependency.toString() != 'dart:ui' ||
              dependency.toString().startsWith(
                lib.uri.resolve('18.match_three/base/').toString(),
              ),
          isTrue,
          reason: '${file.path} 依赖了非内核实现 $dependency',
        );
      }
    }
  });

  test('便利插件只出现在已批准的适配文件', () {
    final adapters = {
      'web_socket_channel': {
        '00.common/network/client/base/client_abstract.dart',
      },
      'image_picker': {
        '02.lan_chat/net_page.dart',
        '02.lan_chat/attachment_menu.dart',
      },
      'file_picker': {
        '02.lan_chat/net_page.dart',
        '02.lan_chat/attachment_menu.dart',
        '00.common/widget/component/chat_component.dart',
      },
      'path_provider': {'00.common/service/storage_service.dart'},
      'package_info_plus': {'00.common/tool/app_info.dart'},
    };
    for (final file in files) {
      for (final dependency in dependencies(file)) {
        if (dependency.scheme != 'package') continue;
        final package = dependency.path.split('/').first;
        if (!adapters.containsKey(package)) continue;
        expect(
          adapters[package],
          contains(relative(file.uri)),
          reason: '$package 不应扩散到 ${file.path}',
        );
      }
    }
  });

  test('依赖扫描包含条件导入、导出与 part，忽略注释和 part of', () {
    final result = sourceDependencies(
      '''
/* import '../upper/ignored.dart'; */
// import '../upper/also_ignored.dart';
import 'a.dart' if (dart.library.io) 'b.dart';
export 'package:treasure/00.common/service/json_store.dart';
part 'c.dart';
part of 'library.dart';
''',
      lib.uri.resolve('18.match_three/base/example.dart'),
      lib.uri,
    ).toList();
    expect(result, [
      lib.uri.resolve('18.match_three/base/a.dart'),
      lib.uri.resolve('18.match_three/base/b.dart'),
      lib.uri.resolve('00.common/service/json_store.dart'),
      lib.uri.resolve('18.match_three/base/c.dart'),
    ]);
  });
}
