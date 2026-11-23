import 'dart:io';

const _messagesPath = 'lib/00.common/l10n/';
const _baseFile = 'app_localizations.dart';
const _intlImport = "import 'package:intl/intl.dart' as intl;";
const _legacyImport =
    "import 'package:flutter_localizations/flutter_localizations.dart';";

Future<void> main(List<String> args) async {
  final check = args.length == 1 && args.single == '--check';
  if (args.isNotEmpty && !check) {
    stderr.writeln(
      'Usage: dart run scripts/generate_localizations.dart [--check]',
    );
    exitCode = 64;
    return;
  }
  final messages = Directory.fromUri(
    Platform.script.resolve('../$_messagesPath'),
  );
  final temp = Directory.systemTemp.createTempSync('treasure-l10n-');
  try {
    final inputs = messages.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.arb'),
    );
    for (final file in inputs) {
      file.copySync(temp.uri.resolve(file.uri.pathSegments.last).toFilePath());
    }
    // Flutter 3.50 emits legacy UI delegates. Generate outside the app so
    // flutter pub get/run/build cannot overwrite the migrated sources.
    File.fromUri(temp.uri.resolve('pubspec.yaml')).writeAsStringSync(
      'name: localization_generator\n'
      'flutter:\n'
      '  generate: true\n',
    );
    final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final sibling = File.fromUri(
      File(Platform.resolvedExecutable).uri.resolve('../../../$executable'),
    );
    await _run(sibling.existsSync() ? sibling.path : executable, [
      'gen-l10n',
      '--arb-dir=.',
      '--output-dir=.',
      '--template-arb-file=app_en.arb',
      '--output-localization-file=$_baseFile',
    ], temp);

    final generated = temp
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    for (final file in generated) {
      final name = file.uri.pathSegments.last;
      var source = file.readAsStringSync().replaceAll('\r\n', '\n');
      source = source.replaceAll('// ignore_for_file: type=lint\n', '');
      source = source.replaceAll('// ignore: unused_import\n', '');
      if (name == _baseFile) {
        source = _migrateDelegates(source);
      } else {
        final withoutIntlImport = source.replaceFirst('$_intlImport\n', '');
        if (!withoutIntlImport.contains('intl.')) source = withoutIntlImport;
        source = source.replaceAllMapped(
          RegExp(r"\(\[String locale = ('[^']+')\]\) : super\(locale\);"),
          (match) => '([super.locale = ${match[1]}]);',
        );
      }
      if (RegExp(
        r'^\s*//\s*ignore(?:_for_file)?:',
        multiLine: true,
      ).hasMatch(source)) {
        throw StateError('Unexpected analyzer suppression generated in $name.');
      }
      file.writeAsStringSync(
        '// Generated from ARB files; do not edit.\n$source',
      );
    }
    await _run(Platform.resolvedExecutable, [
      'format',
      for (final file in generated) file.path,
    ], temp);
    for (final file in generated) {
      final name = file.uri.pathSegments.last;
      final target = File.fromUri(messages.uri.resolve(name));
      final source = file.readAsStringSync().replaceAll('\r\n', '\n');
      if (check) {
        if (!target.existsSync() ||
            target.readAsStringSync().replaceAll('\r\n', '\n') != source) {
          stderr.writeln('Out of date: $_messagesPath$name');
          exitCode = 1;
        }
      } else {
        target.writeAsStringSync(source.replaceAll('\n', '\r\n'));
      }
    }
  } finally {
    temp.deleteSync(recursive: true);
  }
}

String _migrateDelegates(String source) {
  const legacyDelegates =
      '    GlobalMaterialLocalizations.delegate,\n'
      '    GlobalCupertinoLocalizations.delegate,\n'
      '    GlobalWidgetsLocalizations.delegate,';
  final docs = source.indexOf('/// Callers');
  final declaration = source.indexOf('abstract class AppLocalizations');
  if (docs < 0 ||
      declaration <= docs ||
      !source.contains(_legacyImport) ||
      !source.contains(legacyDelegates)) {
    throw StateError(
      'Flutter localization template changed; review the migration.',
    );
  }
  return source
      .replaceRange(docs, declaration, '/// Application translations.\n')
      .replaceFirst(
        _legacyImport,
        "import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;",
      )
      .replaceFirst(
        legacyDelegates,
        '    ...GlobalMaterialLocalizations.delegates,',
      );
}

Future<void> _run(String executable, List<String> args, Directory cwd) async {
  final result = await Process.run(
    executable,
    args,
    workingDirectory: cwd.path,
    runInShell: Platform.isWindows && executable.endsWith('.bat'),
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      args,
      'Generation failed',
      result.exitCode,
    );
  }
}
