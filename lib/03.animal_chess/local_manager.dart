import 'dart:collection';

import '../00.common/game/gamer.dart';
import 'foundation_manager.dart';
import 'intelligence.dart';

class LocalManager extends FoundationalManager {
  /// AI控制器实例
  AiController? _aiController;

  /// AI执行延时
  static const Duration _aiMoveDelay = Duration(milliseconds: 500);

  /// AI动作执行锁：防止异步并发多次执行
  bool _isAiMoving = false;
  int _aiEpoch = 0;
  bool _disposed = false;

  bool get aiEnabled => _aiController != null;

  LocalManager() {
    initGame();
  }

  /// 统一销毁AI资源
  void _disposeAiController() {
    _aiEpoch++;
    _aiController?.dispose();
    _aiController = null;
    _isAiMoving = false;
  }

  /// 初始化AI控制器
  void _initAiController() {
    final currentBoard = displayMap.value.map((g) => g.value).toList();
    _aiController = AiController(
      board: UnmodifiableListView(currentBoard),
      boardSize: boardSize,
      faction: currentGamer.value,
    );

    _performAiMove();
  }

  /// 通用：切换当前对局玩家
  void _switchCurrentGamer() {
    currentGamer.value = currentGamer.value.opponent;
  }

  @override
  void initGame() {
    super.initGame();
    if (aiEnabled) {
      _disposeAiController();
      _initAiController();
    }
  }

  @override
  void endTurn() {
    if (_disposed || winner.value != null) return;
    _switchCurrentGamer();
    final aiCtrl = _aiController;
    if (aiCtrl != null && currentGamer.value == aiCtrl.faction) {
      _performAiMove();
    }
  }

  /// 执行AI走棋（加锁防并发）
  Future<void> _performAiMove() async {
    if (_disposed ||
        winner.value != null ||
        _isAiMoving ||
        _aiController == null) {
      return;
    }

    _isAiMoving = true;
    final epoch = _aiEpoch;
    final aiCtrl = _aiController!;
    try {
      await Future.delayed(_aiMoveDelay);
      // 旧局 AI 延迟不能作用于重开后的棋盘，也不能在投降后继续落子。
      if (_disposed ||
          epoch != _aiEpoch ||
          aiCtrl != _aiController ||
          winner.value != null) {
        return;
      }

      final action = aiCtrl.getAction();
      if (action != null) {
        executeAction(action);
      }
      if (winner.value == null) _switchCurrentGamer();
    } finally {
      if (epoch == _aiEpoch) _isAiMoving = false;
    }
  }

  @override
  void onCellClick(int index) {
    if (_disposed || winner.value != null) return;
    final aiCtrl = _aiController;
    if (aiCtrl == null) {
      autoProcess(index);
      return;
    }
    if (aiCtrl.faction != currentGamer.value) {
      final action = autoProcess(index);
      if (action != null) {
        aiCtrl.applyPlayerAction(action);
      }
    }
  }

  void toggleAiSwitch() {
    if (aiEnabled) {
      _disposeAiController();
    } else {
      _initAiController();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disposeAiController();
    winner.dispose();
  }
}
