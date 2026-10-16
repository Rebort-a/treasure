import 'package:flutter/foundation.dart';

import 'audio_settings_store.dart';
import 'json_store.dart';

/// 所有游戏共用一份音频偏好，页面仅管理播放器生命周期。
class AudioPreferences {
  static final instance = AudioPreferences();

  final JsonStore _store;
  final soundEnabled = ValueNotifier(true);
  final musicEnabled = ValueNotifier(true);
  final musicVolume = ValueNotifier(.32);
  late final Future<void> ready;
  Future<void> _writes = Future.value();
  Future<void>? _disposing;
  bool _disposed = false;
  bool _loggedError = false;
  int _soundVersion = 0;
  int _musicVersion = 0;
  int _volumeVersion = 0;

  AudioPreferences({JsonStore? store})
    : _store = store ?? const AudioSettingsStore() {
    ready = _load();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!_loggedError) {
        _loggedError = true;
        debugPrint('[AudioPreferences] 音频设置不可用，保留当前设置: $error');
      }
    }
  }

  Future<void> _load() async {
    final soundVersion = _soundVersion;
    final musicVersion = _musicVersion;
    final volumeVersion = _volumeVersion;
    await Future.wait([
      _guard(() async {
        final data = await _store.read('audio');
        if (soundVersion == _soundVersion && data['enabled'] is bool) {
          soundEnabled.value = data['enabled'] as bool;
        }
      }),
      _guard(() async {
        final data = await _store.read('music');
        if (musicVersion == _musicVersion && data['enabled'] is bool) {
          musicEnabled.value = data['enabled'] as bool;
        }
        final saved = data['volume'];
        if (volumeVersion == _volumeVersion && saved is num && saved.isFinite) {
          musicVolume.value = saved.toDouble().clamp(0, 1);
        }
      }),
    ]);
  }

  void setSoundEnabled(bool value) {
    if (_disposed) return;
    _soundVersion++;
    soundEnabled.value = value;
    _writes = _writes.then((_) async {
      await ready;
      await _guard(() => _store.write('audio', {'enabled': value}));
    });
  }

  void setMusicEnabled(bool value) {
    if (_disposed) return;
    _musicVersion++;
    musicEnabled.value = value;
    _persistMusic();
  }

  void setMusicVolume(double value) {
    if (_disposed || !value.isFinite) return;
    _volumeVersion++;
    musicVolume.value = value.clamp(0, 1);
    _persistMusic();
  }

  void _persistMusic() {
    _writes = _writes.then((_) async {
      // 等读取结束后保存，修改开关不会覆盖尚未恢复的音乐音量。
      await ready;
      await _guard(
        () => _store.write('music', {
          'enabled': musicEnabled.value,
          'volume': musicVolume.value,
        }),
      );
    });
  }

  Future<void> flush() => _writes;

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await ready;
    await _writes;
    soundEnabled.dispose();
    musicEnabled.dispose();
    musicVolume.dispose();
  }
}
