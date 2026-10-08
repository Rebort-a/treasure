import 'dart:io';

/// 收集源码依赖，包含条件导入；架构测试不依赖目录分隔符或相对路径写法。
Iterable<Uri> sourceDependencies(String source, Uri file, Uri lib) sync* {
  final withoutBlockComments = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  final directives = RegExp(
    r'^\s*(?:import|export|part)\s+(?!of\b)([^;]+);',
    multiLine: true,
  );
  final references = RegExp(r'''['"]([^'"]+)['"]''');
  for (final directive in directives.allMatches(withoutBlockComments)) {
    for (final reference in references.allMatches(directive.group(1)!)) {
      final path = reference.group(1)!;
      if (path.startsWith('package:treasure/')) {
        yield lib.resolve(path.substring('package:treasure/'.length));
      } else if (Uri.parse(path).scheme.isEmpty) {
        yield file.resolve(path);
      } else {
        yield Uri.parse(path);
      }
    }
  }
}

Iterable<File> dartFiles(Directory directory) => directory
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
