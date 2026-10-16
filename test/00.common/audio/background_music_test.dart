import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/00.common/service/music_service.dart';

class _Player implements MusicPlayer {
  Completer<void>? loading;
  Completer<void>? volumeGate;
  bool failPreload = false;
  bool failResume = false;
  final commands = <String>[];
  final volumes = <double>[];
  int disposals = 0;

  @override
  Future<void> preload() async {
    commands.add('preload');
    await loading?.future;
    if (failPreload) throw StateError('No device');
  }

  @override
  Future<void> resume() async {
    if (failResume) throw StateError('Playback blocked');
    commands.add('resume');
  }

  @override
  Future<void> pause() async => commands.add('pause');

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    await volumeGate?.future;
  }

  @override
  Future<void> dispose() async => disposals++;
}

class _Store implements JsonStore {
  final data = <String, Map<String, dynamic>>{};
  Completer<Map<String, dynamic>>? reading;

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async => reading == null
      ? Map.of(data['$project/$name'] ?? {})
      : await reading!.future;

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> value, {
    String project = '00.common',
  }) async => data['$project/$name'] = Map.of(value);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('两首循环音乐作为离线资源完整打包', () {
    for (final name in ['spaceship', 'tank']) {
      final file = File('assets/audio/music/$name.wav');
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
      expect(bytes.length, greaterThan(44100 * 20));
      expect(bytes.skip(44).any((byte) => byte != 0), isTrue);
    }
  });

  test('音乐只在运行、前台且开启时播放，暂停可恢复且重复通知不叠播', () async {
    final player = _Player();
    final audio = BackgroundMusicController(
      project: '11.spaceship',
      player: player,
      store: _Store(),
    );
    await audio.ready;
    await _flush();
    expect(player.commands, ['preload']);
    audio.setPlaying(true);
    audio.setPlaying(true);
    await _flush();
    expect(player.commands, ['preload', 'resume']);
    audio.setPlaying(false);
    await _flush();
    audio.setActive(false);
    audio.setPlaying(true);
    await _flush();
    expect(player.commands.last, 'pause');
    audio.setActive(true);
    await _flush();
    expect(player.commands.last, 'resume');
    audio.setEnabled(false);
    await _flush();
    expect(player.commands.last, 'pause');
    audio.setVolume(.2);
    await _flush();
    expect(player.commands.last, 'pause');
    expect(player.volumes.last, .2);
    audio.setEnabled(true);
    await _flush();
    expect(player.commands.last, 'resume');
    await audio.dispose();
    final before = player.commands.length;
    audio.setPlaying(false);
    audio.setActive(false);
    audio.setEnabled(false);
    await audio.dispose();
    expect(player.commands.length, before);
    expect(player.disposals, 1);
  });

  test('迟到设置不覆盖用户操作，保存时保留未修改音量并按项目隔离', () async {
    final store = _Store()..reading = Completer<Map<String, dynamic>>();
    final player = _Player();
    final audio = BackgroundMusicController(
      project: '11.spaceship',
      player: player,
      store: store,
    );
    audio.setPlaying(true);
    audio.setEnabled(false);
    store.reading!.complete({'enabled': true, 'volume': .65});
    await audio.ready;
    expect(audio.enabled.value, isFalse);
    expect(audio.volume.value, .65);
    await audio.dispose();
    expect(store.data['11.spaceship/music'], {'enabled': false, 'volume': .65});
    expect(store.data.containsKey('17.tank/music'), isFalse);
    store.reading = null;
    final restored = BackgroundMusicController(
      project: '11.spaceship',
      player: _Player(),
      store: store,
    );
    await restored.ready;
    expect(restored.enabled.value, isFalse);
    expect(restored.volume.value, .65);
    restored.setVolume(2);
    restored.setVolume(double.nan);
    expect(restored.volume.value, 1);
    await restored.dispose();
    expect(store.data['11.spaceship/music']!['volume'], 1);
  });

  test('异步音量更新读取最终状态，静音时不能迟到恢复音乐', () async {
    final player = _Player()..volumeGate = Completer<void>();
    final audio = BackgroundMusicController(
      project: '17.tank',
      player: player,
      store: _Store(),
    );
    audio.setPlaying(true);
    await audio.ready;
    await _flush();
    audio.setVolume(.6);
    audio.setEnabled(false);
    player.volumeGate!.complete();
    await _flush();
    expect(player.commands, ['preload']);
    expect(player.volumes.last, .6);
    await audio.dispose();
  });

  test('预载期间退出不启动音乐，等待初始化后只释放一次', () async {
    final player = _Player()..loading = Completer<void>();
    final audio = BackgroundMusicController(
      project: '17.tank',
      player: player,
      store: _Store(),
    );
    audio.setPlaying(true);
    await _flush();
    final disposal = audio.dispose();
    player.loading!.complete();
    await disposal;
    expect(player.commands, ['preload']);
    expect(player.disposals, 1);
  });

  test('设备或播放失败不向游戏抛错，后续操作仍可重试', () async {
    final failedPlayer = _Player()..failPreload = true;
    final failed = BackgroundMusicController(
      project: '11.spaceship',
      player: failedPlayer,
      store: _Store(),
    )..setPlaying(true);
    await failed.ready;
    await failed.dispose();
    expect(failedPlayer.disposals, 1);
    final player = _Player()..failResume = true;
    final audio = BackgroundMusicController(
      project: '17.tank',
      player: player,
      store: _Store(),
    )..setPlaying(true);
    await audio.ready;
    await _flush();
    player.failResume = false;
    audio.setEnabled(true);
    await _flush();
    expect(player.commands.last, 'resume');
    await audio.dispose();
  });
}
