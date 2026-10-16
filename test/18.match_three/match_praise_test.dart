import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/00.common/service/sound_service.dart';
import 'package:treasure/18.match_three/middle/combo_praise.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_audio.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/middle/match_sound.dart';

class _Voice implements SoundPlayer<ComboPraise> {
  final played = <ComboPraise>[];
  int stops = 0;
  int disposals = 0;
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(ComboPraise sound) async => played.add(sound);
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

class _Effects implements MatchSoundPlayer {
  final played = <MatchSound>[];
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(MatchSound sound) async => played.add(sound);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
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

void _praise(MatchManager manager, ComboPraise praise) =>
    manager.praiseVoice.value = ComboPraiseEvent(praise);

Map<String, dynamic> _board() {
  final data = MatchBoard.random(seed: 7).toJson();
  const overrides = {0: 0, 1: 0, 2: 1, 3: 0, 10: 0};
  data['pieces'] = [
    for (var i = 0; i < MatchBoard.cells; i++)
      [i + 1, overrides[i] ?? (i ~/ 8 * 2 + i % 8) % 6, 0],
  ];
  data['nextId'] = 65;
  data['ice'] = List.filled(64, 0);
  data['targets'] = {'4': 1000, '5': 1000};
  data['collected'] = List.filled(6, 0);
  return data;
}

void main() {
  test('五档赞美均绑定独立、非静音的英文离线语音资源', () {
    expect(ComboPraise.values.map((praise) => praise.label), [
      'Good',
      'Great',
      'Excellent',
      'Amazing',
      'Unbelievable',
    ]);
    for (final praise in ComboPraise.values) {
      final bytes = File('assets/${praise.asset}').readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
      expect(bytes.skip(44).any((byte) => byte != 0), isTrue);
    }
  });

  test('普通播报冷却，高档播报及时响应，消除声不影响语音', () async {
    final manager = MatchManager(generate: false);
    final voice = _Voice();
    final effects = _Effects();
    final audio = MatchAudioController(
      manager: manager,
      player: effects,
      praisePlayer: voice,
      store: _Store(),
    );
    await audio.ready;
    _praise(manager, ComboPraise.good);
    _praise(manager, ComboPraise.good);
    _praise(manager, ComboPraise.unbelievable);
    final stops = voice.stops;
    manager.sound.value = const MatchSoundEvent(MatchSound.bomb);
    expect(voice.played, [ComboPraise.good, ComboPraise.unbelievable]);
    expect(effects.played, [MatchSound.bomb]);
    expect(voice.stops, stops);
    audio.setEnabled(false);
    _praise(manager, ComboPraise.amazing);
    expect(voice.stops, greaterThan(stops));
    expect(voice.played, hasLength(2));
    audio.setEnabled(true);
    audio.setActive(false);
    _praise(manager, ComboPraise.excellent);
    audio.setActive(true);
    expect(voice.played, hasLength(2));
    _praise(manager, ComboPraise.excellent);
    expect(voice.played.last, ComboPraise.excellent);
    manager.sound.value = const MatchSoundEvent(MatchSound.reset);
    expect(voice.stops, greaterThan(stops + 1));
    _praise(manager, ComboPraise.good);
    expect(voice.played.last, ComboPraise.good);
    await audio.dispose();
    await audio.dispose();
    _praise(manager, ComboPraise.great);
    expect(voice.disposals, 1);
    expect(voice.played.last, ComboPraise.good);
    manager.dispose();
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('真实消除只随赞美展示播报一次，刷新与重复快照不补播：$reduceMotion', (tester) async {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(_board())
        ..reduceMotion = reduceMotion;
      final voice = _Voice();
      final audio = MatchAudioController(
        manager: manager,
        player: _Effects(),
        praisePlayer: voice,
        store: _Store(),
      );
      await audio.ready;
      manager.swap(10, 2);
      for (var i = 0; i < 400 && manager.busy.value; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(manager.busy.value, isFalse);
      expect(voice.played, hasLength(1));
      expect(manager.comboPraise.value, voice.played.single.label);
      final state = manager.board!.toJson();
      manager.refreshView();
      manager.loadState(state);
      expect(voice.played, hasLength(1));
      manager.reduceMotion = true;
      manager.restart(seed: 42);
      expect(voice.stops, greaterThan(0));
      await audio.dispose();
      manager.dispose();
    });
  }
}
