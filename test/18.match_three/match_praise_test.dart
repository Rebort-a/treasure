import 'dart:async';
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
  Completer<void>? playing;
  int stops = 0;
  int disposals = 0;
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(ComboPraise sound) async {
    played.add(sound);
    await playing?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (playing?.isCompleted == false) playing!.complete();
  }

  @override
  Future<void> dispose() async {
    disposals++;
    if (playing?.isCompleted == false) playing!.complete();
  }
}

class _Effects implements MatchSoundPlayer {
  final played = <MatchSound>[];
  Completer<void>? playing;
  int stops = 0;
  int disposals = 0;
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(MatchSound sound) async {
    played.add(sound);
    await playing?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (playing?.isCompleted == false) playing!.complete();
  }

  @override
  Future<void> dispose() async {
    disposals++;
    if (playing?.isCompleted == false) playing!.complete();
  }
}

class _Store implements JsonStore {
  Completer<void>? loading;
  Map<String, dynamic> voiceSettings = {};

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async {
    await loading?.future;
    return name == 'voice' ? voiceSettings : {};
  }

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

Future<void> _waitForBonus(
  WidgetTester tester,
  MatchManager manager,
  _Effects bonus,
) async {
  for (var i = 0; i < 400 && bonus.played.isEmpty && manager.busy.value; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(bonus.played, [MatchSound.bonus]);
  expect(manager.bonusTime.value, isTrue);
  expect(manager.busy.value, isTrue);
}

void main() {
  test('赞美与奖励播报均绑定完整且非静音的离线 PCM WAV 资源', () {
    for (final asset in [
      for (final praise in ComboPraise.values) praise.asset,
      'audio/voice/bonus_time.wav',
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

  test('连续赞美每次都播报，消除声不抢占语音，静音后台和重开仍可取消', () async {
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
    expect(voice.played, [
      ComboPraise.good,
      ComboPraise.good,
      ComboPraise.unbelievable,
    ]);
    expect(effects.played, [MatchSound.bomb]);
    expect(voice.stops, stops);
    audio.audioPreferences!.setVoiceEnabled(false);
    _praise(manager, ComboPraise.amazing);
    expect(voice.stops, greaterThan(stops));
    expect(voice.played, hasLength(3));
    audio.audioPreferences!.setVoiceEnabled(true);
    audio.setActive(false);
    _praise(manager, ComboPraise.excellent);
    audio.setActive(true);
    expect(voice.played, hasLength(3));
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
    audio.audioPreferences!.setVoiceEnabled(false);
    expect(bonus.stops, greaterThan(stops));
    audio.audioPreferences!.setVoiceEnabled(true);
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

  test('语音等待偏好读取，恢复关闭状态及重新开启均不补播旧赞美和奖励语音', () async {
    final manager = MatchManager(generate: false);
    final voice = _Voice();
    final bonus = _Effects();
    final store = _Store()
      ..loading = Completer<void>()
      ..voiceSettings = {'enabled': false};
    final audio = MatchAudioController(
      manager: manager,
      player: _Effects(),
      praisePlayer: voice,
      bonusPlayer: bonus,
      store: store,
    );
    await Future<void>.delayed(Duration.zero);
    _praise(manager, ComboPraise.good);
    manager.bonusTime.value = true;
    expect(voice.played, isEmpty);
    expect(bonus.played, isEmpty);
    store.loading!.complete();
    await audio.ready;
    expect(voice.played, isEmpty);
    expect(bonus.played, isEmpty);
    manager.bonusTime.value = false;
    _praise(manager, ComboPraise.great);
    expect(voice.played, isEmpty);
    audio.audioPreferences!.setVoiceEnabled(true);
    expect(voice.played, isEmpty);
    expect(bonus.played, isEmpty);
    _praise(manager, ComboPraise.good);
    expect(voice.played, [ComboPraise.good]);
    manager.bonusTime.value = true;
    expect(bonus.played, [MatchSound.bonus]);
    expect(audio.enabled.value, isTrue);
    await audio.dispose();
    manager.dispose();
  });

  testWidgets('等待通关播报期间重开、同步重置或退出，不得迟到进入旧奖励阶段', (tester) async {
    for (final cancel in ['restart', 'snapshot', 'reset', 'dispose']) {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(_board(winning: true));
      final voice = _Voice()..playing = Completer<void>();
      final bonus = _Effects();
      final audio = MatchAudioController(
        manager: manager,
        player: _Effects(),
        praisePlayer: voice,
        bonusPlayer: bonus,
        store: _Store(),
      );
      await audio.ready;
      manager.swap(10, 2);
      expect(voice.played, hasLength(1));
      expect(manager.bonusTime.value, isFalse);
      switch (cancel) {
        case 'restart':
          manager.restart(seed: 42);
        case 'snapshot':
          manager.loadState(manager.board!.toJson());
        case 'reset':
          manager.resetNetworkRound();
        case 'dispose':
          await audio.dispose();
          manager.dispose();
      }
      await tester.pump(const Duration(seconds: 10));
      expect(bonus.played, isEmpty, reason: cancel);
      await audio.dispose();
      manager.dispose();
    }
  });

  testWidgets('静音、切后台或播放器不回报完成时，奖励结算仍可继续且不补播', (tester) async {
    for (final mode in ['mute', 'background', 'timeout']) {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(_board(winning: true));
      final voice = _Voice()..playing = Completer<void>();
      final bonus = _Effects();
      final audio = MatchAudioController(
        manager: manager,
        player: _Effects(),
        praisePlayer: voice,
        bonusPlayer: bonus,
        store: _Store(),
      );
      await audio.ready;
      manager.swap(10, 2);
      expect(voice.played, hasLength(1));
      switch (mode) {
        case 'mute':
          audio.audioPreferences!.setVoiceEnabled(false);
        case 'background':
          audio.setActive(false);
        case 'timeout':
          break;
      }
      for (var i = 0; i < 100 && manager.busy.value; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(manager.busy.value, isFalse, reason: mode);
      expect(manager.board!.status, MatchStatus.won);
      expect(manager.roundSettled, isTrue);
      expect(voice.played, hasLength(1));
      expect(bonus.played, mode == 'timeout' ? [MatchSound.bonus] : isEmpty);
      audio.audioPreferences!.setVoiceEnabled(true);
      audio.setActive(true);
      await tester.pump();
      expect(voice.played, hasLength(1));
      expect(bonus.played, mode == 'timeout' ? [MatchSound.bonus] : isEmpty);
      await audio.dispose();
      manager.dispose();
    }
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('奖励开场等待可被重开、快照、联机重置和退出取消：$reduceMotion', (tester) async {
      for (final cancel in ['restart', 'snapshot', 'reset', 'dispose']) {
        final manager = MatchManager(generate: false)
          ..reduceMotion = true
          ..loadState(_board(winning: true))
          ..reduceMotion = reduceMotion;
        final bonus = _Effects()..playing = Completer<void>();
        final audio = MatchAudioController(
          manager: manager,
          player: _Effects(),
          praisePlayer: _Voice(),
          bonusPlayer: bonus,
          store: _Store(),
        );
        await audio.ready;
        manager.swap(10, 2);
        await _waitForBonus(tester, manager, bonus);
        var conversions = 0;
        manager.view.addListener(() {
          final frame = manager.view.value?.frame;
          if (frame != null &&
              (frame.transferringPieceIds.isNotEmpty ||
                  frame.convertedPieceIds.isNotEmpty)) {
            conversions++;
          }
        });
        switch (cancel) {
          case 'restart':
            manager.restart(seed: 42);
          case 'snapshot':
            manager.loadState(manager.board!.toJson());
          case 'reset':
            manager.resetNetworkRound();
          case 'dispose':
            await audio.dispose();
            manager.dispose();
        }
        await tester.pump(const Duration(seconds: 10));
        expect(conversions, 0, reason: cancel);
        expect(bonus.played, hasLength(1), reason: cancel);
        await audio.dispose();
        manager.dispose();
      }
    });

    testWidgets('奖励开场静音、切后台或超时后仍继续结算，恢复时不补播：$reduceMotion', (tester) async {
      for (final mode in ['mute', 'background', 'timeout']) {
        final manager = MatchManager(generate: false)
          ..reduceMotion = true
          ..loadState(_board(winning: true))
          ..reduceMotion = reduceMotion;
        final bonus = _Effects()..playing = Completer<void>();
        final audio = MatchAudioController(
          manager: manager,
          player: _Effects(),
          praisePlayer: _Voice(),
          bonusPlayer: bonus,
          store: _Store(),
        );
        await audio.ready;
        manager.swap(10, 2);
        await _waitForBonus(tester, manager, bonus);
        final moves = manager.view.value!.movesLeft;
        switch (mode) {
          case 'mute':
            audio.audioPreferences!.setVoiceEnabled(false);
          case 'background':
            audio.setActive(false);
          case 'timeout':
            await tester.pump(const Duration(milliseconds: 4900));
            expect(manager.view.value!.movesLeft, moves);
            expect(manager.busy.value, isTrue);
        }
        // 取消播报应立即解除等待，不必再耗尽五秒保护时间。
        for (var i = 0; i < 15 && manager.view.value!.movesLeft == moves; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(manager.view.value!.movesLeft, lessThan(moves), reason: mode);
        for (var i = 0; i < 400 && manager.busy.value; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(manager.roundSettled, isTrue, reason: mode);
        expect(manager.board!.status, MatchStatus.won);
        audio.audioPreferences!.setVoiceEnabled(true);
        audio.setActive(true);
        await tester.pump();
        expect(bonus.played, hasLength(1));
        await audio.dispose();
        manager.dispose();
      }
    });

    testWidgets('连续两次真实 Good 都播报，刷新与重复快照不补播：$reduceMotion', (tester) async {
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
      for (final move in [(1, 2), (3, 11)]) {
        manager.swap(move.$1, move.$2);
        for (var i = 0; i < 400 && manager.busy.value; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(manager.busy.value, isFalse);
        expect(manager.comboPraise.value, ComboPraise.good.label);
      }
      expect(voice.played, [ComboPraise.good, ComboPraise.good]);
      final state = manager.board!.toJson();
      manager.refreshView();
      manager.loadState(state);
      expect(voice.played, hasLength(2));
      manager.reduceMotion = true;
      manager.restart(seed: 42);
      expect(voice.stops, greaterThan(0));
      await audio.dispose();
      manager.dispose();
    });

    testWidgets('行动评价与奖励开场依次播完才转换步数，且不重复播报：$reduceMotion', (tester) async {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(_board(winning: true))
        ..reduceMotion = reduceMotion;
      final voice = _Voice()..playing = Completer<void>();
      final bonus = _Effects()..playing = Completer<void>();
      final order = <String>[];
      manager.praiseVoice.addListener(() {
        if (manager.praiseVoice.value != null) order.add('praise');
      });
      manager.bonusTime.addListener(() {
        if (manager.bonusTime.value) order.add('bonus');
      });
      manager.view.addListener(() {
        final frame = manager.view.value?.frame;
        if (manager.bonusTime.value &&
            frame != null &&
            (frame.transferringPieceIds.isNotEmpty ||
                frame.convertedPieceIds.isNotEmpty) &&
            !order.contains('conversion')) {
          order.add('conversion');
        }
      });
      final actionEnd = MatchBoard.fromJson(manager.board!.toJson())
          .playSwap(10, 2)!
          .frames
          .firstWhere((frame) => frame.phase == FramePhase.bonus);
      var bonusFrames = 0;
      final bonusSoundAfterVoice = <bool>[];
      final bonusSoundOnConversion = <bool>[];
      manager.sound.addListener(() {
        if (manager.sound.value?.sound == MatchSound.bonus) {
          bonusFrames++;
          bonusSoundAfterVoice.add(bonus.playing!.isCompleted);
          bonusSoundOnConversion.add(
            manager.view.value!.frame.convertedPieceIds.isNotEmpty,
          );
        }
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
      for (
        var i = 0;
        i < 400 && voice.played.isEmpty && manager.busy.value;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(voice.played, hasLength(1));
      expect(manager.view.value!.frame.phase, FramePhase.settled);
      expect(manager.view.value!.score, actionEnd.score);
      expect(manager.view.value!.movesLeft, actionEnd.movesLeft);
      expect(manager.bonusTime.value, isFalse);
      expect(manager.busy.value, isTrue);
      expect(manager.roundSettled, isFalse);
      expect(manager.canInteract, isFalse);
      expect(bonus.played, isEmpty);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(manager.bonusTime.value, isFalse);
      expect(manager.comboPraise.value, voice.played.single.label);
      expect(bonus.played, isEmpty);
      voice.playing!.complete();
      await tester.pump();
      expect(manager.bonusTime.value, isTrue);
      expect(bonus.played, [MatchSound.bonus]);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(manager.view.value!.movesLeft, actionEnd.movesLeft);
      expect(manager.view.value!.score, actionEnd.score);
      expect(manager.busy.value, isTrue);
      expect(manager.roundSettled, isFalse);
      expect(bonusFrames, 0);
      expect(order, ['praise', 'bonus']);
      bonus.playing!.complete();
      await tester.pump();
      for (var i = 0; i < 400 && manager.busy.value; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(manager.busy.value, isFalse);
      expect(manager.board!.status, MatchStatus.won);
      expect(bonusFrames, actionEnd.movesLeft);
      expect(bonusSoundAfterVoice, everyElement(isTrue));
      expect(bonusSoundOnConversion, everyElement(isTrue));
      expect(bonus.played, [MatchSound.bonus]);
      expect(voice.played, hasLength(1));
      expect(order, ['praise', 'bonus', 'conversion']);
      manager.refreshView();
      manager.loadState(manager.board!.toJson());
      expect(bonus.played, hasLength(1));
      await audio.dispose();
      manager.dispose();
    });
  }
}
