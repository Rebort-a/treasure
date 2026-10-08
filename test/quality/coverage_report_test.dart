import 'package:flutter_test/flutter_test.dart';

import '../../scripts/coverage_report.dart';

void main() {
  test('合并重复文件和行，兼容 Windows 路径及生成代码排除', () {
    final report = CoverageReport.parse(r'''
SF:C:\workspace\treasure\lib\18.match_three\base\board.dart
DA:1,0
DA:2,1
end_of_record
SF:lib/18.match_three/base/board.dart
DA:1,2
DA:3,0,checksum
end_of_record
SF:lib/00.common/l10n/app_localizations_en.dart
DA:1,99
end_of_record
SF:test/example_test.dart
DA:1,99
end_of_record
''');
    expect(report.files.length, 1);
    final totals = report.totalsFor('lib/');
    expect(totals.found, 3);
    expect(totals.hit, 2);
    expect(totals.percent, closeTo(200 / 3, 0.001));
  });

  test('低于门槛、关键文件缺失及空记录均不能通过', () {
    final report = CoverageReport.parse('''
SF:lib/core/a.dart
DA:1,1
DA:2,0
end_of_record
''');
    expect(
      report.check({'lib/core/': 80}, ['lib/core/a.dart', 'lib/core/b.dart']),
      hasLength(2),
    );
    expect(report.check({'lib/absent/': 0}, []), hasLength(1));
  });

  test('正好达到门槛时通过，生成文件不构成缺失', () {
    final report = CoverageReport.parse('''
SF:lib/core/a.dart
DA:1,1
DA:2,0
end_of_record
''');
    expect(
      report.check({'lib/core/': 50}, ['lib/core/a.dart', 'lib/core/a.g.dart']),
      isEmpty,
    );
  });

  test('非法行号或命中次数不能生成看似有效的报告', () {
    for (final data in ['DA:0,1', 'DA:1,-1', 'DA:x,1', 'DA:1']) {
      expect(
        () => CoverageReport.parse('SF:lib/core/a.dart\n$data\n'),
        throwsFormatException,
      );
    }
  });
}
