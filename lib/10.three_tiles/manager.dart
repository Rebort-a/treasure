import 'dart:math';
import 'package:flutter/material.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

class Manager {
  /// 虚拟棋牌和卡片尺寸，用来做层级判断
  /// 在显示时会根据真实尺寸动态映射
  static const double boardVirtualWidth = 600;
  static const double boardVirtualHeight = 800;
  static const double cardVirtualSize = 80;

  final Random _random = Random(); // 随机数生成器
  late final TimerCounter _timer; // 计时器

  Difficulty _difficulty = Difficulty.medium; // 游戏难度默认为中等
  bool _isGameOver = false; // 游戏进展

  final ListNotifier<CardNotifier> cards = ListNotifier([]); // 场上的卡片
  final ListNotifier<CardNotifier> selectedCards = ListNotifier([]); // 选中的卡片
  final ListNotifier<PropType> props = ListNotifier([]); //道具袋
  final ValueNotifier<int> elapsed = ValueNotifier(0); // 秒数

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {}); // 弹窗器

  Manager() {
    _initTimer();
    _initGame();
  }

  void _initTimer() {
    _timer = TimerCounter(const Duration(seconds: 1), (tick) {
      elapsed.value = tick;
    });
  }

  void _initGame() {
    // 初始化道具区
    props
      ..clear()
      ..addAll([PropType.removeThree, PropType.reshuffle, PropType.hint]);

    // 根据难度生成卡片
    _generateCards((_difficulty.index + 1) * 30);

    // 启动计时器
    _timer.restart();

    // 更新进展
    _isGameOver = false;
  }

  void _generateCards(int count) {
    final List<CardPosition> positionPool = _getPositions(count); // 坐标池
    final List<CardType> cardPool = CardType.values.toList()
      ..shuffle(_random); // 卡片池

    // 从卡片池中取出卡片，赋予坐标，每种卡片一次三个
    int posIndex = 0;
    while (posIndex < count) {
      for (final t in cardPool) {
        for (int i = 0; i < 3; i++) {
          if (posIndex >= count) break;
          cards.add(
            CardNotifier(GameCard(type: t, position: positionPool[posIndex])),
          );
          posIndex++;
        }
      }
    }

    _updateCardVisibility();
  }

  List<CardPosition> _getPositions(int count) {
    final int layerCount = (count / 15).ceil() + 1; // 层级数量
    final List<CardPosition> positions = <CardPosition>[];

    for (int z = 0; z < layerCount; z++) {
      final shrink = z * 0.08;
      final xMin = (boardVirtualWidth * shrink / 2);
      final xMax =
          boardVirtualWidth -
          cardVirtualSize -
          (boardVirtualWidth * shrink / 2);
      final yMin = (boardVirtualHeight * shrink / 2);
      final yMax =
          boardVirtualHeight -
          cardVirtualSize -
          (boardVirtualHeight * shrink / 2);

      final quota = (count / layerCount).ceil(); // 每层配额
      for (int i = 0; i < quota && positions.length < count; i++) {
        final x = xMin + _random.nextDouble() * (xMax - xMin);
        final y = yMin + _random.nextDouble() * (yMax - yMin);
        positions.add(CardPosition(x: x.round(), y: y.round(), z: z));
      }
    }
    return positions;
  }

  void _updateCardVisibility() {
    final int cardCount = cards.length;
    if (cardCount == 0) return;
    if (cardCount == 1) {
      cards.first.changeEnable(true);
      return;
    }

    // 1. 预计算所有卡片的矩形区域和中心坐标（减少重复计算）
    final List<Rect> cardRects = List.generate(cardCount, (i) {
      final card = cards[i];
      return Rect.fromLTWH(
        card.position.x.toDouble(),
        card.position.y.toDouble(),
        cardVirtualSize,
        cardVirtualSize,
      );
    });

    final List<Offset> centers = List.generate(
      cardCount,
      (i) => cardRects[i].center,
    );
    final double maxOverlapDistSquared = 2 * cardVirtualSize * cardVirtualSize;

    // 2. 重置所有卡片状态（避免上次状态影响）
    for (final card in cards) {
      card.changeEnable(true);
    }

    // 3. 创建网格分区（网格大小设为卡片大小，减少跨网格检查）
    final double gridSize = cardVirtualSize;
    final Map<(int, int), List<int>> grid = {};

    // 4. 所有卡片加入网格
    for (int k = 0; k < cardCount; k++) {
      final rect = cardRects[k];
      // 计算卡片占据的网格范围
      final int minGridX = (rect.left / gridSize).floor();
      final int minGridY = (rect.top / gridSize).floor();
      final int maxGridX = (rect.right / gridSize).floor();
      final int maxGridY = (rect.bottom / gridSize).floor();

      // 加入所有覆盖的网格
      for (int gx = minGridX; gx <= maxGridX; gx++) {
        for (int gy = minGridY; gy <= maxGridY; gy++) {
          grid.putIfAbsent((gx, gy), () => []).add(k);
        }
      }
    }

    // 5. 检查重叠（只检查同网格及相邻网格的上层卡片）
    for (int i = 0; i < cardCount; i++) {
      final currentCard = cards[i];
      if (!currentCard.enable) continue; // 已被覆盖的卡片无需再检查

      final currentRect = cardRects[i];
      final currentCenter = centers[i];

      // 计算当前卡片所在的网格范围
      final int minGridX = (currentRect.left / gridSize).floor();
      final int minGridY = (currentRect.top / gridSize).floor();
      final int maxGridX = (currentRect.right / gridSize).floor();
      final int maxGridY = (currentRect.bottom / gridSize).floor();

      // 检查当前网格及相邻网格（3x3范围）
      outerLoop:
      for (int gx = minGridX - 1; gx <= maxGridX + 1; gx++) {
        for (int gy = minGridY - 1; gy <= maxGridY + 1; gy++) {
          final candidates = grid[(gx, gy)];
          if (candidates == null) continue;

          // 只检查上层卡片（j > i）
          for (final j in candidates) {
            if (j <= i) continue;

            // 快速距离过滤
            final dx = currentCenter.dx - centers[j].dx;
            final dy = currentCenter.dy - centers[j].dy;
            if (dx * dx + dy * dy > maxOverlapDistSquared) {
              continue;
            }

            // 距离足够近时再检查实际重叠
            if (currentRect.overlaps(cardRects[j])) {
              currentCard.changeEnable(false);
              break outerLoop;
            }
          }
        }
      }
    }
  }

  void selectCard(CardNotifier card) {
    if (_isGameOver || !card.enable) return;
    selectedCards.add(card);
    cards.remove(card);
    _updateCardVisibility();
    _checkForMatches();
    if (cards.isEmpty) _handleGameOver(true);
    if (selectedCards.value.length >= 7) _handleGameOver(false);
  }

  void _checkForMatches() {
    if (selectedCards.value.length < 3) return;
    final groups = <CardType, List<CardNotifier>>{};
    for (final c in selectedCards.value) {
      groups.putIfAbsent(c.type, () => []).add(c);
    }
    for (final group in groups.values) {
      if (group.length >= 3) {
        for (final c in group.take(3).toList()) {
          selectedCards.remove(c);
        }
        return;
      }
    }
  }

  void useProp(PropType prop) {
    if (_isGameOver) return;
    switch (prop) {
      case PropType.removeThree:
        _removeThreeRandomCards();
        break;
      case PropType.reshuffle:
        _reshuffleCards();
        break;
      case PropType.hint:
        _showHint();
        break;
    }
    props.remove(prop);
  }

  void _removeThreeRandomCards() {
    for (int i = 0; i < 3 && cards.isNotEmpty; i++) {
      cards.removeLast();
    }
    _updateCardVisibility();
  }

  void _reshuffleCards() {
    final newPositions = _getPositions(cards.length);
    for (int i = 0; i < cards.length; i++) {
      cards[i].changePosition(newPositions[i]);
    }

    _updateCardVisibility();
  }

  void _showHint() {
    if (cards.isEmpty) return;

    // 获取最后一个卡片的类型
    final targetType = cards.last.type;
    final List<CardNotifier> matchedCards = [];

    // 从后往前遍历卡片，寻找相同类型的卡片
    for (int i = cards.length - 1; i >= 0; i--) {
      final currentCard = cards[i];
      if (currentCard.type == targetType) {
        matchedCards.add(currentCard);
        if (matchedCards.length >= 3) {
          break;
        }
      }
    }

    // 高亮找到的卡片
    for (final card in matchedCards) {
      card.changeHint(true);
    }
  }

  void _handleGameOver(bool victory) {
    _timer.stop();
    _isGameOver = true;
    _showGameOverDialog(victory);
  }

  void _showGameOverDialog(bool victory) {
    pageNavigator.value = (context) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(S.gameOver),
          content: Text(
            victory
                ? S.difficultyTimeSeconds(_difficulty.label, elapsed.value)
                : S.youLost,
          ),
          actions: [
            TextButton(
              child: Text(S.ok),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    };
  }

  void showDifficultyDialog() {
    pageNavigator.value = (context) => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.chooseDifficulty),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Difficulty.values
              .map((e) => _buildDifficultyTile(context, e))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDifficultyTile(BuildContext context, Difficulty difficulty) {
    return RadioMenuButton<Difficulty>(
      value: difficulty,
      groupValue: _difficulty,
      onChanged: (Difficulty? value) {
        if (value == null) return;
        Navigator.pop(context);
        _changeDifficulty(value);
      },
      child: Text(difficulty.label),
    );
  }

  void _changeDifficulty(Difficulty d) {
    if (d != _difficulty) {
      _difficulty = d;
      restartGame();
    }
  }

  void restartGame() {
    _clearUp();
    _initGame();
  }

  void leavePage() {
    _clearUp();
    pageNavigator.value = (context) {
      Navigator.pop(context);
    };
  }

  void _clearUp() {
    _timer.stop();
    cards.clear();
    props.clear();
    selectedCards.clear();
    _isGameOver = true;
    elapsed.value = 0;
  }
}

extension on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return S.easy;
      case Difficulty.medium:
        return S.medium;
      case Difficulty.hard:
        return S.hard;
    }
  }
}
