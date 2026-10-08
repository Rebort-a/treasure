import 'package:flutter_test/flutter_test.dart';

import '../../scripts/benchmark.dart';

void main() {
  test('基准夹具可重复，实际执行生成、结算、解帧与投影', () {
    for (final benchmark in benchmarkCases()) {
      final first = benchmark.run();
      expect(benchmark.run(), first, reason: benchmark.name);
      expect(first, greaterThan(0), reason: benchmark.name);
    }
  });

  test('基准报告保留样本、单位与校验和', () {
    final benchmark = BenchmarkCase('fixture', 2, () => 7);
    final result = benchmark.measure(samples: 3);
    expect(result['checksum'], 7);
    expect(result['iterationsPerSample'], 2);
    expect(result['samplesMicrosecondsPerBatch'], hasLength(3));
    expect(result['medianMicrosecondsPerBatch'], greaterThanOrEqualTo(0));
    expect(() => benchmark.measure(samples: 0), throwsArgumentError);
    expect(
      () => BenchmarkCase('empty', 0, () => 7).measure(),
      throwsArgumentError,
    );
  });
}
