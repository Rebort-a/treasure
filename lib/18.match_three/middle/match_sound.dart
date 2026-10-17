import '../../00.common/game/game_sound.dart';

/// 仅用于本机展示，不序列化，也不参与联机判定。
enum MatchSound {
  reset,
  select,
  swap,
  invalid,
  clear1,
  clear2,
  clear3,
  clear4,
  line,
  bomb,
  rainbow,
  ice,
  fall,
  entrance,
  appear,
  transform,
  bonus,
  won,
  lost;

  /// 通用短音效复用共享资源，三消事件语义与触发逻辑保持独立。
  String get asset => switch (this) {
    select => GameSound.tap.asset,
    swap => GameSound.flip.asset,
    invalid => GameSound.error.asset,
    bomb => GameSound.explosion.asset,
    fall => GameSound.move.asset,
    transform => GameSound.cast.asset,
    _ => 'audio/effects/$name.wav',
  };
}

/// 每次创建新事件，允许连续播放相同种类的音效。
class MatchSoundEvent {
  final MatchSound sound;

  const MatchSoundEvent(this.sound);
}
