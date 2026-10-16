import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'json_store.dart';
import 'audio_preferences.dart';

/// 播放实现必须在 stop 后取消尚未开始的旧请求。
abstract interface class SoundPlayer<T> {
  Future<void> preload();
  Future<void> play(T sound);
  Future<void> stop();
  Future<void> dispose();
}

/// 短音效默认复用四个声道，语音可独占一个声道，避免无限创建原生资源。
class AssetSoundPlayer<T> implements SoundPlayer<T> {
  final Map<T, String> assets;
  final int voiceCount;
  final double volume;
  final bool latestOnly;

  AssetSoundPlayer({
    required this.assets,
    this.voiceCount = 4,
    this.volume = .65,
    this.latestOnly = false,
  }) : assert(voiceCount > 0),
       assert(volume >= 0 && volume <= 1);
  final AudioCache _cache = AudioCache(prefix: 'assets/');
  final List<AudioPlayer> _voices = [];
  Future<void>? _initializing;
  Future<void> _tail = Future.value();
  Future<void>? _disposing;
  int _nextVoice = 0;
  int _epoch = 0;
  bool _disposed = false;

  @override
  Future<void> preload() =>
      _disposed ? Future.value() : _initializing ??= _prepare();

  Future<void> _prepare() async {
    try {
      await _cache.loadAll(assets.values.toList());
      for (var i = 0; i < voiceCount && !_disposed; i++) {
        final player = AudioPlayer()..audioCache = _cache;
        _voices.add(player);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(volume);
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              audioFocus: AndroidAudioFocus.none,
              usageType: AndroidUsageType.game,
            ),
            // 遵循系统静音开关，同时不打断用户正在播放的其他音频。
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );
      }
    } catch (_) {
      await _release();
      rethrow;
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    // 单次播放失败不能毒化队列，也不能影响后续的停止和释放。
    _tail = result.catchError((Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> play(T sound) {
    // 语音只保留最新请求，过时的异步加载不能在下一句之后恢复播放。
    if (latestOnly) _epoch++;
    final epoch = _epoch;
    final requestedAt = DateTime.now();
    return _enqueue(() async {
      // 最新语音已通过代次淘汰旧请求，不能再被短音效的排队时限吞掉。
      if (_disposed ||
          epoch != _epoch ||
          _voices.isEmpty ||
          (!latestOnly &&
              DateTime.now().difference(requestedAt) >
                  const Duration(milliseconds: 200))) {
        return;
      }
      final player = _voices[_nextVoice++ % _voices.length];
      await player.stop();
      if (_disposed || epoch != _epoch) return;
      await player.setSource(AssetSource(assets[sound]!));
      if (_disposed || epoch != _epoch) return;
      await player.resume();
    });
  }

  @override
  Future<void> stop() {
    _epoch++;
    return _enqueue(() async {
      await Future.wait([for (final player in _voices) player.stop()]);
    });
  }

  Future<void> _release() async {
    final voices = _voices.toList();
    _voices.clear();
    try {
      await Future.wait([for (final player in voices) player.dispose()]);
    } finally {
      // 插件的 clearAll 使用 POSIX 路径；按文件 URI 删除才能兼容 Windows 盘符。
      final files = _cache.loadedFiles.values.toList();
      _cache.loadedFiles.clear();
      if (!kIsWeb) {
        await Future.wait([
          for (final uri in files)
            () async {
              final file = File.fromUri(uri);
              if (await file.exists()) await file.delete();
            }(),
        ]);
      }
    }
  }

  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _epoch++;
    try {
      await _initializing;
    } catch (_) {
      // 初始化失败已经清理过资源，仍需等待播放队列退出。
    }
    await _enqueue(_release);
  }
}

enum SoundChannel { effects, voice }

/// 管理展示事件、静音和前后台状态，不参与棋盘与网络结算。
class SoundController<T> {
  final Listenable events;
  final T? Function() _currentSound;
  final T? resetSound;
  final int Function(T)? minimumInterval;

  /// 仅指定的提示允许等待首次加载，其他声音仍不积压。
  final bool Function(T)? deferUntilReady;
  final String project;
  final bool persistSettings;
  final SoundChannel channel;
  final SoundPlayer<T> _player;
  late final AudioPreferences? _preferences;
  late final bool _ownsPreferences;
  AudioPreferences? get audioPreferences => _preferences;
  late final ValueNotifier<bool> enabled;
  final Map<T, DateTime> _lastPlayed = {};
  late final Future<void> _readyFuture;
  Future<void> get ready => _readyFuture;
  Future<void>? _disposing;
  bool _ready = false;
  bool _active = true;
  bool _disposed = false;
  bool _loggedError = false;
  T? _pendingSound;

  SoundController({
    required this.events,
    required T? Function() currentSound,
    required SoundPlayer<T> player,
    required this.project,
    this.persistSettings = true,
    this.channel = SoundChannel.effects,
    this.resetSound,
    this.minimumInterval,
    this.deferUntilReady,
    JsonStore? store,
    AudioPreferences? preferences,
  }) : _currentSound = currentSound,
       _player = player {
    _ownsPreferences = persistSettings && preferences == null && store != null;
    _preferences = persistSettings
        ? preferences ??
              (store == null
                  ? AudioPreferences.instance
                  : AudioPreferences(store: store))
        : null;
    enabled = switch (_preferences) {
      final preferences? =>
        channel == SoundChannel.voice
            ? preferences.voiceEnabled
            : preferences.soundEnabled,
      null => ValueNotifier(true),
    };
    enabled.addListener(_onEnabled);
    events.addListener(_onSound);
    final initial = _currentSound();
    if (initial != null &&
        enabled.value &&
        deferUntilReady?.call(initial) == true) {
      _pendingSound = initial;
    }
    _readyFuture = _initialize();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!_loggedError) {
        _loggedError = true;
        debugPrint('[GameAudio] 音频不可用，游戏继续运行: $error');
      }
    }
  }

  Future<void> _initialize() async {
    await _preferences?.ready;
    if (_disposed) return;
    await _guard(() async {
      await _player.preload();
      if (!_disposed) {
        _ready = true;
        final pending = _pendingSound;
        _pendingSound = null;
        if (pending != null && pending == _currentSound()) _onSound();
      }
    });
  }

  void _onEnabled() {
    if (_disposed || enabled.value) return;
    _pendingSound = null;
    if (_ready) _silence();
  }

  void _onSound() {
    final sound = _currentSound();
    if (_disposed || sound == null) return;
    if (sound == resetSound) {
      _silence();
      return;
    }
    if (!_active || !enabled.value) return;
    if (!_ready) {
      _pendingSound = deferUntilReady?.call(sound) == true ? sound : null;
      return;
    }
    final now = DateTime.now();
    final previous = _lastPlayed[sound];
    final interval = minimumInterval?.call(sound) ?? 90;
    if (previous != null &&
        now.difference(previous).inMilliseconds < interval) {
      return;
    }
    _lastPlayed[sound] = now;
    unawaited(_guard(() => _player.play(sound)));
  }

  void _silence() {
    _pendingSound = null;
    _lastPlayed.clear();
    unawaited(_guard(_player.stop));
  }

  void stop() {
    if (!_disposed) _silence();
  }

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    if (!active) _silence();
  }

  void setEnabled(bool value) {
    if (_disposed) return;
    if (_preferences case final preferences?) {
      if (channel == SoundChannel.voice) {
        preferences.setVoiceEnabled(value);
      } else {
        preferences.setSoundEnabled(value);
      }
    } else {
      enabled.value = value;
    }
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _pendingSound = null;
    events.removeListener(_onSound);
    enabled.removeListener(_onEnabled);
    if (_preferences == null) enabled.dispose();
    await _guard(_player.dispose);
    if (_ownsPreferences) {
      await _preferences?.dispose();
    } else {
      await _preferences?.flush();
    }
  }
}
