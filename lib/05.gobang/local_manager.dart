import 'package:flutter/foundation.dart';

import '../00.common/game/gamer.dart';
import 'foundation_manager.dart';
import 'intelligence.dart';

/// 本地对局管理器。AI 接入收归于此（middle 层），UI 层只做 toggle / 难度选择。
class LocalManager extends FoundationalManager {
  AiController? _ai;
  AiDifficulty _difficulty = AiDifficulty.normal;
  bool _aiMoving = false;

  /// 单一思考状态 notifier，供 UI 监听（避免 toggle 时 notifier 切换）
  final ValueNotifier<bool> _aiThinking = ValueNotifier(false);

  bool get aiEnabled => _ai != null;
  AiDifficulty get difficulty => _difficulty;
  TurnGamerType? get aiFaction => _ai?.faction;
  ValueListenable<bool> get aiThinking => _aiThinking;

  /// 当前轮到 AI 且未结束
  bool get _isAiTurn =>
      _ai != null &&
      board.currentGamer.value == _ai!.faction &&
      !board.gameOver;

  @override
  void placePiece(int index) {
    if (board.gameOver) return;
    // 轮到 AI 或 AI 正在思考时，忽略人类点击
    if (_ai != null && (_isAiTurn || _aiMoving)) return;
    board.placePiece(index);
    _maybeAiMove();
  }

  /// 开关 AI。faction 指定 AI 执方（用于重开时调整先后手）
  void toggleAi(bool on, {TurnGamerType? faction}) {
    if (on) {
      final f = faction ?? board.currentGamer.value;
      _ai = AiController(
        size: board.size,
        faction: f,
        difficulty: _difficulty,
      );
      _maybeAiMove();
    } else {
      _ai?.dispose();
      _ai = null;
      _aiMoving = false;
      _aiThinking.value = false;
    }
  }

  /// 切换难度（若 AI 已开启则重建控制器）
  void setDifficulty(AiDifficulty d) {
    _difficulty = d;
    if (_ai != null) {
      final f = _ai!.faction;
      _ai?.dispose();
      _ai = AiController(size: board.size, faction: f, difficulty: d);
      _maybeAiMove();
    }
  }

  /// 异步触发 AI 走子
  void _maybeAiMove() {
    final ai = _ai;
    if (ai == null || _aiMoving || board.gameOver) return;
    if (board.currentGamer.value != ai.faction) return;

    _aiMoving = true;
    _aiThinking.value = true;
    Future(() async {
      try {
        // 让 UI 先刷新到"思考中"状态再开算
        await Future.delayed(const Duration(milliseconds: 50));
        if (_ai != ai) return; // 期间控制器被替换（重开/切难度/关 AI）
        final move = await ai.getAction(board.snapshot());
        if (_ai != ai) return; // 搜索期间控制器被替换
        if (move != null &&
            !board.gameOver &&
            board.currentGamer.value == ai.faction) {
          board.placePiece(move);
        }
      } finally {
        // 仅当仍是同一控制器时重置状态，避免干扰新控制器
        if (_ai == ai) {
          _aiMoving = false;
          _aiThinking.value = false;
        }
      }
    });
  }

  @override
  void restart() {
    final aiFaction = _ai?.faction;
    final wasAi = _ai != null;
    board.restart();
    if (wasAi && aiFaction != null) {
      _ai?.dispose();
      _ai = AiController(
        size: board.size,
        faction: aiFaction,
        difficulty: _difficulty,
      );
      _maybeAiMove();
    }
  }

  @override
  void undo() {
    if (_aiMoving) return; // 思考中禁悔棋
    board.undoMove();
  }

  void dispose() {
    _ai?.dispose();
    _ai = null;
    _aiMoving = false;
    _aiThinking.dispose();
  }
}
