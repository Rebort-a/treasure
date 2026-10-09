import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../base/match_board.dart';

class MatchView {
  final BoardFrame frame;
  final int score;
  final int movesLeft;
  final int seed;
  final int iceLeft;
  final Map<int, int> targets;
  final List<int> collected;
  final MatchStatus status;

  MatchView(MatchBoard board, this.frame)
    : score = frame.score,
      movesLeft = frame.movesLeft,
      seed = board.seed,
      iceLeft = frame.ice.fold(0, (sum, layers) => sum + layers),
      targets = Map.unmodifiable(board.targets),
      collected = frame.collected,
      status = board.status;
}

/// 负责选择和展示帧的生命周期，三消判定始终由纯 Dart 内核完成。
class MatchManager {
  final view = ValueNotifier<MatchView?>(null);
  final selected = ValueNotifier<int?>(null);
  final busy = ValueNotifier(false);
  final comboMultiplier = ValueNotifier<int?>(null);
  final comboPraise = ValueNotifier<String?>(null);
  final bonusTime = ValueNotifier(false);
  final invalidSwap = ValueNotifier<(int, int)?>(null);
  final invalidSwapAnimating = ValueNotifier(false);
  MatchBoard? _board;
  SwapResult? _publishedResult;
  int _animationEpoch = 0;
  int _invalidSwapEpoch = 0;
  bool _disposed = false;
  final Map<Timer, Completer<void>> _pendingDelays = {};
  bool reduceMotion = false;

  MatchManager({bool generate = true, int? seed}) {
    if (generate) restart(seed: seed);
  }

  MatchBoard? get board => _board;
  bool get canInteract =>
      !_disposed &&
      !busy.value &&
      !invalidSwapAnimating.value &&
      _board?.status == MatchStatus.playing;
  bool get canRestart => true;

  void restart({int? seed}) {
    if (_disposed || !canRestart) return;
    _cancelDelays();
    _animationEpoch++;
    _invalidSwapEpoch++;
    _board = MatchBoard.random(seed: seed);
    busy.value = false;
    invalidSwap.value = null;
    invalidSwapAnimating.value = false;
    comboMultiplier.value = null;
    comboPraise.value = null;
    bonusTime.value = false;
    selected.value = null;
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
    }
  }

  /// 联机新局丢弃旧棋盘与动画，由发布者重新生成并通过快照同步。
  void resetNetworkRound() {
    _cancelDelays();
    _animationEpoch++;
    _invalidSwapEpoch++;
    _publishedResult = null;
    _board = null;
    view.value = null;
    busy.value = false;
    selected.value = null;
    invalidSwap.value = null;
    invalidSwapAnimating.value = false;
    comboMultiplier.value = null;
    comboPraise.value = null;
    bonusTime.value = false;
  }

  void swap(int a, int b) {
    if (!canInteract) return;
    selected.value = null;
    final result = _board!.playSwap(a, b);
    if (result == null) {
      if (_board!.adjacent(a, b) &&
          _board!.ice[a] == 0 &&
          _board!.ice[b] == 0) {
        showInvalidSwap(a, b);
      }
      return;
    }
    _animate(result);
  }

  void showInvalidSwap(int a, int b) {
    final board = _board;
    if (_disposed ||
        board == null ||
        !board.adjacent(a, b) ||
        board.ice[a] > 0 ||
        board.ice[b] > 0) {
      return;
    }
    final epoch = ++_invalidSwapEpoch;
    invalidSwapAnimating.value = true;
    invalidSwap.value = (a, b);
    unawaited(() async {
      await _delay(const Duration(milliseconds: 180));
      if (_disposed || epoch != _invalidSwapEpoch) return;
      invalidSwap.value = null;
      await _delay(const Duration(milliseconds: 180));
      if (!_disposed && epoch == _invalidSwapEpoch) {
        invalidSwapAnimating.value = false;
      }
    }());
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
    _cancelDelays();
    final next = MatchBoard.fromJson(data);
    SwapResult? result;
    if (_publishedResult != null &&
        _board?.moveNumber == next.moveNumber &&
        _board?.seed == next.seed) {
      result = _publishedResult;
      _publishedResult = null;
    } else if (_board != null &&
        next.seed == _board!.seed &&
        next.moveNumber > _board!.moveNumber &&
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
    _invalidSwapEpoch++;
    invalidSwap.value = null;
    invalidSwapAnimating.value = false;
    if (result != null) {
      _animate(result);
    } else {
      _animationEpoch++;
      busy.value = false;
      comboMultiplier.value = null;
      comboPraise.value = null;
      bonusTime.value = false;
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

  String _praiseFor(SwapResult result) {
    if (result.cascades >= 6 || result.totalCleared >= 48) {
      return 'Unbelievable';
    }
    if (result.cascades >= 4 ||
        result.specialEffectsTriggered >= 4 ||
        result.totalCleared >= 32) {
      return 'Amazing';
    }
    if (result.cascades >= 3 ||
        result.specialEffectsTriggered >= 2 ||
        result.totalCleared >= 20) {
      return 'Excellent';
    }
    if (result.initialMatchCount >= 4 ||
        result.cascades >= 2 ||
        result.totalCleared >= 12) {
      return 'Great';
    }
    return 'Good';
  }

  Future<void> _delay(Duration duration) {
    final completer = Completer<void>();
    late final Timer timer;
    timer = Timer(duration, () {
      _pendingDelays.remove(timer);
      if (!completer.isCompleted) completer.complete();
    });
    _pendingDelays[timer] = completer;
    return completer.future;
  }

  void _cancelDelays() {
    final pending = _pendingDelays.entries.toList();
    _pendingDelays.clear();
    for (final entry in pending) {
      entry.key.cancel();
      if (!entry.value.isCompleted) entry.value.complete();
    }
  }

  void _showPraiseBriefly(String praise, int epoch) {
    comboMultiplier.value = null;
    comboPraise.value = praise;
    unawaited(() async {
      await _delay(const Duration(milliseconds: 1000));
      if (!_disposed && epoch == _animationEpoch) {
        comboPraise.value = null;
      }
    }());
  }

  void _animate(SwapResult result) {
    _cancelDelays();
    final epoch = ++_animationEpoch;
    final praise = _praiseFor(result);
    final hasBonusTime = result.frames.any(
      (frame) => frame.phase == FramePhase.bonus,
    );
    comboPraise.value = null;
    bonusTime.value = false;
    if (reduceMotion && !hasBonusTime) {
      busy.value = true;
      comboMultiplier.value = null;
      _show(result.frames.last);
      busy.value = false;
      if (_board?.status == MatchStatus.playing) {
        _showPraiseBriefly(praise, epoch);
      }
      return;
    }
    if (reduceMotion) {
      busy.value = true;
      comboMultiplier.value = null;
      unawaited(() async {
        bonusTime.value = true;
        for (final frame in result.frames) {
          if (frame.phase != FramePhase.bonus) continue;
          if (_disposed || epoch != _animationEpoch) return;
          _show(frame);
          await _delay(const Duration(milliseconds: 350));
        }
        if (_disposed || epoch != _animationEpoch) return;
        _show(result.frames.last);
        if (_disposed || epoch != _animationEpoch) return;
        bonusTime.value = false;
        busy.value = false;
      }());
      return;
    }
    busy.value = true;
    comboMultiplier.value = result.cascades == 0 ? null : 1;
    unawaited(() async {
      var cascade = 0;
      var praiseShown = false;
      for (final frame in result.frames) {
        if (_disposed || epoch != _animationEpoch) return;
        if (frame.phase == FramePhase.bonus && !praiseShown) {
          praiseShown = true;
          comboPraise.value = null;
          comboMultiplier.value = null;
          bonusTime.value = true;
        }
        if (frame.phase == FramePhase.clear && !bonusTime.value) {
          cascade++;
          comboMultiplier.value = cascade;
        }
        _show(frame);
        if (frame.phase != FramePhase.settled) {
          await _delay(
            Duration(
              milliseconds: switch (frame.phase) {
                FramePhase.clear => 180,
                FramePhase.bonus => 420,
                _ => 220,
              },
            ),
          );
        }
      }
      if (!praiseShown && _board?.status == MatchStatus.playing) {
        comboMultiplier.value = null;
        _showPraiseBriefly(praise, epoch);
      }
      if (!_disposed && epoch == _animationEpoch) {
        comboMultiplier.value = null;
        bonusTime.value = false;
        busy.value = false;
      }
    }());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelDelays();
    _animationEpoch++;
    view.dispose();
    selected.dispose();
    busy.dispose();
    comboMultiplier.dispose();
    comboPraise.dispose();
    bonusTime.dispose();
    invalidSwap.dispose();
    invalidSwapAnimating.dispose();
  }
}
