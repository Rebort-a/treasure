import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/music_service.dart';
import 'package:treasure/00.common/service/sound_service.dart';
import 'package:treasure/18.match_three/middle/combo_praise.dart';
import 'package:treasure/18.match_three/middle/match_audio.dart';
import 'package:treasure/18.match_three/middle/match_sound.dart';

/// 模拟原生声道边界，验证资源上限、异步取消和释放，而非界面细节。
class _NativeAudio {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final directory = Directory.systemTemp.createTempSync(
    'treasure_match_audio_',
  );
  final created = <String>{};
  final disposed = <String>{};
  final active = <String>{};
  final resumes = <String>[];
  final releaseModes = <String>[];
  int peakActive = 0;
  int? failContextAt;
  Completer<void>? sourceStarted;
  Completer<void>? sourceGate;

  void install() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      _handle,
    );
  }

  Future<Object?> _handle(MethodCall call) async {
    final arguments = call.arguments as Map;
    final id = arguments['playerId'] as String;
    switch (call.method) {
      case 'create':
        created.add(id);
        messenger.setMockMethodCallHandler(
          MethodChannel('xyz.luan/audioplayers/events/$id'),
          (_) async => null,
        );
      case 'setAudioContext':
        if (created.length == failContextAt) {
          throw PlatformException(code: 'NoAudioDevice');
        }
      case 'setReleaseMode':
        releaseModes.add(arguments['releaseMode'] as String);
      case 'setSourceUrl':
        if (sourceStarted?.isCompleted == false) sourceStarted!.complete();
        await sourceGate?.future;
        await messenger.handlePlatformMessage(
          'xyz.luan/audioplayers/events/$id',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'event': 'audio.onPrepared',
            'value': true,
          }),
          (_) {},
        );
      case 'resume':
        resumes.add(id);
        active.add(id);
        if (active.length > peakActive) peakActive = active.length;
      case 'stop' || 'release' || 'pause':
        active.remove(id);
      case 'dispose':
        disposed.add(id);
        active.remove(id);
      case 'getCurrentPosition':
        return 0;
    }
    return null;
  }

  void uninstall() {
    for (final name in [
      'plugins.flutter.io/path_provider',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
      for (final id in created) 'xyz.luan/audioplayers/events/$id',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    directory.deleteSync(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // 文件缓存使用宿主路径，不能沿用组件测试默认的 Android 路径语义。
    debugDefaultTargetPlatformOverride = Platform.isWindows
        ? TargetPlatform.windows
        : Platform.isMacOS
        ? TargetPlatform.macOS
        : TargetPlatform.linux;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('密集播放最多使用四个原生声道，退出释放全部声道和缓存', () async {
    final native = _NativeAudio()..install();
    final player = MatchAssetSoundPlayer();
    try {
      await player.preload();
      for (var i = 0; i < 10; i++) {
        await player.play(i.isEven ? MatchSound.clear1 : MatchSound.bomb);
      }
      expect(native.created, hasLength(4));
      expect(native.resumes, hasLength(10));
      expect(native.peakActive, lessThanOrEqualTo(4));
      await player.dispose();
      await player.dispose();
      expect(native.disposed, native.created);
      expect(native.active, isEmpty);
      expect(
        native.directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.wav')),
        isEmpty,
      );
    } finally {
      await player.dispose();
      native.uninstall();
    }
  });

  test('音源异步准备过程中静音，旧请求不得迟到恢复播放', () async {
    final native = _NativeAudio()
      ..sourceStarted = Completer<void>()
      ..sourceGate = Completer<void>()
      ..install();
    final player = MatchAssetSoundPlayer();
    try {
      await player.preload();
      final playing = player.play(MatchSound.won);
      await native.sourceStarted!.future;
      final stopping = player.stop();
      native.sourceGate!.complete();
      await Future.wait([playing, stopping]);
      expect(native.resumes, isEmpty);
      expect(native.active, isEmpty);
      await player.play(MatchSound.select);
      expect(native.resumes, hasLength(1));
    } finally {
      await player.dispose();
      native.uninstall();
    }
  });

  test('加载过程中退出，不再创建声道或留下缓存', () async {
    final native = _NativeAudio()..install();
    final player = MatchAssetSoundPlayer();
    try {
      final loading = player.preload();
      await player.dispose();
      await loading;
      await player.play(MatchSound.won);
      expect(native.created, isEmpty);
      expect(native.resumes, isEmpty);
      expect(
        native.directory.listSync(recursive: true).whereType<File>(),
        isEmpty,
      );
    } finally {
      await player.dispose();
      native.uninstall();
    }
  });

  test('部分声道初始化失败，已创建资源仍全部释放', () async {
    final native = _NativeAudio()
      ..failContextAt = 2
      ..install();
    final player = MatchAssetSoundPlayer();
    try {
      await expectLater(player.preload(), throwsA(isA<PlatformException>()));
      expect(native.created, hasLength(2));
      expect(native.disposed, native.created);
      await player.stop();
      await player.dispose();
    } finally {
      await player.dispose();
      native.uninstall();
    }
  });

  test('语音只有一个声道，新的赞美取消正在异步准备的旧赞美', () async {
    final native = _NativeAudio()
      ..sourceStarted = Completer<void>()
      ..sourceGate = Completer<void>()
      ..install();
    final player = AssetSoundPlayer<ComboPraise>(
      assets: {for (final praise in ComboPraise.values) praise: praise.asset},
      voiceCount: 1,
      latestOnly: true,
    );
    try {
      await player.preload();
      final first = player.play(ComboPraise.good);
      await native.sourceStarted!.future;
      final next = player.play(ComboPraise.unbelievable);
      native.sourceGate!.complete();
      await Future.wait([first, next]);
      expect(native.created, hasLength(1));
      expect(native.resumes, hasLength(1));
      expect(native.peakActive, 1);
      await player.dispose();
      expect(native.disposed, native.created);
    } finally {
      await player.dispose();
      native.uninstall();
    }
  });

  test('音乐独占声道，暂停恢复不重建，退出释放原生资源及缓存', () async {
    final native = _NativeAudio()..install();
    final player = AssetMusicPlayer('audio/music/tank.wav');
    try {
      await player.preload();
      expect(native.releaseModes, ['ReleaseMode.loop']);
      await player.setVolume(.3);
      await player.resume();
      await player.pause();
      expect(native.active, isEmpty);
      await player.resume();
      expect(native.created, hasLength(1));
      expect(native.resumes, hasLength(2));
      await player.dispose();
      expect(native.disposed, native.created);
      expect(
        native.directory.listSync(recursive: true).whereType<File>(),
        isEmpty,
      );
    } finally {
      await player.dispose();
      native.uninstall();
    }
  });

  test('音乐初始化失败立即释放已创建声道，之后退出不会重复释放', () async {
    final native = _NativeAudio()
      ..failContextAt = 1
      ..install();
    final player = AssetMusicPlayer('audio/music/tank.wav');
    try {
      await expectLater(player.preload(), throwsA(isA<PlatformException>()));
      expect(native.created, hasLength(1));
      expect(native.disposed, native.created);
      await player.dispose();
      expect(native.active, isEmpty);
    } finally {
      await player.dispose();
      native.uninstall();
    }
  });
}
