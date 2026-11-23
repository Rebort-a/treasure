import 'package:material_ui/material_ui.dart';

/// 游戏难度
enum Difficulty { easy, medium, hard }

/// 基础数据定义
enum CardType {
  sheep,
  grass,
  tree,
  flower,
  cloud,
  sun,
  moon,
  star,
  mountain,
  river,
  house,
  fence,
  carrot,
  wheat,
  mushroom,
}

/// 卡片信息复合类型，包含emoji和颜色
class CardInfo {
  final String emoji;
  final int color;

  const CardInfo({required this.emoji, required this.color});
}

/// 卡片扩展方法
extension CardTypeExt on CardType {
  /// 获取卡片对应的信息（emoji和颜色）
  CardInfo get info {
    switch (this) {
      case CardType.sheep:
        return const CardInfo(emoji: "🐑", color: 0xFFFFF3E0);
      case CardType.grass:
        return const CardInfo(emoji: "🌱", color: 0xFFE8F5E9);
      case CardType.tree:
        return const CardInfo(emoji: "🌳", color: 0xFFC8E6C9);
      case CardType.flower:
        return const CardInfo(emoji: "🌸", color: 0xFFFCE4EC);
      case CardType.cloud:
        return const CardInfo(emoji: "☁️", color: 0xFFEBF5FB);
      case CardType.sun:
        return const CardInfo(emoji: "☀️", color: 0xFFFFFDE7);
      case CardType.moon:
        return const CardInfo(emoji: "🌙", color: 0xFFE8EAF6);
      case CardType.star:
        return const CardInfo(emoji: "⭐", color: 0xFFF3E5F5);
      case CardType.mountain:
        return const CardInfo(emoji: "⛰️", color: 0xFFEEEEEE);
      case CardType.river:
        return const CardInfo(emoji: "🌊", color: 0xFFE3F2FD);
      case CardType.house:
        return const CardInfo(emoji: "🏠", color: 0xFFFFEBEE);
      case CardType.fence:
        return const CardInfo(emoji: "🚧", color: 0xFFFFF3E0);
      case CardType.carrot:
        return const CardInfo(emoji: "🥕", color: 0xFFE8F5E9);
      case CardType.wheat:
        return const CardInfo(emoji: "🌾", color: 0xFFFFF8E1);
      case CardType.mushroom:
        return const CardInfo(emoji: "🍄", color: 0xFFFCE4EC);
    }
  }
}

/// 卡片位置信息
class CardPosition {
  final int x;
  final int y;
  final int z; // 层级，用于绘制顺序

  CardPosition({required this.x, required this.y, required this.z});
}

/// 游戏卡片
class GameCard {
  final CardType _type; // 私有字段，类型一旦确定不可修改
  CardPosition _position; // 私有字段，只能通过内部方法修改
  bool _enable; // 私有字段
  bool _hint; // 私有字段

  CardType get type => _type;
  CardPosition get position => _position;
  bool get enable => _enable;
  bool get hint => _hint;

  GameCard({required CardType type, required CardPosition position})
    : _type = type,
      _position = position,
      _enable = true,
      _hint = false;
}

class CardNotifier extends ValueNotifier<GameCard> {
  CardNotifier(super.value);

  CardType get type => value.type;
  CardPosition get position => value.position;
  bool get enable => value.enable;
  bool get hint => value.hint;

  void changePosition(CardPosition position) {
    if (position != value._position) {
      value._position = position;
      notifyListeners();
    }
  }

  void changeEnable(bool enable) {
    if (enable != value._enable) {
      value._enable = enable;
      notifyListeners();
    }
  }

  void changeHint(bool hint) {
    if (hint != value._hint) {
      value._hint = hint;
      notifyListeners();
    }
  }
}

/// 道具类型
enum PropType {
  removeThree, // 移除三个随机卡片
  reshuffle, // 重新排列
  hint, // 提示
}

/// 道具扩展
extension PropTypeExt on PropType {
  String get emoji {
    switch (this) {
      case PropType.removeThree:
        return "🔨";
      case PropType.reshuffle:
        return "🔄";
      case PropType.hint:
        return "💡";
    }
  }
}
