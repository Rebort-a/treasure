import 'package:flutter/foundation.dart';

/// 本机表现事件，不写入存档、规则内核或网络协议。
enum Sound {
  reset,
  tap,
  move,
  flip,
  capture,
  success,
  error,
  shoot,
  hit,
  pickup,
  jump,
  cast,
  explosion,
  win,
  lose;

  String get asset => 'audio/effects/$name.wav';
}

class SoundEvent {
  final Sound sound;

  const SoundEvent(this.sound);
}

/// Manager 只发布事件；未挂载游戏页面时不会创建播放器或发声。
mixin SoundEmitter {
  final audioEvents = ValueNotifier<SoundEvent?>(null);
  bool _audioDisposed = false;

  void emitSound(Sound sound) {
    if (!_audioDisposed) audioEvents.value = SoundEvent(sound);
  }

  void disposeAudioEvents() {
    if (_audioDisposed) return;
    _audioDisposed = true;
    audioEvents.dispose();
  }
}
