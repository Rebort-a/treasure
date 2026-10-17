import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// 生成原创的短音效，不依赖外部素材或音频编码器。
const _rate = 22050;

/// 默认音色保持原样，新提示通过独立音色与包络建立辨识度。
enum _Timbre { classic, wood, bubble, bell }

typedef _Note = ({
  double start,
  double duration,
  double frequency,
  double end,
  double gain,
  double noise,
  _Timbre timbre,
});

_Note _note(
  double frequency, {
  double start = 0,
  double duration = .15,
  double? end,
  double gain = .45,
  double noise = 0,
  _Timbre timbre = _Timbre.classic,
}) => (
  start: start,
  duration: duration,
  frequency: frequency,
  end: end ?? frequency,
  gain: gain,
  noise: noise,
  timbre: timbre,
);

void main(List<String> arguments) {
  final common = arguments.contains('--common');
  final output = Directory.fromUri(
    Platform.script.resolve(
      common ? '../assets/audio/common/' : '../assets/audio/match_three/',
    ),
  )..createSync(recursive: true);
  final sounds = <String, List<_Note>>{
    'select': [_note(880, duration: .055, end: 1100, gain: .28)],
    'swap': [_note(420, duration: .10, end: 760, gain: .3)],
    'invalid': [
      _note(330, duration: .10),
      _note(247, start: .09, duration: .14),
    ],
    for (var i = 0; i < 4; i++)
      'clear${i + 1}': [
        _note(523.25 * math.pow(1.1892, i), duration: .16),
        _note(
          783.99 * math.pow(1.1892, i),
          start: .045,
          duration: .17,
          gain: .25,
        ),
      ],
    'line': [
      _note(260, end: 1800, duration: .22, noise: .22),
      _note(1047, start: .10, duration: .19, gain: .22),
    ],
    'bomb': [
      _note(150, end: 42, duration: .34, noise: .55, gain: .6),
      _note(70, duration: .25, gain: .3),
    ],
    'rainbow': [
      for (var i = 0; i < 5; i++)
        _note(
          [523.25, 659.25, 783.99, 1046.5, 1318.5][i],
          start: i * .055,
          duration: .22,
          gain: .32,
        ),
    ],
    'ice': [
      _note(2400, end: 1350, duration: .12, noise: .65, gain: .25),
      _note(3300, start: .04, duration: .09, noise: .4, gain: .15),
    ],
    'fall': [_note(620, end: 280, duration: .08, gain: .16)],
    // 开局与重开专用：两下同音木质敲击，停顿后落到同时发声的和弦。
    'entrance': [
      _note(293.66, duration: .09, gain: .32, timbre: _Timbre.wood),
      _note(293.66, start: .10, duration: .09, gain: .28, timbre: _Timbre.wood),
      for (final frequency in [369.99, 440.0, 587.33])
        _note(
          frequency,
          start: .23,
          duration: .27,
          gain: .19,
          timbre: _Timbre.wood,
        ),
    ],
    // 整盘补齐使用短促的双气泡下滑，不再与开局或奖励共用上行琶音。
    'appear': [
      _note(760, end: 300, duration: .10, gain: .32, timbre: _Timbre.bubble),
      _note(
        530,
        end: 210,
        start: .105,
        duration: .15,
        gain: .35,
        timbre: _Timbre.bubble,
      ),
    ],
    'transform': [
      _note(660, end: 1320, duration: .20, gain: .3),
      _note(1568, start: .12, duration: .18, gain: .22),
    ],
    // 奖励提示使用高频金属双铃，短于胜利旋律，适合逐步转换时重复触发。
    'bonus': [
      _note(1318.51, duration: .12, gain: .25, timbre: _Timbre.bell),
      _note(987.77, start: .14, duration: .25, gain: .30, timbre: _Timbre.bell),
    ],
    'won': [
      for (var i = 0; i < 6; i++)
        _note(
          [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5][i],
          start: i * .12,
          duration: i == 5 ? .42 : .23,
          gain: .38,
        ),
    ],
    'lost': [
      for (var i = 0; i < 3; i++)
        _note(
          [392.0, 329.63, 261.63][i],
          start: i * .16,
          duration: .30,
          gain: .32,
        ),
    ],
  };
  if (common) {
    sounds
      ..clear()
      ..addAll({
        'tap': [_note(960, duration: .05, gain: .22)],
        'move': [_note(460, end: 320, duration: .07, noise: .12, gain: .3)],
        'flip': [_note(560, end: 880, duration: .09, gain: .28)],
        'capture': [
          _note(220, end: 95, duration: .15, noise: .3),
          _note(660, start: .04, duration: .11, gain: .22),
        ],
        'success': [
          _note(659.25, duration: .13, gain: .28),
          _note(987.77, start: .06, duration: .16, gain: .25),
        ],
        'error': [
          _note(293.66, duration: .08, gain: .25),
          _note(220, start: .07, duration: .12, gain: .25),
        ],
        'shoot': [_note(1500, end: 320, duration: .075, gain: .23)],
        'hit': [_note(180, end: 65, duration: .15, noise: .55, gain: .3)],
        'pickup': [
          _note(783.99, duration: .11, gain: .25),
          _note(1174.66, start: .065, duration: .17, gain: .25),
        ],
        'jump': [_note(260, end: 740, duration: .15, gain: .28)],
        'cast': [
          _note(440, end: 1100, duration: .22, gain: .28),
          _note(1760, start: .09, duration: .18, gain: .18),
        ],
        'explosion': [_note(130, end: 38, duration: .29, noise: .6, gain: .42)],
        'win': [
          for (var i = 0; i < 4; i++)
            _note(
              [523.25, 659.25, 783.99, 1046.5][i],
              start: i * .115,
              duration: i == 3 ? .34 : .21,
              gain: .32,
            ),
        ],
        'lose': [
          for (var i = 0; i < 3; i++)
            _note(
              [349.23, 293.66, 220.0][i],
              start: i * .14,
              duration: .25,
              gain: .28,
            ),
        ],
      });
  }
  for (final entry in sounds.entries) {
    final seconds = entry.value
        .map((note) => note.start + note.duration)
        .reduce(math.max);
    final samples = Float64List((seconds * _rate).ceil() + 1);
    final random = math.Random(18);
    for (final note in entry.value) {
      final offset = (note.start * _rate).round();
      final length = (note.duration * _rate).floor();
      final (attack, decay, release) = switch (note.timbre) {
        _Timbre.classic => (.006, 4.0, .02),
        _Timbre.wood => (.002, 5.0, .02),
        _Timbre.bubble => (.004, 3.0, .02),
        _Timbre.bell => (.003, 2.5, .04),
      };
      for (var i = 0; i < length; i++) {
        final t = i / _rate;
        final progress = t / note.duration;
        // 短起音和缓慢衰减同时防止爆音与结尾截断。
        final envelope =
            math.min(1.0, t / attack) *
            math.exp(-decay * progress) *
            math.min(1.0, (note.duration - t) / release);
        final phase =
            2 *
            math.pi *
            (note.frequency * t +
                (note.end - note.frequency) * t * t / (2 * note.duration));
        final tone = switch (note.timbre) {
          _Timbre.classic => math.sin(phase) + .18 * math.sin(phase * 2),
          // 高次分音迅速衰减，保留短而温暖的木质敲击感。
          _Timbre.wood =>
            math.sin(phase) +
                .35 * math.sin(phase * 3) * math.exp(-10 * progress) +
                .12 * math.sin(phase * 4.2) * math.exp(-16 * progress),
          _Timbre.bubble => math.sin(phase) + .07 * math.sin(phase * 2),
          // 非整数倍分音与轻微拍频使铃声区别于默认的电子提示音。
          _Timbre.bell =>
            (math.sin(phase) +
                    .38 * math.sin(phase * 2.756) * math.exp(-3 * progress) +
                    .18 * math.sin(phase * 4.07) * math.exp(-6 * progress)) *
                (.88 + .12 * math.cos(2 * math.pi * 12 * t)),
        };
        final noise = random.nextDouble() * 2 - 1;
        samples[offset + i] +=
            (tone * (1 - note.noise) + noise * note.noise) *
            note.gain *
            envelope;
      }
    }
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
        (samples[i].clamp(-.95, .95) * 32767).round(),
        Endian.little,
      );
    }
    File('${output.path}/${entry.key}.wav')
        .writeAsBytesSync(bytes.buffer.asUint8List());
  }
  stdout.writeln('Generated ${sounds.length} sounds in ${output.path}');
}
