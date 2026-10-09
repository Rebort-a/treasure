import '../../00.common/network/client/net_multi_turn_engine.dart';
import '../../00.common/network/client/socket_client.dart';
import 'match_manager.dart';
import '../base/match_board.dart';

/// 联机实现留在游戏模块内部，外部只需要 NetMatchThreePage(room)。
class NetMatchManager extends MatchManager {
  final NetMultiTurnEngine turnEngine;
  bool _released = false;

  NetMatchManager({required SocketClient room})
    : turnEngine = NetMultiTurnEngine.forClient(room),
      super(generate: false) {
    turnEngine.configureTurns(
      saveState: saveState,
      loadState: loadState,
      applyAction: applyNetworkAction,
      resetRound: resetNetworkRound,
    );
    turnEngine.currentPlayer.addListener(refreshView);
    turnEngine.synchronized.addListener(refreshView);
    turnEngine.pendingAction.addListener(refreshView);
    view.addListener(_checkRoundFinished);
    busy.addListener(_checkRoundFinished);
  }

  void _checkRoundFinished() {
    if (!busy.value &&
        view.value?.status != null &&
        view.value!.status != MatchStatus.playing) {
      turnEngine.completeRound();
    }
  }

  @override
  bool get canRestart => false;

  @override
  bool get canInteract => super.canInteract && turnEngine.canAct;

  @override
  void swap(int a, int b) {
    if (!canInteract) return;
    selected.value = null;
    if (!board!.canSwap(a, b)) {
      showInvalidSwap(a, b);
      return;
    }
    turnEngine.submitAction({'from': a, 'to': b});
  }

  @override
  void dispose() {
    if (_released) return;
    _released = true;
    turnEngine.currentPlayer.removeListener(refreshView);
    turnEngine.synchronized.removeListener(refreshView);
    turnEngine.pendingAction.removeListener(refreshView);
    view.removeListener(_checkRoundFinished);
    busy.removeListener(_checkRoundFinished);
    turnEngine.releaseGame();
    super.dispose();
  }
}
