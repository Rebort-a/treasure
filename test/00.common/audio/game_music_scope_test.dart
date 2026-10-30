import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/sound_manager.dart';
import 'package:treasure/00.common/sound/audio_preferences.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/00.common/sound/music_service.dart';
import 'package:treasure/00.common/sound/sound_service.dart';
import 'package:treasure/00.common/widget/component/game_audio_scope.dart';

class _Events with SoundEmitter {}

class _Effects implements SoundPlayer<Sound> {
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(Sound sound) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Music implements MusicPlayer {
  bool playing = false;
  int disposals = 0;
  @override
  Future<void> preload() async {}
  @override
  Future<void> resume() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {
    playing = false;
    disposals++;
  }
}

class _Store implements JsonStore {
  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async => {};
  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {}
}

void main() {
  testWidgets('运行状态、页面覆盖、前后台与全局音乐设置共同控制播放，退出释放资源', (tester) async {
    final source = _Events();
    final music = _Music();
    final running = ValueNotifier(false);
    final navigator = GlobalKey<NavigatorState>();
    final preferences = AudioPreferences(store: _Store());
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: GameAudioScope(
          source: source,
          project: 'music_scope_test',
          player: _Effects(),
          musicPlayer: music,
          preferences: preferences,
          musicAsset: 'audio/music/tank.wav',
          musicState: running,
          isMusicPlaying: () => running.value,
          child: const Scaffold(),
        ),
      ),
    );
    await tester.pump();
    expect(music.playing, isFalse);
    running.value = true;
    await tester.pump();
    expect(music.playing, isTrue);
    preferences.setSoundEnabled(false);
    await tester.pump();
    expect(music.playing, isTrue);
    preferences.setMusicEnabled(false);
    await tester.pump();
    expect(music.playing, isFalse);
    preferences.setMusicEnabled(true);
    await tester.pump();
    expect(music.playing, isTrue);
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    expect(music.playing, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(music.playing, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(music.playing, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(music.playing, isTrue);
    running.value = false;
    await tester.pump();
    expect(music.playing, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    running.value = true;
    expect(music.disposals, 1);
    expect(music.playing, isFalse);
    running.dispose();
    source.disposeAudioEvents();
    await preferences.dispose();
  });
}
