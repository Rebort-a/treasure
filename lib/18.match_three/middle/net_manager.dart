import 'package:flutter/foundation.dart';

import '../../00.common/network/client/net_multi_turn_engine.dart';
import '../../00.common/network/client/socket_client.dart';
import 'match_manager.dart';
import '../base/match_board.dart';

/// 联机实现留在游戏模块内部，外部只需要 NetMatchThreePage(room)。
class NetMatchManager extends MatchManager {
  final NetMultiTurnEngine turnEngine;
  final hint = ValueNotifier<int?>(null);
  final playerScores = ValueNotifier<Map<int, int>>(const {});
  final showPersonalScore = ValueNotifier(false);
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
    bonusTime.addListener(_showPersonalResults);
  }

  int get personalScore => playerScores.value[turnEngine.identity] ?? 0;

  /// 同分同排名，不使用成员 ID 排序；已离开的贡献者仍属于本局统计。
  int get personalRank {
    final players = {
      ...turnEngine.participants.keys,
      ...playerScores.value.keys,
    };
    return 1 +
        players
            .where((id) => (playerScores.value[id] ?? 0) > personalScore)
            .length;
  }

  void _showPersonalResults() {
    if (bonusTime.value) showPersonalScore.value = true;
  }

  @override
  void onNetworkActionApplied(SwapResult result, int previousScore) {
    final player = turnEngine.currentPlayer.value;
    if (player == null || _released) return;
    // 进入奖励阶段前锁定本回合贡献，公共 Bonus 分数不归给最后行动者。
    final endScore = result.frames
        .firstWhere(
          (frame) => frame.phase == FramePhase.bonus,
          orElse: () => result.frames.last,
        )
        .score;
    playerScores.value = Map.unmodifiable({
      ...playerScores.value,
      player: (playerScores.value[player] ?? 0) + endScore - previousScore,
    });
  }

  @override
  Map<String, dynamic> saveState() => {
    ...super.saveState(),
    'playerScores': {
      for (final entry in playerScores.value.entries)
        '${entry.key}': entry.value,
    },
  };

  Map<int, int> _readPlayerScores(Map<String, dynamic> data) {
    final raw = data['playerScores'];
    // 旧快照没有个人统计时从零开始，不猜测历史分数归属。
    if (raw == null) return const {};
    if (raw is! Map<String, dynamic> || raw.length > 1000) {
      throw const FormatException('Invalid player scores');
    }
    final scores = <int, int>{};
    var total = 0;
    for (final entry in raw.entries) {
      final id = int.tryParse(entry.key);
      final score = entry.value;
      if (id == null ||
          id <= 0 ||
          id > 2147483647 ||
          score is! int ||
          score < 0 ||
          score > 10000000 ||
          scores.containsKey(id)) {
        throw const FormatException('Invalid player score');
      }
      scores[id] = score;
      total += score;
    }
    final sharedScore = data['score'];
    if (sharedScore is! int || total > sharedScore) {
      throw const FormatException('Inconsistent player scores');
    }
    return Map.unmodifiable(scores);
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
    final scores = _readPlayerScores(data);
    hint.value = null;
    super.loadState(data);
    playerScores.value = scores;
    if (board?.status != MatchStatus.won) {
      showPersonalScore.value = false;
    } else if (bonusTime.value || roundSettled) {
      showPersonalScore.value = true;
    }
  }

  @override
  void resetNetworkRound() {
    hint.value = null;
    playerScores.value = const {};
    showPersonalScore.value = false;
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
    bonusTime.removeListener(_showPersonalResults);
    turnEngine.releaseGame();
    hint.dispose();
    playerScores.dispose();
    showPersonalScore.dispose();
    super.dispose();
  }
}
