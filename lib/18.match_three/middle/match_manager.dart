import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../base/match_board.dart';
import 'combo_praise.dart';
import 'match_sound.dart';

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

enum BonusPacing { fixedBeat, waitForFall }

/// 负责选择和展示帧的生命周期，三消判定始终由纯 Dart 内核完成。
class MatchManager {
  /// 单机和联机共用的默认奖励演出节奏，不影响棋盘结算。
  static const defaultBonusPacing = BonusPacing.fixedBeat;

  /// 转换演出结束后保留一段静态展示，再开始自动触发。
  static const _conversionPause = Duration(milliseconds: 350);
  static const _conversionTransferDuration = Duration(milliseconds: 300);
  static const fallAnimationDuration = Duration(milliseconds: 210);
  static const clearAnimationDuration = Duration(milliseconds: 180);
  static const _naturalFallDelay = Duration(milliseconds: 220);

  // 额外节拍只限制奖励动作，不改变普通消除或补块的动画时长。
  static const _bonusTransferDuration = Duration(milliseconds: 300);
  static const _bonusTransferInterval = Duration(milliseconds: 900);
  static const _bonusTransferFallLead = Duration(milliseconds: 70);
  static const _bonusIgnitionDelay = Duration(milliseconds: 350);
  static const _bonusAutoIgnitionDelay = Duration(milliseconds: 500);

  final BonusPacing bonusPacing;
  final view = ValueNotifier<MatchView?>(null);
  final selected = ValueNotifier<int?>(null);
  final busy = ValueNotifier(false);
  final comboMultiplier = ValueNotifier<int?>(null);
  final comboPraise = ValueNotifier<String?>(null);
  final praiseVoice = ValueNotifier<ComboPraiseEvent?>(null);
  final bonusTime = ValueNotifier(false);
  final invalidSwap = ValueNotifier<(int, int)?>(null);
  final invalidSwapAnimating = ValueNotifier(false);
  final sound = ValueNotifier<MatchSoundEvent?>(null);
  MatchBoard? _board;
  SwapResult? _publishedResult;
  int _animationEpoch = 0;
  int _invalidSwapEpoch = 0;
  bool _disposed = false;
  bool _resultAnnounced = false;
  final Map<Timer, Completer<void>> _pendingDelays = {};
  Completer<void>? _boardAnimation;
  BoardFrame? _boardAnimationFrame;
  Future<void>? _praisePlayback;
  Future<void>? _bonusPlayback;
  bool reduceMotion = false;
  int _roundNumber = 0;

  MatchManager({
    bool generate = true,
    int? seed,
    this.bonusPacing = defaultBonusPacing,
  }) {
    if (generate) restart(seed: seed);
  }

  Duration transferDuration(BoardFrame frame) =>
      frame.transferSourcePieceId == null &&
          bonusPacing == BonusPacing.fixedBeat
      ? _bonusTransferDuration
      : _conversionTransferDuration;

  MatchBoard? get board => _board;
  int get roundNumber => _roundNumber;
  bool get canInteract =>
      !_disposed &&
      !busy.value &&
      !invalidSwapAnimating.value &&
      _board?.status == MatchStatus.playing;
  bool get canRestart => true;

  /// 发布者尚待回环的结算结果也属于忙碌阶段，不能提前结束联机轮次。
  bool get roundSettled =>
      _publishedResult == null &&
      !busy.value &&
      !bonusTime.value &&
      view.value?.frame.phase == FramePhase.settled;

  void restart({int? seed}) {
    if (_disposed || !canRestart) return;
    _emitSound(MatchSound.reset);
    _resultAnnounced = false;
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
    _startBoardEntrance();
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
      _emitSound(MatchSound.select);
    }
  }

  /// 联机新局丢弃旧棋盘与动画，由发布者重新生成并通过快照同步。
  void resetNetworkRound() {
    _emitSound(MatchSound.reset);
    _resultAnnounced = false;
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
    _emitSound(MatchSound.invalid);
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
    final previousScore = _board!.score;
    final result = _board!.playSwap(a, b);
    if (result == null) return false;
    _publishedResult = result;
    onNetworkActionApplied(result, previousScore);
    return true;
  }

  /// 仅在发布者成功应用动作后通知派生业务，重演动画或重复快照不会再次计分。
  @protected
  void onNetworkActionApplied(SwapResult result, int previousScore) {}

  void loadState(Map<String, dynamic> data) {
    _cancelDelays();
    final next = MatchBoard.fromJson(data);
    final isNewRound =
        next.moveNumber == 0 &&
        (view.value == null ||
            _board == null ||
            _board!.seed != next.seed ||
            _board!.moveNumber > 0);
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
      _emitSound(MatchSound.reset);
      _animationEpoch++;
      busy.value = false;
      comboMultiplier.value = null;
      comboPraise.value = null;
      bonusTime.value = false;
      if (isNewRound) {
        _startBoardEntrance();
      } else {
        _show(BoardFrame(next, FramePhase.settled));
      }
    }
  }

  void _startBoardEntrance() {
    _resultAnnounced = false;
    final board = _board!;
    final epoch = ++_animationEpoch;
    _roundNumber++;
    if (reduceMotion) {
      busy.value = false;
      _show(BoardFrame(board, FramePhase.settled));
      _emitSound(MatchSound.entrance);
      return;
    }
    busy.value = true;
    _show(BoardFrame.empty(board));
    unawaited(() async {
      // 留出空棋盘展示时间，新棋子挂载后复用补块入场动画。
      await _delay(const Duration(milliseconds: 100));
      if (_disposed || epoch != _animationEpoch) return;
      if (!reduceMotion) {
        _show(
          BoardFrame(
            board,
            FramePhase.fall,
            spawnedPieceIds: board.pieces
                .whereType<Piece>()
                .map((piece) => piece.id)
                .toSet(),
          ),
        );
        _emitSound(MatchSound.entrance);
        await _delay(const Duration(milliseconds: 220));
        if (_disposed || epoch != _animationEpoch) return;
      } else {
        _emitSound(MatchSound.entrance);
      }
      _show(BoardFrame(board, FramePhase.settled));
      busy.value = false;
    }());
  }

  void _show(BoardFrame frame) {
    if (!_disposed) view.value = MatchView(_board!, frame);
  }

  void _emitSound(MatchSound cue) {
    if (_disposed) return;
    sound.value = MatchSoundEvent(cue);
    if (cue == MatchSound.reset) {
      praiseVoice.value = null;
    }
  }

  bool _isFullBoardSpawn(BoardFrame frame) =>
      frame.spawnedPieceIds.length == MatchBoard.cells;

  /// 只在推进展示帧时发声，刷新视图和重复快照不会重播音效。
  void _presentFrame(BoardFrame frame, {int cascade = 1}) {
    final previous = view.value?.frame;
    _show(frame);
    if (frame.spawnedPieceIds.isNotEmpty) {
      _emitSound(
        _isFullBoardSpawn(frame) ? MatchSound.appear : MatchSound.fall,
      );
    }
    switch (frame.phase) {
      case FramePhase.swap:
        _emitSound(MatchSound.swap);
      case FramePhase.bonus:
        // 奖励开场仅播报语音，步数转换完成时才播放提示音。
        if (frame.convertedPieceIds.isNotEmpty) {
          _emitSound(MatchSound.bonus);
        }
      case FramePhase.clear:
        final effects = {
          for (final index in frame.clearing)
            if (frame.pieces[index] != null) frame.pieces[index]!.effect,
        };
        _emitSound(
          effects.contains(PieceEffect.rainbow)
              ? MatchSound.rainbow
              : effects.contains(PieceEffect.bomb)
              ? MatchSound.bomb
              : effects.contains(PieceEffect.row) ||
                    effects.contains(PieceEffect.column)
              ? MatchSound.line
              : switch (cascade) {
                  <= 1 => MatchSound.clear1,
                  2 => MatchSound.clear2,
                  3 => MatchSound.clear3,
                  _ => MatchSound.clear4,
                },
        );
        if (previous != null &&
            List.generate(
              frame.ice.length,
              (index) => frame.ice[index] < previous.ice[index],
            ).any((cracked) => cracked)) {
          _emitSound(MatchSound.ice);
        }
      case FramePhase.transform:
        if (frame.convertedPieceIds.isNotEmpty) {
          _emitSound(MatchSound.transform);
        }
      case FramePhase.transfer:
        _emitSound(MatchSound.transform);
      case FramePhase.fall:
      case FramePhase.settled:
        break;
    }
  }

  void _announceResult() {
    if (_disposed || _resultAnnounced || !roundSettled) return;
    final status = view.value?.status;
    if (status == MatchStatus.won || status == MatchStatus.lost) {
      _resultAnnounced = true;
      _emitSound(status == MatchStatus.won ? MatchSound.won : MatchSound.lost);
    }
  }

  void refreshView() {
    final current = view.value;
    if (current != null && !_disposed) _show(current.frame);
  }

  ComboPraise _praiseFor(SwapResult result) {
    if (result.cascades >= 6 || result.totalCleared >= 48) {
      return ComboPraise.unbelievable;
    }
    if (result.cascades >= 4 ||
        result.specialEffectsTriggered >= 4 ||
        result.totalCleared >= 32) {
      return ComboPraise.amazing;
    }
    if (result.cascades >= 3 ||
        result.specialEffectsTriggered >= 2 ||
        result.totalCleared >= 20) {
      return ComboPraise.excellent;
    }
    if (result.initialMatchCount >= 4 ||
        result.cascades >= 2 ||
        result.totalCleared >= 12) {
      return ComboPraise.great;
    }
    return ComboPraise.good;
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
    _praisePlayback = null;
    _bonusPlayback = null;
    final animation = _boardAnimation;
    _boardAnimation = null;
    _boardAnimationFrame = null;
    if (animation != null && !animation.isCompleted) animation.complete();
    final pending = _pendingDelays.entries.toList();
    _pendingDelays.clear();
    for (final entry in pending) {
      entry.key.cancel();
      if (!entry.value.isCompleted) entry.value.complete();
    }
  }

  /// 只接受正在等待的帧，重开或切换帧后忽略旧动画回调。
  void finishBoardAnimation(BoardFrame frame) {
    final animation = _boardAnimation;
    if (!_disposed &&
        identical(frame, _boardAnimationFrame) &&
        animation != null &&
        !animation.isCompleted) {
      animation.complete();
    }
  }

  Future<void> _waitBoardAnimation(BoardFrame frame, Duration duration) async {
    final animation = Completer<void>();
    _boardAnimation = animation;
    _boardAnimationFrame = frame;
    // 未挂载界面的成员也必须正常结束结算，不能永久等待界面回调。
    await Future.any([
      animation.future,
      _delay(duration + const Duration(milliseconds: 250)),
    ]);
    if (identical(_boardAnimation, animation)) {
      _boardAnimation = null;
      _boardAnimationFrame = null;
    }
  }

  /// 仅关联当前展示事件，旧播报不能结束下一次赞美的等待。
  void trackPraisePlayback(ComboPraiseEvent event, Future<void> playback) {
    if (!_disposed && identical(praiseVoice.value, event)) {
      _praisePlayback = playback;
    }
  }

  /// 播放器同步关联当前奖励开场，旧局等待由动画代次与可取消延时隔离。
  void trackBonusPlayback(Future<void> playback) {
    if (!_disposed && bonusTime.value) _bonusPlayback = playback;
  }

  void _showPraiseBriefly(
    ComboPraise praise,
    int epoch, {
    bool keepVisible = false,
  }) {
    _praisePlayback = null;
    comboMultiplier.value = null;
    comboPraise.value = praise.label;
    praiseVoice.value = ComboPraiseEvent(praise);
    if (keepVisible) return;
    unawaited(() async {
      await _delay(const Duration(milliseconds: 1000));
      if (!_disposed && epoch == _animationEpoch) {
        comboPraise.value = null;
      }
    }());
  }

  Future<bool> _beginBonusAfterPraise(ComboPraise praise, int epoch) async {
    _showPraiseBriefly(praise, epoch, keepVisible: true);
    final playback = _praisePlayback;
    await Future.wait([
      // 静音或未挂载播放器时也保留本次行动的展示，不直接跳到奖励转换。
      _delay(const Duration(milliseconds: 1000)),
      if (playback != null)
        // 设备异常不能永久阻塞结算；重开和同步重置也会取消这段等待。
        Future.any([playback, _delay(const Duration(seconds: 5))]),
    ]);
    if (_disposed || epoch != _animationEpoch) return false;
    comboPraise.value = null;
    comboMultiplier.value = null;
    _bonusPlayback = null;
    bonusTime.value = true;
    final bonusPlayback = _bonusPlayback;
    if (bonusPlayback != null) {
      // 先完整播报奖励开场，再触发自动消除及步数转换，避免提示音压住语音。
      await Future.any([bonusPlayback, _delay(const Duration(seconds: 5))]);
    }
    return !_disposed && epoch == _animationEpoch;
  }

  Future<void> _playBonusFrames(
    List<BoardFrame> frames,
    int start,
    int epoch, {
    required bool animate,
  }) async {
    final fixedBeat = bonusPacing == BonusPacing.fixedBeat;
    var untilNextTransfer = Duration.zero;

    Future<void> pause(Duration duration) async {
      if (duration > Duration.zero) {
        await _delay(duration);
        untilNextTransfer -= duration;
      }
    }

    for (var i = start; i < frames.length - 1; i++) {
      if (_disposed || epoch != _animationEpoch) return;
      final frame = frames[i];
      if (frame.phase == FramePhase.clear &&
          !frame.naturalClear &&
          frames[i - 1].convertedPieceIds.isEmpty) {
        // 等待的是主动引爆本身，不是之前的坠落或自然消除。
        await pause(_bonusAutoIgnitionDelay);
        if (_disposed || epoch != _animationEpoch) return;
      }

      final next = frames[i + 1];
      final beforeTransfer = next.phase == FramePhase.transfer;
      final waitForAnimation = animate && !fixedBeat
          ? switch (frame.phase) {
              FramePhase.transfer => _waitBoardAnimation(
                frame,
                transferDuration(frame),
              ),
              FramePhase.fall when beforeTransfer => _waitBoardAnimation(
                frame,
                fallAnimationDuration,
              ),
              _ => null,
            }
          : null;

      if (frame.phase == FramePhase.transfer) {
        untilNextTransfer = _bonusTransferInterval;
        if (animate) {
          _presentFrame(frame);
        } else {
          _show(frame);
        }
      } else {
        _presentFrame(frame);
      }

      if (waitForAnimation != null) {
        await waitForAnimation;
        continue;
      }
      final duration = switch (frame.phase) {
        FramePhase.transfer => transferDuration(frame),
        FramePhase.bonus when frame.convertedPieceIds.isNotEmpty =>
          _bonusIgnitionDelay,
        // 没有待消除的匹配时，固定节拍可在最后一段坠落中开始连线。
        FramePhase.fall when fixedBeat && beforeTransfer =>
          _bonusTransferFallLead,
        _ => _regularFrameDelay(frame),
      };
      // 自然连锁消耗节拍内的时间；即使超出节拍，也先消除，再转换下一步。
      await pause(
        fixedBeat && beforeTransfer && untilNextTransfer > duration
            ? untilNextTransfer
            : duration,
      );
    }
  }

  Duration _regularFrameDelay(BoardFrame frame) => switch (frame.phase) {
    FramePhase.clear => clearAnimationDuration,
    FramePhase.fall when frame.staggeredFall => const Duration(
      milliseconds: 120,
    ),
    FramePhase.settled || FramePhase.bonus => Duration.zero,
    _ => _naturalFallDelay,
  };

  void _animate(SwapResult result) {
    _cancelDelays();
    final epoch = ++_animationEpoch;
    final praise = _praiseFor(result);
    final hasBonusTime = result.frames.any(
      (frame) => frame.phase == FramePhase.bonus,
    );
    final hasConversion = result.frames.any(
      (frame) => frame.convertedPieceIds.isNotEmpty,
    );
    final hasFullBoardSpawn = result.frames.any(_isFullBoardSpawn);
    final bonusIndex = result.frames.indexWhere(
      (frame) => frame.phase == FramePhase.bonus,
    );
    final hasActionFullBoardSpawn =
        hasBonusTime && result.frames.take(bonusIndex).any(_isFullBoardSpawn);
    final frames = result.frames;
    comboPraise.value = null;
    bonusTime.value = false;
    if (reduceMotion && !hasBonusTime && !hasConversion) {
      busy.value = true;
      comboMultiplier.value = null;
      // 减少动画时只播放一次操作与消除反馈，不补播被跳过的整段音效。
      _emitSound(MatchSound.swap);
      _emitSound(MatchSound.clear1);
      _show(result.frames.last);
      if (hasFullBoardSpawn || result.shuffled) _emitSound(MatchSound.appear);
      busy.value = false;
      _announceResult();
      if (_board?.status == MatchStatus.playing) {
        _showPraiseBriefly(praise, epoch);
      }
      return;
    }
    if (reduceMotion) {
      busy.value = true;
      comboMultiplier.value = null;
      unawaited(() async {
        if (hasBonusTime) {
          _emitSound(MatchSound.swap);
          _emitSound(MatchSound.clear1);
        }
        final actionEnd = hasBonusTime ? bonusIndex : frames.length;
        for (var i = 0; i < actionEnd; i++) {
          if (_disposed || epoch != _animationEpoch) return;
          final frame = frames[i];
          if (frame.convertedPieceIds.isNotEmpty) {
            _presentFrame(frame);
            await _delay(_conversionPause);
          }
        }
        if (_disposed || epoch != _animationEpoch) return;
        if (hasBonusTime) {
          _show(frames[bonusIndex - 1]);
          if (hasActionFullBoardSpawn) _emitSound(MatchSound.appear);
          if (!await _beginBonusAfterPraise(praise, epoch)) return;
          await _playBonusFrames(frames, bonusIndex, epoch, animate: false);
        }
        if (_disposed || epoch != _animationEpoch) return;
        _show(result.frames.last);
        if (_disposed || epoch != _animationEpoch) return;
        if (result.shuffled || (!hasBonusTime && hasFullBoardSpawn)) {
          _emitSound(MatchSound.appear);
        }
        bonusTime.value = false;
        busy.value = false;
        _announceResult();
        if (!hasBonusTime && _board?.status == MatchStatus.playing) {
          _showPraiseBriefly(praise, epoch);
        }
      }());
      return;
    }
    busy.value = true;
    comboMultiplier.value = result.cascades == 0 ? null : 1;
    unawaited(() async {
      var cascade = 0;
      final actionEnd = hasBonusTime ? bonusIndex : frames.length;
      for (var i = 0; i < actionEnd; i++) {
        if (_disposed || epoch != _animationEpoch) return;
        final frame = frames[i];
        if (frame.phase == FramePhase.clear) {
          cascade++;
          comboMultiplier.value = cascade;
        }
        final transfer = frame.phase == FramePhase.transfer
            ? _waitBoardAnimation(frame, transferDuration(frame))
            : null;
        _presentFrame(frame, cascade: cascade);
        // 重排没有独立的下落帧，只在最终棋盘真正展示时提示一次。
        if (result.shuffled && identical(frame, frames.last)) {
          _emitSound(MatchSound.appear);
        }
        if (transfer != null) {
          await transfer;
        } else {
          final duration = frame.convertedPieceIds.isNotEmpty
              ? _conversionPause
              : _regularFrameDelay(frame);
          if (duration > Duration.zero) await _delay(duration);
        }
      }
      if (_disposed || epoch != _animationEpoch) return;
      if (hasBonusTime) {
        if (!await _beginBonusAfterPraise(praise, epoch)) return;
        await _playBonusFrames(frames, bonusIndex, epoch, animate: true);
        if (_disposed || epoch != _animationEpoch) return;
        _show(frames.last);
        if (result.shuffled) _emitSound(MatchSound.appear);
      } else if (_board?.status == MatchStatus.playing) {
        comboMultiplier.value = null;
        _showPraiseBriefly(praise, epoch);
      }
      if (!_disposed && epoch == _animationEpoch) {
        comboMultiplier.value = null;
        bonusTime.value = false;
        busy.value = false;
        _announceResult();
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
    praiseVoice.dispose();
    bonusTime.dispose();
    invalidSwap.dispose();
    invalidSwapAnimating.dispose();
    sound.dispose();
  }
}
