import 'package:flutter/foundation.dart';

/// 本机表现事件，不写入存档、规则内核或网络协议。
enum GameSound {
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

class GameSoundEvent {
  final GameSound sound;

  const GameSoundEvent(this.sound);
}

/// Manager 只发布事件；未挂载游戏页面时不会创建播放器或发声。
mixin GameSoundEmitter {
  final audioEvents = ValueNotifier<GameSoundEvent?>(null);
  bool _audioDisposed = false;

  void emitSound(GameSound sound) {
    if (!_audioDisposed) audioEvents.value = GameSoundEvent(sound);
  }

  void disposeAudioEvents() {
    if (_audioDisposed) return;
    _audioDisposed = true;
    audioEvents.dispose();
  }
}
