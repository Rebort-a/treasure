import 'package:flutter/foundation.dart';

/// 卡牌状态：hidden 背面朝上 / revealed 正面展示 / matched 已配对移除
enum CardState { hidden, revealed, matched }

/// 记忆翻牌卡牌数据模型
class MemoryCard {
  final int _id;
  final String _pattern;
  CardState _state;

  MemoryCard({
    required int id,
    required String pattern,
    CardState state = CardState.hidden,
  }) : _id = id,
       _pattern = pattern,
       _state = state;

  int get id => _id;
  String get pattern => _pattern;
  CardState get state => _state;
}

/// 单卡状态管理（每张卡一个 ValueNotifier，单卡级刷新）
class MemoryCardNotifier extends ValueNotifier<MemoryCard> {
  MemoryCardNotifier(super.value);

  int get id => value._id;
  String get pattern => value._pattern;
  CardState get state => value._state;

  void changeState(CardState newState) {
    if (value._state != newState) {
      value._state = newState;
      notifyListeners();
    }
  }
}

/// 卡牌图案池
/// 难度上限 16 对，这里提供 20 种以备扩展
List<String> cardPatterns = [
  // 水果
  "🍎", "🍌", "🍇", "🍓", "🥝", "🍊", "🍉", "🍑",
  // 动物
  "🐶", "🐱", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
  // 食物
  "🍔", "🍟", "🍕", "🍩",
];
