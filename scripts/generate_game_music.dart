import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _rate = 22050;

/// 用原创音序生成完整循环，尾音按周期回卷，避免循环接缝截断混响。
class _Sequencer {
  final double beat;
  final Float64List samples;
  final random = math.Random(1117);

  _Sequencer(int bpm)
    : beat = 60 / bpm,
      samples = Float64List((64 * 60 / bpm * _rate).round());

  void tone(
    double start,
    double length,
    int midi,
    double gain, {
    bool bass = false,
    bool pad = false,
  }) {
    final frequency = 440 * math.pow(2, (midi - 69) / 12);
    final duration = length * beat;
    final count = (duration * _rate).round();
    final offset = (start * beat * _rate).round();
    for (var i = 0; i < count; i++) {
      final t = i / _rate;
      final phase = 2 * math.pi * frequency * t;
      final attack = math.min(1.0, t / (pad ? .10 : .008));
      final release = math.min(1.0, (duration - t) / (pad ? .20 : .045));
      final envelope =
          attack *
          release *
          (pad ? .75 : math.exp(-(bass ? 3 : 4) * t / duration));
      final wave = bass
          ? math.sin(phase) + .22 * math.sin(phase * 2)
          : pad
          ? math.sin(phase) + .15 * math.sin(phase * 1.003)
          : math.sin(phase) +
                .25 * math.sin(phase * 2) +
                .08 * math.sin(phase * 3);
      samples[(offset + i) % samples.length] += wave * envelope * gain;
    }
  }

  void drum(double start, String kind, double gain) {
    final duration = kind == 'hat' ? .07 : .22;
    final count = (duration * _rate).round();
    final offset = (start * beat * _rate).round();
    var previousNoise = 0.0;
    for (var i = 0; i < count; i++) {
      final t = i / _rate;
      final noise = random.nextDouble() * 2 - 1;
      final transient = math.min(1.0, t / .002);
      final wave = switch (kind) {
        'kick' =>
          math.sin(
                2 * math.pi * (48 * t + 85 * .025 * (1 - math.exp(-t / .025))),
              ) *
              math.exp(-22 * t),
        'snare' =>
          (noise * .65 + math.sin(2 * math.pi * 185 * t) * .35) *
              math.exp(-24 * t),
        _ => (noise - previousNoise) * math.exp(-70 * t) * .5,
      };
      samples[(offset + i) % samples.length] += wave * gain * transient;
      previousNoise = noise;
    }
  }

  void save(File file) {
    final peak = samples.fold<double>(0, (a, b) => math.max(a, b.abs()));
    final gain = .82 / math.max(peak, .01);
    final bytes = ByteData(44 + samples.length * 2);
    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
    text(8, 'WAVEfmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, _rate, Endian.little);
    bytes.setUint32(28, _rate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(
        44 + i * 2,
        (samples[i] * gain * 32767).round(),
        Endian.little,
      );
    }
    file.writeAsBytesSync(bytes.buffer.asUint8List());
    stdout.writeln(
      '${file.path}: '
      '${(samples.length / _rate).toStringAsFixed(2)} s',
    );
  }
}

void main() {
  final output = Directory.fromUri(
    Platform.script.resolve('../assets/audio/music/'),
  )..createSync(recursive: true);
  final space = _Sequencer(112);
  final tank = _Sequencer(124);
  const spaceRoots = [45, 41, 48, 43];
  const tankRoots = [40, 40, 43, 38, 40, 45, 43, 38];
  const spaceMelody = [0, 7, 12, 15, 12, 7, 10, 7];
  const tankMelody = [0, 0, 7, 10, 7, 5, 3, 7];

  for (var bar = 0; bar < 16; bar++) {
    final start = bar * 4.0;
    final spaceRoot = spaceRoots[(bar ~/ 2) % spaceRoots.length];
    final tankRoot = tankRoots[bar % tankRoots.length];
    for (final interval in [0, 3, 7]) {
      space.tone(start, 4.3, spaceRoot + 12 + interval, .065, pad: true);
    }
    for (var step = 0; step < 8; step++) {
      final at = start + step * .5;
      space.tone(
        at,
        .70,
        spaceRoot + 24 + spaceMelody[(step + (bar.isOdd ? 2 : 0)) % 8],
        .075,
      );
      tank.tone(at, .38, tankRoot + (step.isOdd ? 12 : 0), .18, bass: true);
      space.drum(at + .25, 'hat', .035);
      tank.drum(at, 'hat', step.isEven ? .05 : .035);
      if (bar % 4 >= 2 || step.isEven) {
        tank.tone(
          at,
          .42,
          tankRoot + 24 + tankMelody[(step + bar % 2) % 8],
          .075,
        );
      }
    }
    for (var step = 0; step < 4; step++) {
      space.tone(start + step, .8, spaceRoot, .16, bass: true);
      space.drum(start + step, step.isEven ? 'kick' : 'snare', .16);
      tank.drum(start + step, step.isEven ? 'kick' : 'snare', .23);
    }
    if (bar % 4 == 3) tank.drum(start + 3.5, 'snare', .14);
  }
  space.save(File('${output.path}/spaceship.wav'));
  tank.save(File('${output.path}/tank.wav'));
}
