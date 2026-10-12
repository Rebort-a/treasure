import 'package:flutter/foundation.dart';

import '../../00.common/network/client/net_multi_turn_engine.dart';
import '../../00.common/network/client/socket_client.dart';
import 'match_manager.dart';
import '../base/match_board.dart';

/// 联机实现留在游戏模块内部，外部只需要 NetMatchThreePage(room)。
class NetMatchManager extends MatchManager {
  final NetMultiTurnEngine turnEngine;
  final hint = ValueNotifier<int?>(null);
  bool _released = false;

  NetMatchManager({required SocketClient room})
    : turnEngine = NetMultiTurnEngine.forClient(room),
      super(generate: false) {
    turnEngine.configureTurns(
      saveState: saveState,
      loadState: loadState,
      applyAction: applyNetworkAction,
      resetRound: resetNetworkRound,
      receiveHint: _receiveHint,
    );
    turnEngine.currentPlayer.addListener(_turnChanged);
    turnEngine.synchronized.addListener(refreshView);
    turnEngine.pendingAction.addListener(refreshView);
    view.addListener(_checkRoundFinished);
    busy.addListener(_checkRoundFinished);
    bonusTime.addListener(_checkRoundFinished);
  }

  void _checkRoundFinished() {
    if (roundSettled &&
        view.value?.status != null &&
        view.value!.status != MatchStatus.playing) {
      turnEngine.completeRound();
    }
  }

  @override
  bool get canRestart => false;

  @override
  bool get canInteract => super.canInteract && turnEngine.canAct;

  void _turnChanged() {
    selected.value = null;
    hint.value = null;
    refreshView();
  }

  void _receiveHint(Map<String, dynamic> data) {
    final index = data['cell'];
    if (index is int &&
        index >= 0 &&
        index < MatchBoard.cells &&
        board?.status == MatchStatus.playing) {
      hint.value = index;
    }
  }

  @override
  void selectCell(int index) {
    if (_released || index < 0 || index >= MatchBoard.cells) return;
    if (turnEngine.currentPlayer.value != turnEngine.identity) {
      if (board?.status == MatchStatus.playing) {
        turnEngine.submitHint({'cell': index});
      }
      return;
    }
    super.selectCell(index);
  }

  @override
  void loadState(Map<String, dynamic> data) {
    hint.value = null;
    super.loadState(data);
  }

  @override
  void resetNetworkRound() {
    hint.value = null;
    super.resetNetworkRound();
  }

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
    turnEngine.currentPlayer.removeListener(_turnChanged);
    turnEngine.synchronized.removeListener(refreshView);
    turnEngine.pendingAction.removeListener(refreshView);
    view.removeListener(_checkRoundFinished);
    busy.removeListener(_checkRoundFinished);
    bonusTime.removeListener(_checkRoundFinished);
    turnEngine.releaseGame();
    hint.dispose();
    super.dispose();
  }
}
