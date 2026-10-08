import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('README 的游戏数量、应用清单和 SDK 与仓库一致', () {
    final readme = File('README.md').readAsStringSync();
    final games = Directory('lib')
        .listSync()
        .whereType<Directory>()
        .where(
          (directory) => RegExp(r'^(?:0[3-9]|1[0-9]|[2-9]\d)\.').hasMatch(
            directory.uri.pathSegments.where((s) => s.isNotEmpty).last,
          ),
        )
        .toList();
    expect(readme, contains('${games.length}_Games_+_LAN_Chat'));
    for (final directory in games) {
      final name = directory.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final number = name.split('.').first;
      expect(readme, contains('| $number |'), reason: name);
    }
    final sdk = jsonDecode(File('.fvmrc').readAsStringSync()) as Map;
    expect(readme, contains('Flutter-${sdk['flutter']}'));
    final constraint = RegExp(
      r'^\s+sdk: (\^[\d.]+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
    expect(readme, contains('Dart **$constraint**'));
  });

  test('README 本地链接与预览图片存在，不发布悬空文档入口', () {
    final readme = File('README.md').readAsStringSync();
    for (final match in RegExp(r'\]\(([^)]+)\)').allMatches(readme)) {
      final reference = match.group(1)!;
      if (Uri.parse(reference).hasScheme || reference.startsWith('#')) continue;
      final file = reference.split('#').first;
      expect(File(file).existsSync(), isTrue, reason: reference);
    }
  });
}
