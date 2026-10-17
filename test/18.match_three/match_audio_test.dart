import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/00.common/service/sound_service.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_audio.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/middle/match_sound.dart';

class _Player implements MatchSoundPlayer {
  final played = <MatchSound>[];
  Completer<void>? loading;
  bool failPreload = false;
  bool failPlay = false;
  int stops = 0;
  int disposals = 0;

  @override
  Future<void> preload() async {
    await loading?.future;
    if (failPreload) throw StateError('No audio device');
  }

  @override
  Future<void> play(MatchSound sound) async {
    if (failPlay) throw StateError('Playback blocked');
    played.add(sound);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposals++;
}

class _Voice implements SoundPlayer<ComboPraise> {
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(ComboPraise sound) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Store implements JsonStore {
  Map<String, dynamic> settings = {};
  Completer<Map<String, dynamic>>? reading;
  final writes = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async => name != 'audio'
      ? {}
      : reading == null
      ? settings
      : await reading!.future;

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {
    if (name != 'audio') return;
    settings = Map.of(data);
    writes.add(settings);
  }
}

void _emit(MatchManager manager, MatchSound sound) {
  manager.sound.value = MatchSoundEvent(sound);
}

Map<String, dynamic> _boardData({
  PieceEffect effect = PieceEffect.none,
  int moves = 8,
  bool winning = false,
}) {
  final data = MatchBoard.random(seed: 7).toJson();
  const overrides = {0: 0, 1: 0, 2: 1, 3: 0, 10: 0};
  data['pieces'] = [
    for (var i = 0; i < MatchBoard.cells; i++)
      [
        i + 1,
        overrides[i] ?? (i ~/ 8 * 2 + i % 8) % 6,
        (i == 0 ? effect : PieceEffect.none).index,
      ],
  ];
  data['nextId'] = 65;
  data['ice'] = List.filled(64, 0);
  data['targets'] = winning ? {'0': 1, '1': 1} : {'4': 1000, '5': 1000};
  data['collected'] = [0, winning ? 1 : 0, 0, 0, 0, 0];
  data['movesLeft'] = moves;
  data['moveNumber'] = (data['initialMoves'] as int) - moves;
  return data;
}

MatchManager _manager(Map<String, dynamic> data) {
  return MatchManager(generate: false)
    ..reduceMotion = true
    ..loadState(data);
}

Future<void> _settle(WidgetTester tester, List<MatchManager> managers) async {
  for (var i = 0; i < 400; i++) {
    if (managers.every((manager) => !manager.busy.value)) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('Animation did not finish');
}

void main() {
  test('所有播放事件都有有效且有界的 PCM 资源', () {
    for (final sound in MatchSound.values) {
      if (sound == MatchSound.reset) continue;
      final bytes = File('assets/${sound.asset}').readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(header.getUint16(20, Endian.little), 1);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 22050);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), bytes.length - 44);
      expect(bytes.length, inInclusiveRange(1000, 50000));
      expect(bytes.skip(44).any((byte) => byte != 0), isTrue);
    }
  });

  test('静音设置加载、切换、保存，并立即停止当前音频', () async {
    final manager = MatchManager(generate: false);
    final player = _Player();
    final store = _Store()..settings = {'enabled': false};
    final audio = MatchAudioController(
      manager: manager,
      player: player,
      praisePlayer: _Voice(),
      bonusPlayer: _Player(),
      store: store,
    );
    await audio.ready;
    expect(audio.enabled.value, isFalse);
    _emit(manager, MatchSound.swap);
    expect(player.played, isEmpty);
    audio.setEnabled(true);
    _emit(manager, MatchSound.swap);
    expect(player.played, [MatchSound.swap]);
    audio.setEnabled(false);
    _emit(manager, MatchSound.bomb);
    expect(player.stops, 1);
    expect(player.played, [MatchSound.swap]);
    await audio.dispose();
    expect(store.writes, [
      {'enabled': true},
      {'enabled': false},
    ]);
    expect(player.disposals, 1);
    manager.dispose();
  });

  test('后台不播放，回前台不补播，重开清空旧音效和限流状态', () async {
    final manager = MatchManager(generate: false);
    final player = _Player();
    final audio = MatchAudioController(
      manager: manager,
      player: player,
      praisePlayer: _Voice(),
      bonusPlayer: _Player(),
      store: _Store(),
    );
    await audio.ready;
    _emit(manager, MatchSound.clear1);
    _emit(manager, MatchSound.clear1);
    expect(player.played, [MatchSound.clear1]);
    audio.setActive(false);
    _emit(manager, MatchSound.won);
    expect(player.stops, 1);
    audio.setActive(true);
    expect(player.played, [MatchSound.clear1]);
    _emit(manager, MatchSound.reset);
    _emit(manager, MatchSound.clear1);
    expect(player.stops, 2);
    expect(player.played, [MatchSound.clear1, MatchSound.clear1]);
    await audio.dispose();
    _emit(manager, MatchSound.bomb);
    expect(player.played, hasLength(2));
    await audio.dispose();
    expect(player.disposals, 1);
    manager.dispose();
  });

  test('初始化期间不堆积声音，离开后异步加载不能恢复播放', () async {
    final manager = MatchManager(generate: false);
    final player = _Player()..loading = Completer<void>();
    final audio = MatchAudioController(
      manager: manager,
      player: player,
      praisePlayer: _Voice(),
      bonusPlayer: _Player(),
      store: _Store(),
    );
    _emit(manager, MatchSound.swap);
    await audio.dispose();
    player.loading!.complete();
    await audio.ready;
    _emit(manager, MatchSound.won);
    expect(player.played, isEmpty);
    expect(player.disposals, 1);
    manager.dispose();
  });

  test('用户切换优先于迟到的设置读取，快速切换按最终状态保存', () async {
    final manager = MatchManager(generate: false);
    final player = _Player();
    final store = _Store()..reading = Completer<Map<String, dynamic>>();
    final audio = MatchAudioController(
      manager: manager,
      player: player,
      praisePlayer: _Voice(),
      bonusPlayer: _Player(),
      store: store,
    );
    audio.setEnabled(false);
    store.reading!.complete({'enabled': true});
    await audio.ready;
    expect(audio.enabled.value, isFalse);
    audio.setEnabled(true);
    audio.setEnabled(false);
    await audio.dispose();
    expect(store.settings['enabled'], isFalse);
    manager.dispose();
  });

  test('播放失败不影响游戏，后续用户手势仍可再次尝试', () async {
    final manager = _manager(_boardData());
    final player = _Player()..failPlay = true;
    final audio = MatchAudioController(
      manager: manager,
      player: player,
      praisePlayer: _Voice(),
      bonusPlayer: _Player(),
      store: _Store(),
    );
    await audio.ready;
    manager.swap(10, 2);
    await Future<void>.delayed(Duration.zero);
    expect(manager.board!.moveNumber, greaterThan(0));
    expect(manager.busy.value, isFalse);
    player.failPlay = false;
    _emit(manager, MatchSound.bomb);
    expect(player.played, [MatchSound.bomb]);
    await audio.dispose();
    manager.dispose();
  });

  test('预载失败时游戏仍可操作，释放仍正常执行', () async {
    final manager = _manager(_boardData());
    final player = _Player()..failPreload = true;
    final audio = MatchAudioController(
      manager: manager,
      player: player,
      praisePlayer: _Voice(),
      bonusPlayer: _Player(),
      store: _Store(),
    );
    await audio.ready;
    manager.swap(10, 2);
    expect(manager.canInteract, isTrue);
    expect(player.played, isEmpty);
    await audio.dispose();
    expect(player.disposals, 1);
    manager.dispose();
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('首次入场等待冷加载，重开只播一次，刷新静音与后台不补播：$reduceMotion', (tester) async {
      final manager = MatchManager(generate: false)
        ..reduceMotion = reduceMotion
        ..restart(seed: 7);
      final player = _Player()..loading = Completer<void>();
      final audio = MatchAudioController(
        manager: manager,
        player: player,
        praisePlayer: _Voice(),
        bonusPlayer: _Player(),
        store: _Store(),
      );
      await _settle(tester, [manager]);
      expect(player.played, isEmpty);
      player.loading!.complete();
      await audio.ready;
      expect(player.played, [MatchSound.entrance]);

      manager.restart(seed: 8);
      await _settle(tester, [manager]);
      expect(player.played, [MatchSound.entrance, MatchSound.entrance]);
      manager.refreshView();
      manager.loadState(manager.board!.toJson());
      expect(player.played, hasLength(2));

      audio.setEnabled(false);
      manager.restart(seed: 9);
      await _settle(tester, [manager]);
      audio.setEnabled(true);
      expect(player.played, hasLength(2));
      audio.setActive(false);
      manager.restart(seed: 10);
      await _settle(tester, [manager]);
      audio.setActive(true);
      expect(player.played, hasLength(2));
      await audio.dispose();
      manager.dispose();
    });

    testWidgets('双彩虹全清补齐播放补齐音而非开局音，本地与联机重演一致：$reduceMotion', (tester) async {
      final data = _boardData(effect: PieceEffect.rainbow);
      (data['pieces'] as List)[1][2] = PieceEffect.rainbow.index;
      final local = _manager(data)..reduceMotion = reduceMotion;
      final member = _manager(data)..reduceMotion = reduceMotion;
      final localSounds = <MatchSound>[];
      final memberSounds = <MatchSound>[];
      local.sound.addListener(() => localSounds.add(local.sound.value!.sound));
      member.sound.addListener(
        () => memberSounds.add(member.sound.value!.sound),
      );
      local.swap(0, 1);
      member.loadState(local.board!.toJson());
      await _settle(tester, [local, member]);
      expect(
        localSounds.where((cue) => cue == MatchSound.appear),
        hasLength(1),
      );
      expect(localSounds, isNot(contains(MatchSound.entrance)));
      expect(memberSounds, localSounds);
      expect(
        local.board!.pieces.whereType<Piece>(),
        hasLength(MatchBoard.cells),
      );
      local.refreshView();
      member.loadState(local.board!.toJson());
      expect(
        memberSounds.where((cue) => cue == MatchSound.appear),
        hasLength(1),
      );
      local.dispose();
      member.dispose();
    });
  }

  testWidgets('冷加载期间的入场音在静音、后台、同步重置、退出或新事件后取消', (tester) async {
    for (final reason in [
      'mute',
      'background',
      'reset',
      'dispose',
      'newSound',
    ]) {
      final manager = MatchManager(generate: false)
        ..reduceMotion = true
        ..restart(seed: 7);
      final player = _Player()..loading = Completer<void>();
      final audio = MatchAudioController(
        manager: manager,
        player: player,
        praisePlayer: _Voice(),
        bonusPlayer: _Player(),
        store: _Store(),
      );
      await tester.pump();
      switch (reason) {
        case 'mute':
          audio.setEnabled(false);
          audio.setEnabled(true);
        case 'background':
          audio.setActive(false);
          audio.setActive(true);
        case 'reset':
          manager.resetNetworkRound();
        case 'dispose':
          await audio.dispose();
        case 'newSound':
          _emit(manager, MatchSound.select);
      }
      player.loading!.complete();
      await audio.ready;
      expect(player.played, isEmpty, reason: reason);
      await audio.dispose();
      manager.dispose();
    }
  });

  testWidgets('选择、无效交换及展示帧产生音效，刷新和快照不重复播放', (tester) async {
    final manager = _manager(_boardData());
    final sounds = <MatchSound>[];
    manager.sound.addListener(() => sounds.add(manager.sound.value!.sound));
    manager.selectCell(20);
    expect(sounds, [MatchSound.select]);
    manager.showInvalidSwap(20, 21);
    expect(sounds.last, MatchSound.invalid);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 180));
    manager.reduceMotion = false;
    manager.swap(10, 2);
    await _settle(tester, [manager]);
    expect(sounds, contains(MatchSound.swap));
    expect(sounds, contains(MatchSound.clear1));
    expect(sounds, contains(MatchSound.fall));
    final played = sounds.where((sound) => sound != MatchSound.reset).toList();
    manager.refreshView();
    manager.loadState(manager.board!.toJson());
    expect(sounds.where((sound) => sound != MatchSound.reset), played);
    manager.dispose();
  });

  testWidgets('特效与碎冰跟随消除展示帧播放', (tester) async {
    for (final entry in {
      PieceEffect.row: MatchSound.line,
      PieceEffect.bomb: MatchSound.bomb,
      PieceEffect.rainbow: MatchSound.rainbow,
    }.entries) {
      final data = _boardData(effect: entry.key);
      data['ice'] = [for (var i = 0; i < 64; i++) i == 8 ? 1 : 0];
      final manager = _manager(data)..reduceMotion = false;
      final sounds = <MatchSound>[];
      manager.sound.addListener(() => sounds.add(manager.sound.value!.sound));
      manager.swap(10, 2);
      await _settle(tester, [manager]);
      expect(sounds, contains(entry.value));
      expect(sounds, contains(MatchSound.ice));
      manager.dispose();
    }
  });

  testWidgets('发布者回环与成员重演产生相同音效，不在判定时提前发声', (tester) async {
    final data = _boardData();
    final publisher = _manager(data)..reduceMotion = false;
    final member = _manager(data)..reduceMotion = false;
    final publisherSounds = <MatchSound>[];
    final memberSounds = <MatchSound>[];
    publisher.sound.addListener(
      () => publisherSounds.add(publisher.sound.value!.sound),
    );
    member.sound.addListener(() => memberSounds.add(member.sound.value!.sound));
    expect(publisher.applyNetworkAction({'from': 10, 'to': 2}), isTrue);
    expect(publisherSounds, isEmpty);
    final snapshot = publisher.saveState();
    publisher.loadState(snapshot);
    member.loadState(snapshot);
    await _settle(tester, [publisher, member]);
    expect(publisherSounds, isNotEmpty);
    expect(memberSounds, publisherSounds);
    publisher.dispose();
    member.dispose();
  });

  testWidgets('胜利等到奖励结算结束，减少动画时仍播报结果且不重复', (tester) async {
    for (final reduceMotion in [false, true]) {
      final manager = _manager(_boardData(moves: 3, winning: true))
        ..reduceMotion = reduceMotion;
      final sounds = <MatchSound>[];
      manager.sound.addListener(() => sounds.add(manager.sound.value!.sound));
      manager.swap(10, 2);
      expect(manager.board!.status, MatchStatus.won);
      expect(sounds, isNot(contains(MatchSound.won)));
      await _settle(tester, [manager]);
      expect(sounds, contains(MatchSound.bonus));
      expect(sounds.last, MatchSound.won);
      manager.refreshView();
      manager.loadState(manager.board!.toJson());
      expect(sounds.where((sound) => sound == MatchSound.won), hasLength(1));
      manager.dispose();
    }
  });

  testWidgets('失败和重开取消旧奖励，不遗留迟到的结果音效', (tester) async {
    final losing = _manager(_boardData(moves: 1));
    final sounds = <MatchSound>[];
    losing.sound.addListener(() => sounds.add(losing.sound.value!.sound));
    losing.swap(10, 2);
    expect(sounds.last, MatchSound.lost);
    losing.dispose();

    final winning = _manager(_boardData(moves: 3, winning: true))
      ..reduceMotion = false;
    sounds.clear();
    winning.sound.addListener(() => sounds.add(winning.sound.value!.sound));
    winning.swap(10, 2);
    winning.reduceMotion = true;
    winning.restart(seed: 42);
    expect(sounds, contains(MatchSound.reset));
    expect(sounds.last, MatchSound.entrance);
    await tester.pump(const Duration(seconds: 10));
    expect(sounds, isNot(contains(MatchSound.won)));
    winning.dispose();
  });
}
