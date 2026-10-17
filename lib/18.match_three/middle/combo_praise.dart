import '../base/match_board.dart';

export '../base/match_board.dart' show ComboPraise;

/// 复用内核已有档位，语音资源与展示文字不参与规则和序列化。
extension ComboPraiseAudio on ComboPraise {
  String get label => switch (this) {
    ComboPraise.good => 'Good',
    ComboPraise.great => 'Great',
    ComboPraise.excellent => 'Excellent',
    ComboPraise.amazing => 'Amazing',
    ComboPraise.unbelievable => 'Unbelievable',
  };
  String get asset => 'audio/voice/$name.wav';
}

class ComboPraiseEvent {
  final ComboPraise praise;

  const ComboPraiseEvent(this.praise);
}
