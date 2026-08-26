import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/tool/notifiers.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/tool/storage_service.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/widget/effect/magic_celebration.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

class MemoryManager {
  late final TimerCounter _timer;

  int _difficulty = 6; // 牌对数
  bool _isGameOver = false;
  Future<int>? _bestTimeFuture;

  final ListNotifier<MemoryCardNotifier> cards = ListNotifier([]);
  final ValueNotifier<int> firstIndex = ValueNotifier(-1);
  final ValueNotifier<bool> isMatching = ValueNotifier(false);
  final ValueNotifier<int> matchedCount = ValueNotifier(0);
  final ValueNotifier<int> elapsed = ValueNotifier(0);

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  MemoryManager() {
    _initTimer();
    _initGame();
  }

  void _initTimer() {
    _timer = TimerCounter(const Duration(seconds: 1), (tick) {
      elapsed.value = tick;
    });
  }

  /// 初始化棋盘：取 _difficulty 种图案各 2 张洗牌填入；计时归零但不启动（首翻启动）
  void _initGame() {
    _timer.stop();
    _timer.setTick(0);
    elapsed.value = 0;

    final rng = Random();
    final patterns = List<String>.from(cardPatterns)..shuffle(rng);
    final chosen = patterns.take(_difficulty).toList();

    cards.clear();
    int id = 0;
    for (final p in chosen) {
      cards.add(MemoryCardNotifier(MemoryCard(id: id++, pattern: p)));
      cards.add(MemoryCardNotifier(MemoryCard(id: id++, pattern: p)));
    }
    // 洗牌（按 id 打乱）
    final list = cards.value.toList()..shuffle(rng);
    cards.clear();
    cards.addAll(list);

    firstIndex.value = -1;
    isMatching.value = false;
    matchedCount.value = 0;
    _isGameOver = false;
  }

  int get difficulty => _difficulty;

  void resetGame() => _initGame();

  /// 翻牌主入口（异步时序，isMatching 锁防重入）
  Future<void> flipCard(int i) async {
    if (_isGameOver || isMatching.value) return;
    if (i < 0 || i >= cards.length) return;
    final card = cards[i];

    // 再点当前已翻开的第一张：取消选择翻回（须在 state guard 之前，否则死代码）
    if (i == firstIndex.value && card.state == CardState.revealed) {
      card.changeState(CardState.hidden);
      firstIndex.value = -1;
      return;
    }

    if (card.state != CardState.hidden) return; // matched 或已展示

    // 翻开这张牌（触发翻面动画 0→1）
    card.changeState(CardState.revealed);
    if (!_timer.isRunning) _timer.start(); // 首次翻牌启动计时

    // 第一步：无展示牌时，此牌停留作参考
    if (firstIndex.value == -1) {
      firstIndex.value = i;
      return;
    }

    // 第二步：翻开第二张，两张同时展示约 500ms 后判定
    final a = firstIndex.value;
    final b = i;
    final cardA = cards[a];
    final cardB = cards[b];
    isMatching.value = true;
    await Future.delayed(const Duration(milliseconds: 500));

    // await 期间若重开/改难度重建了 cards，索引失效，中止判定
    if (a >= cards.length ||
        b >= cards.length ||
        !identical(cards[a], cardA) ||
        !identical(cards[b], cardB) ||
        cards[a].state != CardState.revealed ||
        cards[b].state != CardState.revealed) {
      firstIndex.value = -1;
      isMatching.value = false;
      return;
    }

    if (cardA.pattern == cardB.pattern) {
      // 匹配成功：两张同时再展示 50ms 后永久移除
      await Future.delayed(const Duration(milliseconds: 50));
      if (a >= cards.length ||
          b >= cards.length ||
          !identical(cards[a], cardA) ||
          !identical(cards[b], cardB) ||
          cards[a].state != CardState.revealed ||
          cards[b].state != CardState.revealed) {
        firstIndex.value = -1;
        isMatching.value = false;
        return;
      }
      cardA.changeState(CardState.matched);
      cardB.changeState(CardState.matched);
      matchedCount.value++;
      if (matchedCount.value == _difficulty) _handleGameOver();
    } else {
      // 匹配失败：翻回背面
      cardA.changeState(CardState.hidden);
      cardB.changeState(CardState.hidden);
    }
    firstIndex.value = -1;
    isMatching.value = false;
  }

  Future<void> _handleGameOver() async {
    _timer.stop();
    _isGameOver = true;
    await _saveBestTime();
    _bestTimeFuture = _readBestTime(); // 缓存 Future，避免 FutureBuilder 每次重建重读
    _showCompletionDialog();
  }

  /// 保存最佳用时（按难度，仿 08.sudoku）
  Future<void> _saveBestTime() async {
    final data = await StorageService.instance.read('memory_best');
    final key = 'diff_$_difficulty';
    final best = data[key] as int? ?? 0;
    if (best == 0 || _timer.tick < best) {
      data[key] = _timer.tick;
      await StorageService.instance.write('memory_best', data);
    }
  }

  void _showCompletionDialog() {
    pageNavigator.value = (context) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.congratulations,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                S.difficultyTime(
                  '$_difficulty',
                  TimerCounter.formatDuration(_timer.tick),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: _bestTimeFuture,
                builder: (_, snap) {
                  final best = snap.data ?? 0;
                  if (best == 0) return const SizedBox.shrink();
                  return Text(
                    '${S.bestTimeLabel}: ${TimerCounter.formatDuration(best)}',
                    style: const TextStyle(color: Colors.grey),
                  );
                },
              ),
              const SizedBox(height: 12),
              const MagicCelebrationAnimation(),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  resetGame();
                },
                child: Text(S.startNewGame),
              ),
            ],
          ),
        ),
      );
    };
  }

  Future<int> _readBestTime() async {
    final data = await StorageService.instance.read('memory_best');
    return data['diff_$_difficulty'] as int? ?? 0;
  }

  /// 难度设置对话框（牌对数 4~16）
  void showSelector() {
    pageNavigator.value = (context) => DialogTemplate.intSliderDialog(
      context: context,
      title: S.setDifficulty,
      sliderData: IntSliderData(
        start: 4,
        end: cardPatterns.length < 16 ? cardPatterns.length : 16,
        value: _difficulty,
        step: 1,
      ),
      onConfirm: _changeDifficulty,
    );
  }

  void _changeDifficulty(int value) {
    if (value != _difficulty) {
      _difficulty = value;
      resetGame();
    }
  }

  void leavePage() {
    _timer.stop();
    pageNavigator.value = (context) {
      Navigator.pop(context);
    };
  }
}
