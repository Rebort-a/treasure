import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_preferences.dart';
import '../service/json_store.dart';

/// 音乐独占声道，不与射击、消除等短音效竞争播放器。
abstract interface class MusicPlayer {
  Future<void> preload();
  Future<void> resume();
  Future<void> pause();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class AssetMusicPlayer implements MusicPlayer {
  final String asset;
  final AudioCache _cache = AudioCache(prefix: 'assets/');
  AudioPlayer? _player;
  Future<void>? _initializing;
  Future<void>? _disposing;
  bool _disposed = false;

  AssetMusicPlayer(this.asset);

  @override
  Future<void> preload() =>
      _disposed ? Future.value() : _initializing ??= _prepare();

  Future<void> _prepare() async {
    final player = _player = AudioPlayer()..audioCache = _cache;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      if (_disposed) return;
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.game,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      if (_disposed) return;
      await player.setSource(AssetSource(asset));
    } catch (_) {
      await _release();
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    if (!_disposed) await _player?.resume();
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> setVolume(double volume) async => _player?.setVolume(volume);

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    try {
      await _initializing;
    } catch (_) {
      // 初始化失败已清理资源，退出仍需正常完成。
    }
    await _release();
  }

  Future<void> _release() async {
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } finally {
      final files = _cache.loadedFiles.values.toList();
      _cache.loadedFiles.clear();
      if (!kIsWeb) {
        for (final uri in files) {
          final file = File.fromUri(uri);
          if (await file.exists()) await file.delete();
        }
      }
    }
  }
}

/// 同时满足游戏运行、页面可见和用户开启三个条件才播放。
class BackgroundMusicController {
  final String project;
  final MusicPlayer _player;
  final AudioPreferences _preferences;
  final bool _ownsPreferences;
  ValueNotifier<bool> get enabled => _preferences.musicEnabled;
  ValueNotifier<double> get volume => _preferences.musicVolume;
  late final Future<void> ready;
  Future<void> _commands = Future.value();
  Future<void>? _disposing;
  bool _initialized = false;
  bool _active = true;
  bool _playing = false;
  bool _audible = false;
  bool _disposed = false;
  bool _loggedError = false;
  double? _appliedVolume;

  BackgroundMusicController({
    required this.project,
    required MusicPlayer player,
    JsonStore? store,
    AudioPreferences? preferences,
  }) : _player = player,
       _preferences =
           preferences ??
           (store == null
               ? AudioPreferences.instance
               : AudioPreferences(store: store)),
       _ownsPreferences = preferences == null && store != null {
    enabled.addListener(_sync);
    volume.addListener(_sync);
    ready = _initialize();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!_loggedError) {
        _loggedError = true;
        debugPrint('[GameMusic] 音乐不可用，游戏继续运行: $error');
      }
    }
  }

  Future<void> _initialize() async {
    await _preferences.ready;
    if (_disposed) return;
    await _guard(() async {
      await _player.preload();
      _initialized = true;
    });
    _sync();
  }

  void _sync() {
    if (_disposed) return;
    // 命令串行执行，但执行时读取最新状态，快速暂停或静音不会积压旧播放。
    _commands = _commands.then(
      (_) => _guard(() async {
        if (_disposed || !_initialized) return;
        if (_appliedVolume != volume.value) {
          final requestedVolume = volume.value;
          await _player.setVolume(requestedVolume);
          _appliedVolume = requestedVolume;
        }
        if (_disposed) return;
        final audible = _active && _playing && enabled.value;
        if (audible == _audible) return;
        if (audible) {
          await _player.resume();
        } else {
          await _player.pause();
        }
        _audible = audible;
      }),
    );
  }

  void setActive(bool value) {
    if (_disposed || _active == value) return;
    _active = value;
    _sync();
  }

  void setPlaying(bool value) {
    if (_disposed || _playing == value) return;
    _playing = value;
    _sync();
  }

  void setEnabled(bool value) {
    if (_disposed) return;
    _preferences.setMusicEnabled(value);
    _sync();
  }

  void setVolume(double value) {
    if (_disposed || !value.isFinite) return;
    _preferences.setMusicVolume(value);
    _sync();
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    enabled.removeListener(_sync);
    volume.removeListener(_sync);
    await ready;
    await _commands;
    await _guard(_player.dispose);
    if (_ownsPreferences) {
      await _preferences.dispose();
    } else {
      await _preferences.flush();
    }
  }
}
