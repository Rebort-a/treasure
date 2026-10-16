import 'dart:io';
import 'dart:typed_data';

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
  int stops = 0;
  int disposals = 0;
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(MatchSound sound) async => played.add(sound);
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
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

Map<String, dynamic> _board({bool winning = false}) {
  final data = MatchBoard.random(seed: 7).toJson();
  const overrides = {0: 0, 1: 0, 2: 1, 3: 0, 10: 0};
  data['pieces'] = [
    for (var i = 0; i < MatchBoard.cells; i++)
      [i + 1, overrides[i] ?? (i ~/ 8 * 2 + i % 8) % 6, 0],
  ];
  data['nextId'] = 65;
  data['ice'] = List.filled(64, 0);
  data['targets'] = winning ? {'0': 1, '1': 1} : {'4': 1000, '5': 1000};
  data['collected'] = [0, winning ? 1 : 0, 0, 0, 0, 0];
  if (winning) {
    data['movesLeft'] = 3;
    data['moveNumber'] = (data['initialMoves'] as int) - 3;
  }
  return data;
}

void main() {
  test('赞美与奖励播报均绑定完整且非静音的离线 PCM WAV 资源', () {
    for (final asset in [
      for (final praise in ComboPraise.values) praise.asset,
      'audio/match_praise/bonus_time.wav',
    ]) {
      final bytes = File('assets/$asset').readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      expect(bytes.length, greaterThanOrEqualTo(44), reason: asset);
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
      expect(
        header.getUint32(4, Endian.little),
        bytes.length - 8,
        reason: asset,
      );
      var offset = 12;
      var hasFormat = false;
      var hasAudio = false;
      var blockAlign = 0;
      // WAV 可包含 LIST 等元数据块，不能假定音频固定从第 44 字节开始。
      while (offset + 8 <= bytes.length) {
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final size = header.getUint32(offset + 4, Endian.little);
        final start = offset + 8;
        final end = start + size;
        expect(end, lessThanOrEqualTo(bytes.length), reason: '$asset: $id');
        if (id == 'fmt ') {
          expect(size, greaterThanOrEqualTo(16), reason: asset);
          expect(header.getUint16(start, Endian.little), 1, reason: asset);
          final channels = header.getUint16(start + 2, Endian.little);
          final sampleRate = header.getUint32(start + 4, Endian.little);
          final byteRate = header.getUint32(start + 8, Endian.little);
          blockAlign = header.getUint16(start + 12, Endian.little);
          expect(channels, greaterThan(0), reason: asset);
          expect(sampleRate, greaterThan(0), reason: asset);
          expect(
            header.getUint16(start + 14, Endian.little),
            16,
            reason: asset,
          );
          expect(blockAlign, channels * 2, reason: asset);
          expect(byteRate, sampleRate * blockAlign, reason: asset);
          hasFormat = true;
        } else if (id == 'data') {
          expect(hasFormat, isTrue, reason: asset);
          expect(size, greaterThan(0), reason: asset);
          expect(size % blockAlign, 0, reason: asset);
          expect(
            bytes.sublist(start, end).any((byte) => byte != 0),
            isTrue,
            reason: asset,
          );
          hasAudio = true;
        }
        offset = end + size % 2;
      }
      expect(offset, bytes.length, reason: asset);
      expect(hasFormat && hasAudio, isTrue, reason: asset);
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
      bonusPlayer: _Effects(),
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

  test('奖励语音优先且不随转换帧重播，静音后台重开和退出取消且不补播', () async {
    final manager = MatchManager(generate: false);
    final voice = _Voice();
    final bonus = _Effects();
    final audio = MatchAudioController(
      manager: manager,
      player: _Effects(),
      praisePlayer: voice,
      bonusPlayer: bonus,
      store: _Store(),
    );
    await audio.ready;
    _praise(manager, ComboPraise.amazing);
    manager.bonusTime.value = true;
    expect(bonus.played, [MatchSound.bonus]);
    expect(voice.stops, greaterThan(0));
    _praise(manager, ComboPraise.unbelievable);
    expect(voice.played, [ComboPraise.amazing]);
    final stops = bonus.stops;
    for (var i = 0; i < 5; i++) {
      manager.bonusTime.value = true;
      manager.sound.value = const MatchSoundEvent(MatchSound.bonus);
    }
    expect(bonus.played, hasLength(1));
    expect(bonus.stops, stops);
    audio.setEnabled(false);
    expect(bonus.stops, greaterThan(stops));
    audio.setEnabled(true);
    expect(bonus.played, hasLength(1));
    audio.setActive(false);
    manager.bonusTime.value = false;
    manager.bonusTime.value = true;
    audio.setActive(true);
    expect(bonus.played, hasLength(1));
    final backgroundStops = bonus.stops;
    manager.sound.value = const MatchSoundEvent(MatchSound.reset);
    manager.bonusTime.value = false;
    expect(bonus.stops, greaterThan(backgroundStops));
    manager.bonusTime.value = true;
    expect(bonus.played, hasLength(2));
    await audio.dispose();
    await audio.dispose();
    manager.bonusTime.value = false;
    manager.bonusTime.value = true;
    expect(bonus.played, hasLength(2));
    expect(bonus.disposals, 1);
    expect(voice.disposals, 1);
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
        bonusPlayer: _Effects(),
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

    testWidgets('通关多个奖励帧只播一次 Bonus Time，刷新与快照不补播：$reduceMotion', (
      tester,
    ) async {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(_board(winning: true))
        ..reduceMotion = reduceMotion;
      final voice = _Voice();
      final bonus = _Effects();
      var bonusFrames = 0;
      manager.sound.addListener(() {
        if (manager.sound.value?.sound == MatchSound.bonus) bonusFrames++;
      });
      final audio = MatchAudioController(
        manager: manager,
        player: _Effects(),
        praisePlayer: voice,
        bonusPlayer: bonus,
        store: _Store(),
      );
      await audio.ready;
      manager.swap(10, 2);
      for (var i = 0; i < 400 && manager.busy.value; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(manager.busy.value, isFalse);
      expect(manager.board!.status, MatchStatus.won);
      expect(bonusFrames, greaterThan(1));
      expect(bonus.played, [MatchSound.bonus]);
      expect(voice.played, isEmpty);
      manager.refreshView();
      manager.loadState(manager.board!.toJson());
      expect(bonus.played, hasLength(1));
      await audio.dispose();
      manager.dispose();
    });
  }
}
