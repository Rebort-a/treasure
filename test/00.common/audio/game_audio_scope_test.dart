import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/sound_manager.dart';
import 'package:treasure/00.common/sound/audio_preferences.dart';
import 'package:treasure/00.common/sound/sound_service.dart';
import 'package:treasure/00.common/widget/component/game_audio_scope.dart';

import '../../support/noop_json_store.dart';

class _Events with SoundEmitter {}

class _Player implements SoundPlayer<Sound> {
  final sounds = <Sound>[];
  int stops = 0;
  int disposals = 0;

  @override
  Future<void> preload() async {}
  @override
  Future<void> play(Sound sound) async => sounds.add(sound);
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

Widget _game(_Events source, _Player player, AudioPreferences preferences) =>
    GameAudioScope(
      source: source,
      player: player,
      project: 'audio_test',
      preferences: preferences,
      child: const Scaffold(body: SizedBox.expand()),
    );

void main() {
  testWidgets('静音与前后台切换只影响音频，不积压事件，退出释放一次', (tester) async {
    final source = _Events();
    final player = _Player();
    final preferences = AudioPreferences(store: NoopJsonStore());
    await tester.pumpWidget(
      MaterialApp(home: _game(source, player, preferences)),
    );
    await tester.pump();
    source.emitSound(Sound.move);
    expect(player.sounds, [Sound.move]);
    preferences.setSoundEnabled(false);
    await tester.pump();
    source.emitSound(Sound.win);
    expect(player.sounds, [Sound.move]);
    expect(player.stops, greaterThan(0));
    preferences.setSoundEnabled(true);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    source.emitSound(Sound.hit);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player.sounds, [Sound.move]);
    source.emitSound(Sound.pickup);
    expect(player.sounds.last, Sound.pickup);
    await tester.pumpWidget(const SizedBox());
    source.emitSound(Sound.shoot);
    await tester.pump();
    expect(player.disposals, 1);
    expect(player.sounds, [Sound.move, Sound.pickup]);
    source.disposeAudioEvents();
    await preferences.dispose();
  });

  testWidgets('透明弹窗保留结算音，不透明页面覆盖后静音，返回不补播', (tester) async {
    final source = _Events();
    final player = _Player();
    final navigator = GlobalKey<NavigatorState>();
    final preferences = AudioPreferences(store: NoopJsonStore());
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: _game(source, player, preferences),
      ),
    );
    await tester.pump();
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(content: Text('Result')),
    );
    await tester.pumpAndSettle();
    source.emitSound(Sound.win);
    expect(player.sounds, [Sound.win]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    source.emitSound(Sound.shoot);
    expect(player.sounds, [Sound.win]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(player.sounds, [Sound.win]);
    source.emitSound(Sound.capture);
    expect(player.sounds.last, Sound.capture);
    await tester.pumpWidget(const SizedBox());
    source.disposeAudioEvents();
    await preferences.dispose();
  });

  testWidgets('切换 Manager 后旧事件源不再播放，旧播放器只释放一次', (tester) async {
    final first = _Events();
    final next = _Events();
    final oldPlayer = _Player();
    final player = _Player();
    final preferences = AudioPreferences(store: NoopJsonStore());
    await tester.pumpWidget(
      MaterialApp(home: _game(first, oldPlayer, preferences)),
    );
    await tester.pump();
    first.emitSound(Sound.tap);
    await tester.pumpWidget(
      MaterialApp(home: _game(next, player, preferences)),
    );
    await tester.pump();
    first.emitSound(Sound.hit);
    next.emitSound(Sound.success);
    expect(oldPlayer.sounds, [Sound.tap]);
    expect(oldPlayer.disposals, 1);
    expect(player.sounds, [Sound.success]);
    await tester.pumpWidget(const SizedBox());
    first.disposeAudioEvents();
    next.disposeAudioEvents();
    await preferences.dispose();
  });
}
