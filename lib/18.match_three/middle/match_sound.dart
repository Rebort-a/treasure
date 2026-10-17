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

  String get asset => 'audio/match_three/$name.wav';
}

/// 每次创建新事件，允许连续播放相同种类的音效。
class MatchSoundEvent {
  final MatchSound sound;

  const MatchSoundEvent(this.sound);
}
