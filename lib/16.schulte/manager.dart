import 'package:flutter/widgets.dart';

import '../00.common/sound/sound_manager.dart';

import '../00.common/model/notifiers.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

class SchulteManager with SoundEmitter {
  static const int cols = 10;
  static const int rows = 10;

  late final TimerCounter _timer;

  int _regionCount = 12; // N（区域数 = 数字数）
  bool _disposed = false;
  bool _leaving = false;
  final ValueNotifier<bool> gameOver = ValueNotifier(false);

  final ValueNotifier<SchulteBoard> board = ValueNotifier(
    SchulteBoard(cols: cols, rows: rows, regions: const []),
  );
  final ValueNotifier<int> nextNumber = ValueNotifier(1);
  final ValueNotifier<int> elapsed = ValueNotifier(0);
  final ValueNotifier<String> displayInfo = ValueNotifier('');
  final AlwaysNotifier<SchulteTapFeedback?> tapFeedback = AlwaysNotifier(null);

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
    if (_disposed || _leaving) return;
    emitSound(Sound.reset);
    _timer.stop();
    _timer.setTick(0);
    elapsed.value = 0;
    board.value = RegionGenerator.generate(cols, rows, _regionCount);
    nextNumber.value = 1;
    tapFeedback.value = null;
    gameOver.value = false;
    displayInfo.value = _displayText;
  }

  void resetGame() => _initGame();

  /// 动画结束后由 page 回调清空反馈状态
  void clearFeedback() {
    if (!_disposed && !_leaving) tapFeedback.value = null;
  }

  /// 释放资源（page dispose 时调用）
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    gameOver.dispose();
    disposeAudioEvents();
    _timer.dispose();
    board.dispose();
    nextNumber.dispose();
    elapsed.dispose();
    displayInfo.dispose();
    tapFeedback.dispose();
  }

  /// 点击命中：屏幕坐标 → 格子坐标 → 区域 id → 判定
  void handleTap(Offset local, double width, double height) {
    if (_disposed || _leaving || gameOver.value) return;
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
    if (_disposed || _leaving || gameOver.value) return;
    if (id < 0 || id >= board.value.regions.length) return;
    final r = board.value.regions[id];

    if (r.number == nextNumber.value) {
      emitSound(Sound.success);
      // 正确：首次启动计时，棋盘样式保持不变（不标记/不清理）
      if (!_timer.isRunning) _timer.start();
      nextNumber.value++;
      displayInfo.value = _displayText;
      tapFeedback.value = SchulteTapFeedback(regionId: id, isCorrect: true);
      if (nextNumber.value > _regionCount) _handleGameOver();
    } else {
      // 错误：触发红色反馈，棋盘样式不变
      emitSound(Sound.error);
      tapFeedback.value = SchulteTapFeedback(regionId: id, isCorrect: false);
    }
  }

  void _handleGameOver() {
    emitSound(Sound.win);
    _timer.stop();
    gameOver.value = true;
    displayInfo.value = _displayText;
  }

  String get _displayText => gameOver.value
      ? S.timeTaken(_timer.tick)
      : S.nextNumber(nextNumber.value);

  int get difficulty => _regionCount;
  int get minDifficulty => 4;
  int get maxDifficulty => 40;

  void changeDifficulty(int value) {
    if (_disposed || _leaving) return;
    if (value != _regionCount) {
      _regionCount = value;
      resetGame();
    }
  }

  void leavePage() {
    if (_disposed || _leaving) return;
    _leaving = true;
    _timer.stop();
  }
}
