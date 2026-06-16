import 'base.dart';
import 'foundation_manager.dart';
import 'intelligence.dart';

class LocalManager extends FoundationalManager {
  AiController? _aiController;
  bool get aiEnabled => _aiController != null;

  LocalManager() {
    initGame();
  }

  @override
  void initGame() {
    super.initGame();
    if (aiEnabled) {
      _aiController!.dispose();
      _initAi();
    }
  }

  void enableAI(bool enable) {
    if (enable && !aiEnabled) {
      _initAi();
    } else if (!enable && aiEnabled) {
      _aiController?.dispose();
      _aiController = null;
    }
  }

  void _initAi() {
    final currentBoard = displayMap.value.map((g) => g.value).toList();
    _aiController = AiController(
      board: currentBoard,
      boardSize: boardSize,
      faction: currentGamer.value,
    );
    _performAiMove();
  }

  /// 用户点击格子
  void requestSelectGrid(int index) {
    if (!aiEnabled) {
      selectGrid(index);
      return;
    }

    if (_aiController!.faction != currentGamer.value) {
      GameAction? action = selectGrid(index);

      if (action != null) {
        _syncControllerState(action);
        _performAiMove();
      }
    }
  }

  void _syncControllerState(GameAction action) {
    if (_aiController == null) return;
    _aiController!.updateState(action);
  }

  Future<void> _performAiMove() async {
    if (_aiController == null) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (_aiController == null) return;

    final currentBoard = displayMap.value.map((g) => g.value).toList();
    final action = _aiController!.getAction(currentBoard);

    if (action is FlipAction) {
      selectGrid(action.index);
    } else if (action is MoveAction) {
      selectGrid(action.from);
      selectGrid(action.to);
    }
  }
}
