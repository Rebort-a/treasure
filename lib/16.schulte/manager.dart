import 'package:flutter/material.dart';

import '../00.common/tool/notifiers.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

class SchulteManager {
  static const int cols = 10;
  static const int rows = 10;

  late final TimerCounter _timer;

  int _regionCount = 12; // N（区域数 = 数字数）
  bool _isGameOver = false;

  final ValueNotifier<SchulteBoard> board =
      ValueNotifier(SchulteBoard(cols: cols, rows: rows, regions: const []));
  final ValueNotifier<int> nextNumber = ValueNotifier(1);
  final ValueNotifier<int> elapsed = ValueNotifier(0);
  final ValueNotifier<String> displayInfo = ValueNotifier('');
  final AlwaysNotifier<SchulteTapFeedback?> tapFeedback = AlwaysNotifier(null);

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  SchulteManager() {
    _initTimer();
    _initGame();
  }

  void _initTimer() {
    _timer = TimerCounter(const Duration(seconds: 1), (tick) {
      elapsed.value = tick;
    });
  }

  /// 初始化：生成不规则区域 + 填 1~N 打乱；计时归零不启动（首次正确点击启动）
  void _initGame() {
    _timer.stop();
    _timer.setTick(0);
    elapsed.value = 0;
    board.value = RegionGenerator.generate(cols, rows, _regionCount);
    nextNumber.value = 1;
    tapFeedback.value = null;
    _isGameOver = false;
    displayInfo.value = _displayText;
  }

  void resetGame() => _initGame();

  /// 动画结束后由 page 回调清空反馈状态
  void clearFeedback() => tapFeedback.value = null;

  /// 释放资源（page dispose 时调用）
  void dispose() {
    _timer.dispose();
    board.dispose();
    nextNumber.dispose();
    elapsed.dispose();
    displayInfo.dispose();
    tapFeedback.dispose();
    pageNavigator.dispose();
  }

  /// 点击命中：屏幕坐标 → 格子坐标 → 区域 id → 判定
  void handleTap(Offset local, double width, double height) {
    if (_isGameOver) return;
    final b = board.value;
    final cellW = width / b.cols;
    final cellH = height / b.rows;
    int col = (local.dx / cellW).floor();
    int row = (local.dy / cellH).floor();
    if (col < 0) col = 0;
    if (col >= b.cols) col = b.cols - 1;
    if (row < 0) row = 0;
    if (row >= b.rows) row = b.rows - 1;
    final id = b.regionIdAt(col, row);
    onTapRegion(id);
  }

  /// 区域点击判定
  void onTapRegion(int id) {
    if (_isGameOver) return;
    if (id < 0 || id >= board.value.regions.length) return;
    final r = board.value.regions[id];

    if (r.number == nextNumber.value) {
      // 正确：首次启动计时，棋盘样式保持不变（不标记/不清理）
      if (!_timer.isRunning) _timer.start();
      nextNumber.value++;
      displayInfo.value = _displayText;
      tapFeedback.value = SchulteTapFeedback(regionId: id, isCorrect: true);
      if (nextNumber.value > _regionCount) _handleGameOver();
    } else {
      // 错误：触发红色反馈，棋盘样式不变
      tapFeedback.value = SchulteTapFeedback(regionId: id, isCorrect: false);
    }
  }

  void _handleGameOver() {
    _timer.stop();
    _isGameOver = true;
    displayInfo.value = _displayText;
  }

  String get _displayText =>
      _isGameOver ? S.timeTaken(_timer.tick) : S.nextNumber(nextNumber.value);

  /// 难度设置（区域数 N：4~40）
  void showSelector() {
    pageNavigator.value = (context) => DialogTemplate.intSliderDialog(
          context: context,
          title: S.setDifficulty,
          sliderData: IntSliderData(
            start: 4,
            end: 40,
            value: _regionCount,
            step: 1,
          ),
          onConfirm: _changeDifficulty,
        );
  }

  void _changeDifficulty(int value) {
    if (value != _regionCount) {
      _regionCount = value;
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
