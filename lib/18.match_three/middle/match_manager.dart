import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../base/match_board.dart';

enum MatchFeedback { invalidSwap, hint, shuffled, combo }

class MatchView {
  final BoardFrame frame;
  final int score;
  final int scoreTarget;
  final int movesLeft;
  final int seed;
  final int iceLeft;
  final Map<int, int> targets;
  final List<int> collected;
  final MatchStatus status;

  MatchView(MatchBoard board, this.frame)
    : score = board.score,
      scoreTarget = board.scoreTarget,
      movesLeft = board.movesLeft,
      seed = board.seed,
      iceLeft = board.iceLeft,
      targets = Map.unmodifiable(board.targets),
      collected = List.unmodifiable(board.collected),
      status = board.status;
}

/// 负责选择、提示和展示帧的生命周期，三消判定始终由纯 Dart 内核完成。
class MatchManager {
  final view = ValueNotifier<MatchView?>(null);
  final selected = ValueNotifier<int?>(null);
  final hint = ValueNotifier<(int, int)?>(null);
  final busy = ValueNotifier(false);
  final feedback = ValueNotifier<MatchFeedback?>(null);
  MatchBoard? _board;
  SwapResult? _publishedResult;
  int _animationEpoch = 0;
  bool _disposed = false;
  bool reduceMotion = false;

  MatchManager({bool generate = true, int? seed}) {
    if (generate) restart(seed: seed);
  }

  MatchBoard? get board => _board;
  bool get canInteract =>
      !_disposed && !busy.value && _board?.status == MatchStatus.playing;
  bool get canRestart => true;

  void restart({int? seed}) {
    if (_disposed || !canRestart) return;
    _animationEpoch++;
    _board = MatchBoard.random(seed: seed);
    busy.value = false;
    selected.value = null;
    hint.value = null;
    feedback.value = null;
    _show(BoardFrame(_board!, FramePhase.settled));
  }

  void selectCell(int index) {
    if (!canInteract || index < 0 || index >= MatchBoard.cells) return;
    final previous = selected.value;
    if (previous == index) {
      selected.value = null;
    } else if (previous != null && _board!.adjacent(previous, index)) {
      swap(previous, index);
    } else {
      selected.value = index;
      hint.value = null;
    }
  }

  void swap(int a, int b) {
    if (!canInteract) return;
    selected.value = null;
    hint.value = null;
    final result = _board!.playSwap(a, b);
    if (result == null) {
      feedback.value = MatchFeedback.invalidSwap;
      return;
    }
    _animate(result);
  }

  void showHint() {
    if (!canInteract) return;
    final moves = _board!.legalMoves;
    if (moves.isNotEmpty) {
      hint.value = moves.first;
      selected.value = null;
      feedback.value = MatchFeedback.hint;
    }
  }

  /// 发布者才生成首次随机棋盘。网络同步发送完整随机状态，接管者无需重抽。
  Map<String, dynamic> saveState() {
    _board ??= MatchBoard.random();
    return _board!.toJson();
  }

  bool applyNetworkAction(Map<String, dynamic> action) {
    final a = action['from'];
    final b = action['to'];
    if (a is! int || b is! int || _board == null) return false;
    final result = _board!.playSwap(a, b);
    if (result == null) return false;
    _publishedResult = result;
    return true;
  }

  void loadState(Map<String, dynamic> data) {
    final next = MatchBoard.fromJson(data);
    SwapResult? result;
    if (_publishedResult != null &&
        _board?.moveNumber == next.moveNumber &&
        _board?.seed == next.seed) {
      result = _publishedResult;
      _publishedResult = null;
    } else if (_board != null &&
        next.seed == _board!.seed &&
        next.moveNumber == _board!.moveNumber + 1 &&
        next.lastSwap != null) {
      // 普通成员用上一步快照重演动画；判定结果仍以发布者快照为准。
      final replay = MatchBoard.fromJson(_board!.toJson());
      final swap = next.lastSwap!;
      final candidate = replay.playSwap(swap.$1, swap.$2);
      if (candidate != null &&
          jsonEncode(replay.toJson()) == jsonEncode(next.toJson())) {
        result = candidate;
      }
    }
    _board = next;
    selected.value = null;
    hint.value = null;
    if (result != null) {
      _animate(result);
    } else {
      _animationEpoch++;
      busy.value = false;
      feedback.value = null;
      _show(BoardFrame(next, FramePhase.settled));
    }
  }

  void _show(BoardFrame frame) {
    if (!_disposed) view.value = MatchView(_board!, frame);
  }

  void refreshView() {
    final current = view.value;
    if (current != null && !_disposed) _show(current.frame);
  }

  void _animate(SwapResult result) {
    final epoch = ++_animationEpoch;
    feedback.value = result.shuffled
        ? MatchFeedback.shuffled
        : result.cascades > 1
        ? MatchFeedback.combo
        : null;
    if (reduceMotion) {
      busy.value = false;
      _show(result.frames.last);
      return;
    }
    busy.value = true;
    unawaited(() async {
      for (final frame in result.frames) {
        if (_disposed || epoch != _animationEpoch) return;
        _show(frame);
        if (frame.phase != FramePhase.settled) {
          await Future<void>.delayed(
            Duration(milliseconds: frame.phase == FramePhase.clear ? 180 : 220),
          );
        }
      }
      if (!_disposed && epoch == _animationEpoch) busy.value = false;
    }());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _animationEpoch++;
    view.dispose();
    selected.dispose();
    hint.dispose();
    busy.dispose();
    feedback.dispose();
  }
}
