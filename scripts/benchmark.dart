import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:treasure/00.common/network/protocol/tcp_frame_codec.dart';
import 'package:treasure/13.minecraft/base/matrix.dart';
import 'package:treasure/13.minecraft/base/vector.dart';
import 'package:treasure/18.match_three/base/match_board.dart';

/// 固定输入的 CPU 微基准，不把内核耗时当作界面帧率或跨设备网络性能。
class BenchmarkCase {
  final String name;
  final int iterations;
  final int Function() run;

  const BenchmarkCase(this.name, this.iterations, this.run);

  Map<String, Object> measure({int samples = 7}) {
    if (iterations < 1 || samples < 1) {
      throw ArgumentError('Iterations and samples must be positive');
    }
    final checksum = run();
    for (var warmup = 0; warmup < 2; warmup++) {
      if (run() != checksum) throw StateError('$name is not deterministic');
    }
    final times = <double>[];
    for (var sample = 0; sample < samples; sample++) {
      final watch = Stopwatch()..start();
      for (var iteration = 0; iteration < iterations; iteration++) {
        if (run() != checksum) throw StateError('$name checksum changed');
      }
      watch.stop();
      times.add(watch.elapsedMicroseconds / iterations);
    }
    final sorted = times.toList()..sort();
    return {
      'name': name,
      'iterationsPerSample': iterations,
      'samplesMicrosecondsPerBatch': times,
      'medianMicrosecondsPerBatch': sorted[sorted.length ~/ 2],
      'p90MicrosecondsPerBatch': sorted[(sorted.length * 0.9).ceil() - 1],
      'checksum': checksum,
    };
  }
}

List<BenchmarkCase> benchmarkCases() {
  final snapshots = [
    for (var seed = 1; seed <= 32; seed++)
      MatchBoard.random(seed: seed).toJson(),
  ];
  final payload = Uint8List.fromList(
    List.generate(64 * 1024, (index) => index % 256),
  );
  final framed = TcpFrameCodec.encode(payload);
  final projection = ColMat4.perspectiveLH(math.pi / 3, 16 / 9, 0.1, 256);
  final vertices = [
    for (var index = 0; index < 4096; index++)
      Vector4((index % 16).toDouble(), (index % 31).toDouble(), 32, 1),
  ];
  return [
    BenchmarkCase('match_three.generate_32', 3, () {
      var checksum = 0;
      for (var seed = 1; seed <= 32; seed++) {
        final board = MatchBoard.random(seed: seed);
        checksum += board.initialMoves + board.pieces.first!.kind;
      }
      return checksum;
    }),
    BenchmarkCase('match_three.snapshot_and_swap_32', 3, () {
      var checksum = 0;
      for (final snapshot in snapshots) {
        final board = MatchBoard.fromJson(snapshot);
        final move = board.legalMoves.first;
        final result = board.playSwap(move.$1, move.$2)!;
        checksum += result.scoreGained + result.frames.length;
      }
      return checksum;
    }),
    BenchmarkCase('network.decode_fragmented_64k', 10, () {
      final decoder = TcpFrameDecoder();
      final frames = <Uint8List>[];
      for (var offset = 0; offset < framed.length; offset += 113) {
        frames.addAll(
          decoder.add(
            Uint8List.sublistView(
              framed,
              offset,
              math.min(offset + 113, framed.length),
            ),
          ),
        );
      }
      if (frames.length != 1 || frames.single.length != payload.length) {
        throw StateError('TCP frame reconstruction failed');
      }
      return frames.single.length + frames.single.last;
    }),
    BenchmarkCase('voxel.project_4096_vertices', 20, () {
      var checksum = 0.0;
      for (final vertex in vertices) {
        final projected = projection.multiplyVector4(vertex);
        checksum += projected.x / projected.w + projected.y / projected.w;
      }
      return checksum.round();
    }),
  ];
}

void main(List<String> arguments) {
  try {
    if (arguments.any((argument) => !argument.startsWith('--json='))) {
      throw const FormatException(
        'Usage: dart run scripts/benchmark.dart [--json=path]',
      );
    }
    final results = [
      for (final benchmark in benchmarkCases()) benchmark.measure(),
    ];
    final data = {
      'schemaVersion': 1,
      'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'operatingSystem': Platform.operatingSystem,
      'dartRuntime': Platform.version,
      'scope': 'CPU microbenchmarks; not UI FPS or device network latency',
      'results': results,
    };
    for (final result in results) {
      stdout.writeln(
        '${result['name']}: median '
        '${(result['medianMicrosecondsPerBatch'] as double).toStringAsFixed(1)} '
        'us/batch',
      );
    }
    for (final argument in arguments) {
      final file = File(argument.substring('--json='.length));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    }
  } on Object catch (error) {
    stderr.writeln('Benchmark failed: $error');
    exitCode = 1;
  }
}
