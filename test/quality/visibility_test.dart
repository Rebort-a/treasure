import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('分享图片为有效的 1280×640 PNG，GitHub 与 Web 使用同一份内容', () {
    final github = File('.github/social-preview.png').readAsBytesSync();
    final web = File('web/social-preview.png').readAsBytesSync();
    expect(github, orderedEquals(web));
    expect(github.take(8), orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]));
    final header = ByteData.sublistView(github);
    expect(header.getUint32(16, Endian.big), 1280);
    expect(header.getUint32(20, Endian.big), 640);
    expect(github.length, lessThan(1024 * 1024));
  });

  test('手动设置说明与仓库分享信息一致，Topics 数量和格式有效', () {
    final config = jsonDecode(
      File('.github/repository-metadata.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(config['repository'], 'Rebort-a/treasure');
    expect(config['slogan'], '六端为一，无界互联');
    final topics = (config['topics'] as List).cast<String>();
    expect(topics.length, inInclusiveRange(1, 20));
    expect(topics.toSet().length, topics.length);
    for (final topic in topics) {
      expect(RegExp(r'^[a-z0-9][a-z0-9-]{0,49}$').hasMatch(topic), isTrue);
    }
    final guide = File('docs/visibility.md').readAsStringSync();
    expect(guide, contains(config['description'] as String));
    expect(guide, contains(config['homepage'] as String));
    for (final topic in topics) {
      expect(
        RegExp(
          '^\\s*${RegExp.escape(topic)}\\s*\$',
          multiLine: true,
        ).hasMatch(guide),
        isTrue,
      );
    }
    expect(guide, contains('不是 GitHub 自动读取的配置'));
    expect(guide, isNot(contains('configure-github.ps1')));
    expect(guide, isNot(contains('generate-social-preview.ps1')));
  });

  test('Web 分享元信息与实际静态资源和 metadata 地址一致', () {
    final index = File('web/index.html').readAsStringSync();
    final config = jsonDecode(
      File('.github/repository-metadata.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final homepage = config['homepage'] as String;
    expect(index, contains('href="$homepage"'));
    expect(index, contains('property="og:title"'));
    expect(index, contains('property="og:image"'));
    expect(index, contains('name="twitter:card"'));
    expect(index, contains('${homepage}social-preview.png'));
    expect(index, contains('href="\$FLUTTER_BASE_HREF"'));
    expect(index, contains('flutter_bootstrap.js'));
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['description'], contains('六端为一，无界互联'));
  });

  test('分享说明和社区入口文件存在，不声称草稿已发布', () {
    for (final file in [
      '.github/ISSUE_TEMPLATE/bug_report.yml',
      '.github/ISSUE_TEMPLATE/feature_request.yml',
      '.github/ISSUE_TEMPLATE/config.yml',
      '.github/PULL_REQUEST_TEMPLATE.md',
      'docs/visibility.md',
      'docs/post-drafts.md',
    ]) {
      expect(File(file).existsSync(), isTrue, reason: file);
    }
    final guide = File('docs/visibility.md').readAsStringSync();
    expect(guide, contains('35 Star'));
    expect(guide, contains('不会因为提交一个 JSON 或 PNG 文件就自动改变'));
  });
}
