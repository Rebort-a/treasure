import 'package:flutter/foundation.dart';

import 'base.dart';
import 'foundation_manager.dart';
import 'intelligence.dart';

/// 本地对局管理器。AI 接入收归于此（middle 层），UI 层只做 toggle / 难度选择。
class GoLocalManager extends GoFoundationalManager {
  GoAiController? _ai;
  final _difficulty = ValueNotifier(GoAiDifficulty.normal);
  final _aiEnabled = ValueNotifier(false);
  bool _aiMoving = false;

  final ValueNotifier<bool> _aiThinking = ValueNotifier(false);

  bool get aiEnabled => _aiEnabled.value;
  ValueListenable<bool> get aiEnabledListenable => _aiEnabled;
  GoAiDifficulty get difficulty => _difficulty.value;
  ValueListenable<GoAiDifficulty> get difficultyListenable => _difficulty;
  StoneState? get aiFaction => _ai?.faction;
  ValueListenable<bool> get aiThinking => _aiThinking;

  /// 当前轮到 AI 且未结束
  bool get _isAiTurn =>
      _ai != null &&
      board.currentPlayer.value == _ai!.faction &&
      !board.gameOver;

  @override
  void placePiece(int index) {
    if (disposed || board.gameOver) return;
    // 轮到 AI 或 AI 正在思考时，忽略人类点击
    if (_ai != null && (_isAiTurn || _aiMoving)) return;
    applyBoardMove(index);
    _maybeAiMove();
  }

  /// 开关 AI。faction 指定 AI 执方（用于重开时调整先后手）
  void toggleAi(bool on, {StoneState? faction}) {
    if (disposed) return;
    final previousFaction = _ai?.faction;
    _clearAi();
    if (on) {
      final f = faction ?? previousFaction ?? board.currentPlayer.value;
      _ai = GoAiController(
        size: board.size,
        faction: f,
        difficulty: _difficulty.value,
      );
      _maybeAiMove();
    }
    _aiEnabled.value = on;
  }

  /// 切换难度（若 AI 已开启则重建控制器）
  void setDifficulty(GoAiDifficulty d) {
    if (disposed) return;
    _difficulty.value = d;
    if (_ai != null) {
      final f = _ai!.faction;
      _clearAi();
      _ai = GoAiController(size: board.size, faction: f, difficulty: d);
      _maybeAiMove();
    }
  }

  /// 异步触发 AI 走子
  void _maybeAiMove() {
    final ai = _ai;
    if (disposed || ai == null || _aiMoving || board.gameOver) return;
    if (board.currentPlayer.value != ai.faction) return;

    _aiMoving = true;
    _aiThinking.value = true;
    Future(() async {
      try {
        // 让 UI 先刷新到"思考中"状态再开算
        await Future.delayed(const Duration(milliseconds: 50));
        if (disposed || _ai != ai) return; // 期间控制器被替换（重开/切难度/关 AI）
        final move = await ai.getAction(board.snapshot());
        if (disposed || _ai != ai) return; // 搜索期间控制器被替换
        if (move != null &&
            !board.gameOver &&
            board.currentPlayer.value == ai.faction) {
          applyBoardMove(move);
        }
      } finally {
        // 仅当仍是同一控制器时重置状态，避免干扰新控制器
        if (!disposed && _ai == ai) {
          _aiMoving = false;
          _aiThinking.value = false;
        }
      }
    });
  }

  @override
  void restart() {
    if (disposed) return;
    final aiFaction = _ai?.faction;
    final wasAi = _ai != null;
    super.restart();
    if (wasAi && aiFaction != null) {
      _clearAi();
      _ai = GoAiController(
        size: board.size,
        faction: aiFaction,
        difficulty: _difficulty.value,
      );
      _maybeAiMove();
    }
  }

  @override
  void undo() {
    if (disposed || _aiMoving) return; // 思考中禁悔棋
    board.undoMove();
  }

  void _clearAi() {
    final ai = _ai;
    _ai = null;
    ai?.dispose();
    _aiMoving = false;
    _aiThinking.value = false;
  }

  @override
  void dispose() {
    if (disposed) return;
    _clearAi();
    _aiThinking.dispose();
    _aiEnabled.dispose();
    _difficulty.dispose();
    super.dispose();
  }
}
