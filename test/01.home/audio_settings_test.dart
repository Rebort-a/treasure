import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/sound_manager.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/sound/audio_preferences.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/00.common/sound/music_service.dart';
import 'package:treasure/00.common/sound/sound_service.dart';
import 'package:treasure/01.home/middle/home_state.dart';
import 'package:treasure/01.home/upper/pages/settings_page.dart';
import 'package:treasure/18.match_three/middle/combo_praise.dart';
import 'package:treasure/18.match_three/middle/match_audio.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/middle/match_sound.dart';

class _Events with SoundEmitter {}

class _Player<T> implements SoundPlayer<T> {
  final played = <T>[];
  int stops = 0;
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(T sound) async => played.add(sound);
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async {}
}

class _MatchPlayer extends _Player<MatchSound> implements MatchSoundPlayer {}

class _Music implements MusicPlayer {
  bool playing = false;
  double? volume;
  @override
  Future<void> preload() async {}
  @override
  Future<void> resume() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> setVolume(double value) async => volume = value;
  @override
  Future<void> dispose() async {}
}

class _Store implements JsonStore {
  final data = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async => Map.of(data['$project/$name'] ?? {});
  @override
  Future<void> write(
    String name,
    Map<String, dynamic> value, {
    String project = '00.common',
  }) async => data['$project/$name'] = Map.of(value);
}

void main() {
  testWidgets('设置页独立控制跨游戏音效、语音、音乐及震动，退出后仍保留', (tester) async {
    final store = _Store();
    final preferences = AudioPreferences(store: store);
    final events = _Events();
    final sound = _Player<Sound>();
    final effects = SoundController<Sound>(
      events: events.audioEvents,
      currentSound: () => events.audioEvents.value?.sound,
      player: sound,
      project: '11.spaceship',
      preferences: preferences,
    );
    final match = MatchManager(generate: false);
    final matchPlayer = _MatchPlayer();
    final voice = _Player<ComboPraise>();
    final bonus = _Player<MatchSound>();
    final matchAudio = MatchAudioController(
      manager: match,
      player: matchPlayer,
      praisePlayer: voice,
      bonusPlayer: bonus,
      preferences: preferences,
    );
    final musicPlayers = [_Music(), _Music()];
    final music = [
      for (var i = 0; i < 2; i++)
        BackgroundMusicController(
          project: i == 0 ? '11.spaceship' : '17.tank',
          player: musicPlayers[i],
          preferences: preferences,
        )..setPlaying(true),
    ];
    await Future.wait([
      effects.ready,
      matchAudio.ready,
      for (final controller in music) controller.ready,
    ]);
    final state = HomeState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSettingsPage(state: state, audioPreferences: preferences),
        ),
      ),
    );
    await tester.pumpAndSettle();
    events.emitSound(Sound.shoot);
    match.sound.value = const MatchSoundEvent(MatchSound.swap);
    match.praiseVoice.value = const ComboPraiseEvent(ComboPraise.amazing);
    expect(sound.played, [Sound.shoot]);
    expect(matchPlayer.played, [MatchSound.swap]);
    expect(voice.played, [ComboPraise.amazing]);
    match.bonusTime.value = true;
    expect(bonus.played, [MatchSound.bonus]);
    match.bonusTime.value = false;
    final soundSwitch = find.widgetWithText(SwitchListTile, S.gameSoundEffects);
    await tester.ensureVisible(soundSwitch);
    await tester.tap(soundSwitch);
    await tester.pump();
    events.emitSound(Sound.explosion);
    match.sound.value = const MatchSoundEvent(MatchSound.bomb);
    match.praiseVoice.value = const ComboPraiseEvent(ComboPraise.unbelievable);
    expect(sound.played, hasLength(1));
    expect(matchPlayer.played, hasLength(1));
    expect(voice.played, hasLength(2));
    match.sound.value = const MatchSoundEvent(MatchSound.reset);
    match.bonusTime.value = false;
    match.bonusTime.value = true;
    expect(bonus.played, hasLength(2));
    expect(sound.stops, greaterThan(0));
    expect(musicPlayers.every((player) => player.playing), isTrue);

    final voiceSwitch = find.widgetWithText(
      SwitchListTile,
      S.voiceAnnouncements,
    );
    await tester.ensureVisible(voiceSwitch);
    await tester.tap(voiceSwitch);
    await tester.pump();
    match.bonusTime.value = false;
    match.praiseVoice.value = const ComboPraiseEvent(ComboPraise.good);
    match.bonusTime.value = true;
    expect(voice.played, hasLength(2));
    expect(bonus.played, hasLength(2));
    expect(voice.stops, greaterThan(0));
    expect(bonus.stops, greaterThan(0));

    await tester.ensureVisible(soundSwitch);
    await tester.tap(soundSwitch);
    await tester.pump();
    events.emitSound(Sound.hit);
    match.sound.value = const MatchSoundEvent(MatchSound.line);
    expect(sound.played, [Sound.shoot, Sound.hit]);
    expect(matchPlayer.played, [MatchSound.swap, MatchSound.line]);
    match.bonusTime.value = false;
    match.praiseVoice.value = const ComboPraiseEvent(ComboPraise.great);
    expect(voice.played, hasLength(2));
    await tester.tap(soundSwitch);
    await tester.pump();
    await tester.ensureVisible(voiceSwitch);
    await tester.tap(voiceSwitch);
    await tester.pump();
    expect(voice.played, hasLength(2));
    expect(bonus.played, hasLength(2));
    await tester.tap(voiceSwitch);
    await tester.pump();

    expect(musicPlayers.every((player) => player.playing), isTrue);
    await tester.ensureVisible(find.byType(Slider));
    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pumpAndSettle();
    final volume = preferences.musicVolume.value;
    expect(volume, isNot(.32));
    expect(musicPlayers.every((player) => player.volume == volume), isTrue);
    expect(preferences.soundEnabled.value, isFalse);
    expect(preferences.voiceEnabled.value, isFalse);
    final musicSwitch = find.widgetWithText(SwitchListTile, S.backgroundMusic);
    await tester.ensureVisible(musicSwitch);
    await tester.tap(musicSwitch);
    await tester.pump();
    expect(musicPlayers.every((player) => !player.playing), isTrue);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    final vibrationSwitch = find.widgetWithText(SwitchListTile, S.vibration);
    await tester.ensureVisible(vibrationSwitch);
    await tester.tap(vibrationSwitch);
    await tester.pump();
    expect(preferences.vibrationEnabled.value, isFalse);
    await tester.pumpWidget(const SizedBox());
    await Future.wait([
      effects.dispose(),
      matchAudio.dispose(),
      for (final controller in music) controller.dispose(),
    ]);
    final nextPlayer = _Player<Sound>();
    final next = SoundController<Sound>(
      events: events.audioEvents,
      currentSound: () => events.audioEvents.value?.sound,
      player: nextPlayer,
      project: '05.gobang',
      preferences: preferences,
    );
    await next.ready;
    events.emitSound(Sound.move);
    expect(nextPlayer.played, isEmpty);
    await next.dispose();
    expect(store.data['00.common/audio'], {'enabled': false});
    expect(store.data['00.common/voice'], {'enabled': false});
    expect(store.data['00.common/music'], {'enabled': false, 'volume': volume});
    expect(store.data['00.common/vibration'], {'enabled': false});
    events.disposeAudioEvents();
    match.dispose();
    state.dispose();
    await preferences.dispose();
  });
}
