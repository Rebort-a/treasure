import 'dart:math';

import 'package:flutter/foundation.dart';

import '../00.common/sound/sound_manager.dart';

import '../00.common/model/notifiers.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

class MemoryManager with SoundEmitter {
  late final TimerCounter _timer;

  bool _disposed = false;
  bool _leaving = false;
  int _operation = 0;

  int _difficulty = 6; // 牌对数

  final ListNotifier<MemoryCardNotifier> cards = ListNotifier([]);
  final ValueNotifier<int> firstIndex = ValueNotifier(-1);
  final ValueNotifier<bool> isMatching = ValueNotifier(false);
  final ValueNotifier<int> matchedCount = ValueNotifier(0);
  final ValueNotifier<int> elapsed = ValueNotifier(0);
  final ValueNotifier<String> displayInfo = ValueNotifier('');
  final ValueNotifier<bool> gameOver = ValueNotifier(false);

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
    if (_disposed || _leaving) return;
    _operation++;
    emitSound(Sound.reset);
    _timer.stop();
    _timer.setTick(0);
    elapsed.value = 0;

    final rng = Random();
    final patterns = List<String>.from(cardPatterns)..shuffle(rng);
    final chosen = patterns.take(_difficulty).toList();

    final previous = cards.value;
    int id = 0;
    final next = <MemoryCardNotifier>[];
    for (final p in chosen) {
      next.add(MemoryCardNotifier(MemoryCard(id: id++, pattern: p)));
      next.add(MemoryCardNotifier(MemoryCard(id: id++, pattern: p)));
    }
    next.shuffle(rng);
    // 一次替换列表，旧操作已由局次失效。
    // ChangeNotifier 释放后仍允许移除监听，视图下一次重建可安全解绑旧牌。
    cards.value = next;
    for (final card in previous) {
      card.dispose();
    }

    firstIndex.value = -1;
    isMatching.value = false;
    matchedCount.value = 0;
    gameOver.value = false;
    displayInfo.value = _displayText;
  }

  void resetGame() => _initGame();

  /// 翻牌主入口（异步时序，isMatching 锁防重入）
  Future<void> flipCard(int i) async {
    if (_disposed || _leaving || gameOver.value || isMatching.value) return;
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
    emitSound(Sound.flip);
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
    final operation = ++_operation;
    isMatching.value = true;
    await Future.delayed(const Duration(milliseconds: 500));

    // 旧局或退出后的操作不能改写当前局的选择和配对锁。
    if (!_isCurrentOperation(operation)) return;

    if (cardA.pattern == cardB.pattern) {
      // 匹配成功：两张同时再展示 50ms 后永久移除
      await Future.delayed(const Duration(milliseconds: 50));
      if (!_isCurrentOperation(operation)) return;
      cardA.changeState(CardState.matched);
      cardB.changeState(CardState.matched);
      matchedCount.value++;
      emitSound(Sound.success);
      displayInfo.value = _displayText;
      if (matchedCount.value == _difficulty) _handleGameOver();
    } else {
      // 匹配失败：翻回背面
      emitSound(Sound.error);
      cardA.changeState(CardState.hidden);
      cardB.changeState(CardState.hidden);
    }
    firstIndex.value = -1;
    isMatching.value = false;
  }

  bool _isCurrentOperation(int operation) =>
      !_disposed && !_leaving && operation == _operation;

  void _handleGameOver() {
    emitSound(Sound.win);
    _timer.stop();
    gameOver.value = true;
    displayInfo.value = _displayText;
  }

  String get _displayText => gameOver.value
      ? S.timeTaken(_timer.tick)
      : S.remainingPairs(_difficulty - matchedCount.value);

  int get difficulty => _difficulty;
  int get minDifficulty => 4;
  int get maxDifficulty => cardPatterns.length < 16 ? cardPatterns.length : 16;

  void changeDifficulty(int value) {
    if (_disposed || _leaving) return;
    if (value != _difficulty) {
      _difficulty = value;
      resetGame();
    }
  }

  void leavePage() {
    if (_disposed || _leaving) return;
    _leaving = true;
    _operation++;
    _timer.stop();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operation++;
    _timer.dispose();
    disposeAudioEvents();
    for (final card in cards.value) {
      card.dispose();
    }
    cards.dispose();
    firstIndex.dispose();
    isMatching.dispose();
    matchedCount.dispose();
    elapsed.dispose();
    displayInfo.dispose();
    gameOver.dispose();
  }
}
