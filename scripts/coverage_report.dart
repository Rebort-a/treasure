import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// 同一文件的多段记录合并到具体行，避免重复统计覆盖率。
class CoverageReport {
  final Map<String, Map<int, int>> files;

  CoverageReport._(this.files);

  factory CoverageReport.parse(String content) {
    final files = <String, Map<int, int>>{};
    Map<int, int>? current;
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.startsWith('SF:')) {
        final path = normalizeSourcePath(line.substring(3));
        current = path.startsWith('lib/') && !isGenerated(path)
            ? files.putIfAbsent(path, () => {})
            : null;
      } else if (line.startsWith('DA:') && current != null) {
        final values = line.substring(3).split(',');
        if (values.length < 2) throw FormatException('Invalid DA: $line');
        final number = int.tryParse(values[0]);
        final hits = int.tryParse(values[1]);
        if (number == null || number <= 0 || hits == null || hits < 0) {
          throw FormatException('Invalid DA: $line');
        }
        current[number] = math.max(current[number] ?? 0, hits);
      } else if (line == 'end_of_record') {
        current = null;
      }
    }
    return CoverageReport._(files);
  }

  CoverageTotals totalsFor(String prefix) {
    var found = 0;
    var hit = 0;
    for (final entry in files.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      found += entry.value.length;
      hit += entry.value.values.where((hits) => hits > 0).length;
    }
    return CoverageTotals(found, hit);
  }

  List<String> check(
    Map<String, double> thresholds,
    Iterable<String> sourceFiles,
  ) {
    final failures = <String>[];
    for (final entry in thresholds.entries) {
      final totals = totalsFor(entry.key);
      if (totals.found == 0 || totals.percent < entry.value) {
        failures.add(
          '${entry.key}: ${totals.percent.toStringAsFixed(1)}% '
          '< ${entry.value.toStringAsFixed(1)}% (lines: ${totals.found})',
        );
      }
      // 关键模块不能通过漏报整个文件来提高覆盖率。
      for (final rawPath in sourceFiles) {
        final path = normalizeSourcePath(rawPath);
        if (path.startsWith(entry.key) &&
            !isGenerated(path) &&
            !files.containsKey(path)) {
          failures.add('${entry.key}: missing LCOV record for $path');
        }
      }
    }
    return failures;
  }
}

class CoverageTotals {
  final int found;
  final int hit;

  const CoverageTotals(this.found, this.hit);

  double get percent => found == 0 ? 0 : hit * 100 / found;

  Map<String, Object> toJson() => {
    'linesFound': found,
    'linesHit': hit,
    'percent': percent,
  };
}

String normalizeSourcePath(String path) {
  var normalized = path.replaceAll('\\', '/');
  final lib = normalized.lastIndexOf('/lib/');
  if (lib >= 0) normalized = normalized.substring(lib + 1);
  if (normalized.startsWith('./')) normalized = normalized.substring(2);
  return normalized;
}

bool isGenerated(String path) => RegExp(
  r'(?:^|/)app_localizations(?:_[^/]+)?\.dart$|\.g\.dart$|\.freezed\.dart$',
).hasMatch(path);

void main(List<String> arguments) {
  try {
    _run(arguments);
  } on Object catch (error) {
    stderr.writeln('Coverage report failed: $error');
    exitCode = 1;
  }
}

void _run(List<String> arguments) {
  final unknown = arguments.where(
    (argument) =>
        argument.startsWith('--') &&
        argument != '--check' &&
        !argument.startsWith('--json='),
  );
  final paths = arguments.where((argument) => !argument.startsWith('--'));
  if (unknown.isNotEmpty || paths.length > 1) {
    throw const FormatException(
      'Usage: dart run scripts/coverage_report.dart '
      '[coverage/lcov.info] [--check] [--json=path]',
    );
  }
  final report = CoverageReport.parse(
    File(paths.isEmpty ? 'coverage/lcov.info' : paths.single)
        .readAsStringSync(),
  );
  if (report.files.isEmpty || report.totalsFor('lib/').found == 0) {
    throw const FormatException('No executable lib coverage records found');
  }
  final inventory =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => normalizeSourcePath(file.path))
          .where((path) => !isGenerated(path))
          .toList()
        ..sort();
  final missing = inventory.where((path) => !report.files.containsKey(path));
  final modules = inventory.map((path) => path.split('/')[1]).toSet().toList()
    ..sort();
  final totals = <String, CoverageTotals>{
    for (final module in modules)
      module: report.totalsFor(
        module.endsWith('.dart') ? 'lib/$module' : 'lib/$module/',
      ),
  };
  stdout.writeln('Executable lines in LCOV; generated code excluded.');
  for (final entry in totals.entries) {
    final value = entry.value;
    stdout.writeln(
      '${entry.key.padRight(24)} '
      '${value.hit.toString().padLeft(5)}/${value.found.toString().padRight(5)} '
      '${value.percent.toStringAsFixed(1)}%',
    );
  }
  final total = report.totalsFor('lib/');
  stdout.writeln(
    'TOTAL: ${total.hit}/${total.found} '
    '(${total.percent.toStringAsFixed(1)}%)',
  );
  stdout.writeln(
    'LCOV files: ${inventory.length - missing.length}/${inventory.length}; '
    'missing files have unknown executable-line coverage, not 100%.',
  );
  for (final file in missing) {
    stdout.writeln('  Missing LCOV: $file');
  }
  for (final argument in arguments.where((arg) => arg.startsWith('--json='))) {
    final output = File(argument.substring('--json='.length));
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'generatedCodeExcluded': true,
        'total': total.toJson(),
        'modules': {
          for (final entry in totals.entries) entry.key: entry.value.toJson(),
        },
        'sourceFiles': inventory.length,
        'missingLcovFiles': missing.toList(),
      }),
    );
  }
  if (!arguments.contains('--check')) return;
  final config = jsonDecode(
    File('scripts/coverage_thresholds.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final thresholds = <String, double>{};
  for (final entry in config.entries) {
    final value = entry.value;
    if (!entry.key.startsWith('lib/') ||
        !entry.key.endsWith('/') ||
        value is! num ||
        !value.isFinite ||
        value < 0 ||
        value > 100) {
      throw FormatException('Invalid coverage threshold: ${entry.key}');
    }
    thresholds[entry.key] = value.toDouble();
  }
  if (thresholds.isEmpty) {
    throw const FormatException('Coverage thresholds must not be empty');
  }
  final failures = report.check(thresholds, inventory);
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  if (failures.isNotEmpty) {
    exitCode = 1;
  } else {
    stdout.writeln('Critical coverage gates passed.');
  }
}
