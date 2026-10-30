import '../../00.common/sound/sound_manager.dart';

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
    select => Sound.tap.asset,
    swap => Sound.flip.asset,
    invalid => Sound.error.asset,
    bomb => Sound.explosion.asset,
    fall => Sound.move.asset,
    transform => Sound.cast.asset,
    _ => 'audio/effects/$name.wav',
  };
}

/// 每次创建新事件，允许连续播放相同种类的音效。
class MatchSoundEvent {
  final MatchSound sound;

  const MatchSoundEvent(this.sound);
}
