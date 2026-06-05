import '../00.common/game/gamer.dart';
import 'foundation_manager.dart';

class LocalManager extends FoundationalManager {
  LocalManager() {
    initGame();
  }

  @override
  void leavePage() {
    showChessResult(currentGamer.value == TurnGamerType.rear);
  }
}
