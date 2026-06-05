import 'dart:async';

/// 可暂停、可恢复、可归零的周期性计时器
class TimerCounter {
  TimerCounter(this._duration, this._callback);

  final Duration _duration;
  final void Function(int tick) _callback;

  Timer? _timer;
  int _tick = 0; // 自己维护的 tick，随时可归零

  /// 当前 tick（只读）
  int get tick => _tick;

  /// 是否正在运行
  bool get isRunning => _timer != null && _timer!.isActive;

  /// 开始计时（如果已经在跑则忽略）
  void start() {
    if (isRunning) return;
    _timer = Timer.periodic(_duration, (_) {
      _tick++;
      _callback(_tick);
    });
  }

  void restart() {
    _tick = 0; // 归零 tick
    start();
  }

  /// 停止计时
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源
  void dispose() => stop();

  static String formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int remainingSeconds = totalSeconds % 3600;
    int minutes = remainingSeconds ~/ 60;
    int seconds = remainingSeconds % 60;

    // 格式化确保两位数显示
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
