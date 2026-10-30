import 'package:flutter/material.dart';

import '../00.common/sound/sound_manager.dart';

import '../00.common/model/notifiers.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

class GuessManager with SoundEmitter {
  bool _disposed = false;
  late final TimerCounter _timer; // 计时器

  int _difficulty = 6;
  bool _isGameOver = false;

  final ListNotifier<String> correctItems = ListNotifier([]);
  final ListNotifier<String> guessItems = ListNotifier([]);
  final ListNotifier<String> markItems = ListNotifier([]);
  final ValueNotifier<int> selectedItem = ValueNotifier(-1);
  final ValueNotifier<String> displayInfo = ValueNotifier('');

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  GuessManager() {
    _initTimer();
    _initGame();
  }

  void _initTimer() {
    _timer = TimerCounter(const Duration(seconds: 1), (_) {});
  }

  void _initGame() {
    emitSound(Sound.reset);
    correctItems.value = (List<String>.from(
      guessItem,
    )..shuffle()).take(_difficulty).toList();
    guessItems.value = List.from(correctItems.value)..shuffle();
    markItems.value = List.filled(_difficulty, MarkType.unknown.emoji);
    _timer.restart();
    _isGameOver = false;
    displayInfo.value = _displayText;
  }

  void resetGame() {
    if (_disposed) return;
    _initGame();
  }

  void _changeDifficulty(int value) {
    if (_disposed) return;
    if (value != _difficulty) {
      _difficulty = value;
      resetGame();
    }
  }

  /// 显示难度设置对话框
  void showSelector() {
    pageNavigator.value = (context) => DialogTemplate.intSliderDialog(
      context: context,
      title: S.setDifficulty,
      sliderData: IntSliderData(
        start: 4,
        end: guessItem.length,
        value: _difficulty,
        step: 1,
      ),
      onConfirm: _changeDifficulty,
    );
  }

  void guessSelect(int index) {
    if (_disposed || _isGameOver) return;

    if (selectedItem.value == index) {
      selectedItem.value = -1;
    } else if (selectedItem.value == -1) {
      selectedItem.value = index;
      emitSound(Sound.tap);
    } else {
      _swapItems(selectedItem.value, index);
    }
  }

  void _swapItems(int i, int j) {
    String temp = guessItems[i];
    guessItems[i] = guessItems[j];
    guessItems[j] = temp;
    selectedItem.value = -1;
    emitSound(Sound.move);
    if (_correctCount == _difficulty) {
      _handleGameOver();
    } else {
      displayInfo.value = _displayText;
    }
  }

  void _handleGameOver() {
    if (!_isGameOver) emitSound(Sound.win);
    _timer.stop();
    _isGameOver = true;
    displayInfo.value = _displayText;
    markItems.value = List.from(guessItems.value);
  }

  String get _displayText =>
      _isGameOver ? S.timeTaken(_timer.tick) : S.correctCount(_correctCount);

  int get _correctCount {
    int count = 0;
    for (int i = 0; i < guessItems.length; i++) {
      if (guessItems[i] == correctItems[i]) {
        count++;
      }
    }
    return count;
  }

  void markSelect(int index) {
    if (_disposed || _isGameOver) return;

    selectedItem.value = -1;

    markItems[index] = MarkTypeExt.toggle(markItems[index]);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer.dispose();
    disposeAudioEvents();
    correctItems.dispose();
    guessItems.dispose();
    markItems.dispose();
    selectedItem.dispose();
    displayInfo.dispose();
    pageNavigator.dispose();
  }

  void leavePage() {
    if (_disposed) return;
    _timer.stop();
    pageNavigator.value = (context) {
      Navigator.pop(context);
    };
  }
}
