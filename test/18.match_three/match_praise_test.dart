import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/00.common/sound/sound_service.dart';
import 'package:treasure/18.match_three/middle/combo_praise.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_audio.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/middle/match_sound.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';
import 'package:treasure/18.match_three/upper/match_celebration.dart';

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

Map<String, dynamic> _board({
  bool winning = false,
  int moves = 3,
  bool simple = false,
}) {
  final data = MatchBoard.random(seed: 7).toJson();
  final overrides = {0: 0, 1: 0, 2: 1, if (!simple) 3: 0, 10: 0};
  data['pieces'] = [
    for (var i = 0; i < MatchBoard.cells; i++)
      [i + 1, overrides[i] ?? (i ~/ 8 * 2 + i % 8) % 6, 0],
  ];
  data['nextId'] = 65;
  data['ice'] = List.filled(64, 0);
  data['targets'] = winning ? {'0': 1, '1': 1} : {'4': 1000, '5': 1000};
  data['collected'] = [0, winning ? 1 : 0, 0, 0, 0, 0];
  if (winning) {
    data['movesLeft'] = moves;
    data['moveNumber'] = (data['initialMoves'] as int) - moves;
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
  test('连续赞美每次都播报，消除声不抢占语音，静音后台和重开仍可取消', () async {
    final manager = MatchManager(generate: false);
    final voice = _Voice();
    final effects = _Effects();
    final audio = MatchAudioController(
      manager: manager,
      player: effects,
      winPlayer: _Effects(),
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
      winPlayer: _Effects(),
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
      winPlayer: _Effects(),
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

  testWidgets('等待胜利音效期间重开、同步重置或退出，不得迟到进入旧奖励阶段', (tester) async {
    for (final cancel in ['restart', 'snapshot', 'reset', 'dispose']) {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(_board(winning: true));
      final win = _Effects()..playing = Completer<void>();
      final bonus = _Effects();
      final audio = MatchAudioController(
        manager: manager,
        player: _Effects(),
        winPlayer: win,
        praisePlayer: _Voice(),
        bonusPlayer: bonus,
        store: _Store(),
      );
      await audio.ready;
      manager.swap(10, 2);
      expect(win.played, [MatchSound.win]);
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

  testWidgets('胜利音效静音、切后台或超时后，奖励结算仍可继续且不补播', (tester) async {
    for (final mode in ['mute', 'background', 'timeout']) {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(_board(winning: true));
      final win = _Effects()..playing = Completer<void>();
      final bonus = _Effects();
      final audio = MatchAudioController(
        manager: manager,
        player: _Effects(),
        winPlayer: win,
        praisePlayer: _Voice(),
        bonusPlayer: bonus,
        store: _Store(),
      );
      await audio.ready;
      manager.swap(10, 2);
      expect(win.played, [MatchSound.win]);
      switch (mode) {
        case 'mute':
          audio.setEnabled(false);
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
      final expectedBonus = mode == 'background'
          ? <MatchSound>[]
          : [MatchSound.bonus];
      expect(bonus.played, expectedBonus);
      audio.setEnabled(true);
      audio.setActive(true);
      await tester.pump();
      expect(win.played, [MatchSound.win]);
      expect(bonus.played, expectedBonus);
      await audio.dispose();
      manager.dispose();
    }
  });

  testWidgets('撒花播放约 2.2 秒后自动移除', (tester) async {
    final manager = MatchManager(generate: false);
    addTearDown(manager.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MatchCelebration(manager: manager, child: const SizedBox()),
        ),
      ),
    );
    final confetti = find.byKey(const ValueKey('match-celebration'));
    expect(confetti, findsNothing);
    manager.winCelebration.value = true;
    await tester.pump();
    expect(confetti, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(confetti, findsOneWidget);
    // 在标称时长之后再采样，让控制器发出完成通知。
    await tester.pump(const Duration(milliseconds: 120));
    expect(confetti, findsNothing);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('零步通关显示恭喜完成，撒花期间可点击棋盘中央重开：$reduceMotion', (tester) async {
      final language = LanguageProvider.instance;
      language.resetForTesting();
      language.locale.value = AppLocale.zh;
      addTearDown(language.resetForTesting);
      final data = _board(winning: true, moves: 1, simple: true);
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(data);
      final win = _Effects()..playing = Completer<void>();
      final voice = _Voice()..playing = Completer<void>();
      final effects = _Effects();
      final bonus = _Effects();
      final audio = MatchAudioController(
        manager: manager,
        player: effects,
        winPlayer: win,
        praisePlayer: voice,
        bonusPlayer: bonus,
        store: _Store(),
      );
      await audio.ready;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: MatchGameView(manager: manager, onExit: () {}),
            ),
          ),
        ),
      );
      final confetti = find.byKey(const ValueKey('match-celebration'));
      final replay = find.byKey(const ValueKey('round-replay'));
      final multiplier = find.byKey(const ValueKey('match-multiplier'));
      var openedBonus = false;
      manager.bonusTime.addListener(
        () => openedBonus |= manager.bonusTime.value,
      );
      manager.swap(10, 2);
      await tester.pump();
      expect(tester.widget<Text>(multiplier).data, '1');
      for (var i = 0; i < 10 && voice.played.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(win.played, [MatchSound.win]);
      expect(voice.played, [ComboPraise.good]);
      final resultText = find.text('恭喜完成！');
      expect(find.text('Good'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Good'), findsOneWidget);
      win.playing!.complete();
      await tester.pump();
      expect(resultText, findsNothing);
      expect(replay, findsNothing);
      expect(effects.played, isNot(contains(MatchSound.won)));
      voice.playing!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Good'), findsNothing);
      expect(resultText, findsOneWidget);
      expect(replay, findsOneWidget);
      expect(confetti, reduceMotion ? findsNothing : findsOneWidget);
      expect(openedBonus, isFalse);
      expect(bonus.played, isEmpty);
      expect(manager.roundSettled, isTrue);
      expect(manager.view.value!.movesLeft, 0);
      expect(effects.played.last, MatchSound.won);
      await tester.ensureVisible(replay);
      await tester.pump();
      expect(confetti, reduceMotion ? findsNothing : findsOneWidget);
      await tester.tap(replay);
      await tester.pump();
      expect(manager.roundNumber, 1);
      expect(manager.board!.status, MatchStatus.playing);
      expect(manager.board!.moveNumber, 0);
      expect(resultText, findsNothing);
      expect(replay, findsNothing);
      expect(confetti, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.dispose();
      manager.dispose();
    });

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
          winPlayer: _Effects(),
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
          winPlayer: _Effects(),
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
        winPlayer: _Effects(),
        praisePlayer: voice,
        bonusPlayer: _Effects(),
        store: _Store(),
      );
      await audio.ready;
      for (final move in [(1, 2), (3, 11)]) {
        manager.swap(move.$1, move.$2);
        for (var i = 0; i < 400 && manager.comboPraise.value == null; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(manager.comboPraise.value, ComboPraise.good.label);
        expect(manager.canInteract, isFalse);
        await tester.pump(const Duration(seconds: 1));
        expect(manager.comboPraise.value, isNull);
        expect(manager.canInteract, isTrue);
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

    testWidgets('胜利庆祝与行动并行，赞美和胜利音结束后直接开始奖励：$reduceMotion', (tester) async {
      final data = _board(winning: true, simple: true);
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..loadState(data)
        ..reduceMotion = reduceMotion;
      final voice = _Voice()..playing = Completer<void>();
      final win = _Effects()..playing = Completer<void>();
      final effects = _Effects();
      final bonus = _Effects()..playing = Completer<void>();
      final order = <String>[];
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
        player: effects,
        winPlayer: win,
        praisePlayer: voice,
        bonusPlayer: bonus,
        store: _Store(),
      );
      await audio.ready;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MatchCelebration(manager: manager, child: const SizedBox()),
          ),
        ),
      );
      final confetti = find.byKey(const ValueKey('match-celebration'));
      manager.swap(10, 2);
      if (!reduceMotion) {
        expect(win.played, isEmpty);
        await tester.pump(const Duration(milliseconds: BonusTiming.fall));
        expect(manager.view.value!.frame.phase, FramePhase.clear);
        expect(voice.played, isEmpty);
      }
      expect(win.played, [MatchSound.win]);
      expect(manager.view.value!.frame.goalsMet, isTrue);
      expect(manager.comboMultiplier.value, 1);
      await tester.pump();
      expect(confetti, reduceMotion ? findsNothing : findsOneWidget);
      for (var i = 0; i < 10 && voice.played.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(voice.played, [ComboPraise.good]);
      expect(manager.comboPraise.value, 'Good');
      expect(manager.view.value!.frame.phase, FramePhase.settled);
      expect(manager.view.value!.score, actionEnd.score);
      expect(manager.view.value!.movesLeft, actionEnd.movesLeft);
      expect(manager.roundSettled, isFalse);
      expect(manager.canInteract, isFalse);
      win.playing!.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(manager.comboPraise.value, 'Good');
      expect(manager.bonusTime.value, isFalse);
      expect(bonus.played, isEmpty);
      voice.playing!.complete();
      await tester.pump();
      expect(manager.comboPraise.value, isNull);
      expect(confetti, reduceMotion ? findsNothing : findsOneWidget);
      expect(manager.bonusTime.value, isTrue);
      expect(bonus.played, [MatchSound.bonus]);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(manager.view.value!.movesLeft, actionEnd.movesLeft);
      expect(manager.view.value!.score, actionEnd.score);
      expect(manager.busy.value, isTrue);
      expect(manager.roundSettled, isFalse);
      expect(bonusFrames, 0);
      expect(order, ['bonus']);
      expect(effects.played, isNot(contains(MatchSound.won)));
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
      expect(voice.played, [ComboPraise.good]);
      expect(order, ['bonus', 'conversion']);
      expect(manager.roundSettled, isTrue);
      expect(effects.played.last, MatchSound.won);
      manager.refreshView();
      manager.loadState(manager.board!.toJson());
      expect(bonus.played, hasLength(1));
      expect(
        effects.played.where((sound) => sound == MatchSound.won),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.dispose();
      manager.dispose();
    });
  }
}
