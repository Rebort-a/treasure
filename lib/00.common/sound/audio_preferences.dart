import 'package:flutter/foundation.dart';

import 'audio_settings_store.dart';
import '../service/json_store.dart';

/// 所有游戏共用声音和震动偏好，页面仅管理播放器生命周期。
class AudioPreferences {
  static final instance = AudioPreferences();

  final JsonStore _store;
  final soundEnabled = ValueNotifier(true);
  final voiceEnabled = ValueNotifier(true);
  final musicEnabled = ValueNotifier(true);
  final musicVolume = ValueNotifier(.32);
  final vibrationEnabled = ValueNotifier(true);
  late final Future<void> ready;
  Future<void> _writes = Future.value();
  Future<void>? _disposing;
  bool _disposed = false;
  bool _loggedError = false;
  int _soundVersion = 0;
  int _voiceVersion = 0;
  int _musicVersion = 0;
  int _volumeVersion = 0;
  int _vibrationVersion = 0;

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
    final voiceVersion = _voiceVersion;
    final musicVersion = _musicVersion;
    final volumeVersion = _volumeVersion;
    final vibrationVersion = _vibrationVersion;
    var savedAudio = <String, dynamic>{};
    var savedVoice = <String, dynamic>{};
    var audioLoaded = false;
    var voiceLoaded = false;
    await Future.wait([
      _guard(() async {
        final data = await _store.read('audio');
        savedAudio = data;
        audioLoaded = true;
        if (soundVersion == _soundVersion && data['enabled'] is bool) {
          soundEnabled.value = data['enabled'] as bool;
        }
      }),
      _guard(() async {
        savedVoice = await _store.read('voice');
        voiceLoaded = true;
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
      _guard(() async {
        final data = await _store.read('vibration');
        if (vibrationVersion == _vibrationVersion && data['enabled'] is bool) {
          vibrationEnabled.value = data['enabled'] as bool;
        }
      }),
    ]);
    if (voiceVersion == _voiceVersion) {
      // 旧版本把语音并入音效；没有独立设置时沿用旧值，避免升级后意外出声。
      final saved = savedVoice['enabled'] is bool
          ? savedVoice['enabled']
          : savedAudio['enabled'];
      if (saved is bool) voiceEnabled.value = saved;
    }
    if (audioLoaded && voiceLoaded && savedVoice['enabled'] is! bool) {
      // 首次拆分后固定语音偏好，后续只切换音效也不能改变下次启动的语音状态。
      final value = voiceEnabled.value;
      await _guard(() => _store.write('voice', {'enabled': value}));
    }
  }

  void setSoundEnabled(bool value) {
    if (_disposed) return;
    _soundVersion++;
    soundEnabled.value = value;
    _persistEnabled('audio', value);
  }

  void setVoiceEnabled(bool value) {
    if (_disposed) return;
    _voiceVersion++;
    voiceEnabled.value = value;
    _persistEnabled('voice', value);
  }

  void setVibrationEnabled(bool value) {
    if (_disposed) return;
    _vibrationVersion++;
    vibrationEnabled.value = value;
    _persistEnabled('vibration', value);
  }

  void _persistEnabled(String name, bool value) {
    _writes = _writes.then((_) async {
      await ready;
      await _guard(() => _store.write(name, {'enabled': value}));
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

  Future<void> flush() async {
    await ready;
    await _writes;
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await ready;
    await _writes;
    soundEnabled.dispose();
    voiceEnabled.dispose();
    musicEnabled.dispose();
    musicVolume.dispose();
    vibrationEnabled.dispose();
  }
}
