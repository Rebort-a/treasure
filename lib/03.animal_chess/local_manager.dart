import '../00.common/game/gamer.dart';
import 'base.dart';
import 'foundation_manager.dart';
import 'test.dart';

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
      _initAiController();
    }
  }

  void _initAiController() {
    final currentBoard = displayMap.value.map((g) => g.value.clone()).toList();
    _aiController = AiController(
      board: currentBoard,
      boardSize: boardSize,
      faction: currentGamer.value,
    );
    _performAiMove();
  }

  @override
  void endTurn() {
    currentGamer.value = currentGamer.value.opponent;
    if (aiEnabled && currentGamer.value == _aiController!.faction) {
      _performAiMove();
    }
  }

  Future<void> _performAiMove() async {
    if (!aiEnabled) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!aiEnabled) return;

    final action = _aiController!.getAction();

    if (action != null) {
      executeAction(action);
    }
    endTurn();
  }

  // 玩家点击格子
  @override
  void onGridClick(int index) {
    if (!aiEnabled) {
      autoProcess(index);
      return;
    }

    if (_aiController!.faction != currentGamer.value) {
      GameAction? action = autoProcess(index);

      if (action != null) {
        _syncControllerState(action);
      }
    }
  }

  void _syncControllerState(GameAction action) {
    if (aiEnabled) _aiController!.applyPlayerAction(action);
  }

  void toggleAiSwicth() {
    if (aiEnabled) {
      _aiController?.dispose();
      _aiController = null;
    } else {
      _initAiController();
    }
  }
}
