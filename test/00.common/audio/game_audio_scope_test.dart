import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/game_sound.dart';
import 'package:treasure/00.common/service/sound_service.dart';
import 'package:treasure/00.common/widget/component/game_audio_scope.dart';

class _Events with GameSoundEmitter {}

class _Player implements SoundPlayer<GameSound> {
  final sounds = <GameSound>[];
  int stops = 0;
  int disposals = 0;

  @override
  Future<void> preload() async {}
  @override
  Future<void> play(GameSound sound) async => sounds.add(sound);
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

Widget _game(_Events source, _Player player) => GameAudioScope(
  source: source,
  player: player,
  project: 'audio_test',
  child: Scaffold(
    appBar: AppBar(actions: const [GameSoundButton()]),
    body: const SizedBox.expand(),
  ),
);

void main() {
  test('通用音效事件均有可播放的短 PCM 资源', () {
    for (final sound in GameSound.values) {
      if (sound == GameSound.reset) continue;
      final bytes = File('assets/${sound.asset}').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
      expect(data.getUint16(20, Endian.little), 1);
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint16(34, Endian.little), 16);
      expect(data.getUint32(40, Endian.little), bytes.length - 44);
      expect(bytes.length, inInclusiveRange(1000, 40000));
    }
  });

  testWidgets('静音与前后台切换只影响音频，不积压事件，退出释放一次', (tester) async {
    final source = _Events();
    final player = _Player();
    await tester.pumpWidget(MaterialApp(home: _game(source, player)));
    await tester.pump();
    source.emitSound(GameSound.move);
    expect(player.sounds, [GameSound.move]);
    await tester.tap(find.byType(GameSoundButton));
    await tester.pump();
    source.emitSound(GameSound.win);
    expect(player.sounds, [GameSound.move]);
    expect(player.stops, greaterThan(0));
    await tester.tap(find.byType(GameSoundButton));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    source.emitSound(GameSound.hit);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player.sounds, [GameSound.move]);
    source.emitSound(GameSound.pickup);
    expect(player.sounds.last, GameSound.pickup);
    await tester.pumpWidget(const SizedBox());
    source.emitSound(GameSound.shoot);
    await tester.pump();
    expect(player.disposals, 1);
    expect(player.sounds, [GameSound.move, GameSound.pickup]);
    source.disposeAudioEvents();
  });

  testWidgets('透明弹窗保留结算音，不透明页面覆盖后静音，返回不补播', (tester) async {
    final source = _Events();
    final player = _Player();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: _game(source, player)),
    );
    await tester.pump();
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(content: Text('Result')),
    );
    await tester.pumpAndSettle();
    source.emitSound(GameSound.win);
    expect(player.sounds, [GameSound.win]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    source.emitSound(GameSound.shoot);
    expect(player.sounds, [GameSound.win]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(player.sounds, [GameSound.win]);
    source.emitSound(GameSound.capture);
    expect(player.sounds.last, GameSound.capture);
    await tester.pumpWidget(const SizedBox());
    source.disposeAudioEvents();
  });

  testWidgets('切换 Manager 后旧事件源不再播放，旧播放器只释放一次', (tester) async {
    final first = _Events();
    final next = _Events();
    final oldPlayer = _Player();
    final player = _Player();
    await tester.pumpWidget(MaterialApp(home: _game(first, oldPlayer)));
    await tester.pump();
    first.emitSound(GameSound.tap);
    await tester.pumpWidget(MaterialApp(home: _game(next, player)));
    await tester.pump();
    first.emitSound(GameSound.hit);
    next.emitSound(GameSound.success);
    expect(oldPlayer.sounds, [GameSound.tap]);
    expect(oldPlayer.disposals, 1);
    expect(player.sounds, [GameSound.success]);
    await tester.pumpWidget(const SizedBox());
    first.disposeAudioEvents();
    next.disposeAudioEvents();
  });
}
