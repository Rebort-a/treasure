import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../base/match_board.dart';
import 'combo_praise.dart';
import 'match_sound.dart';

export '../base/match_board.dart' show BonusPacing;

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
  /// 单机和联机共用的默认奖励演出节奏，不影响棋盘结算。
  static const defaultBonusPacing = BonusPacing.fixedBeat;

  /// 转换演出结束后保留一段静态展示，再开始自动触发。
  static const _conversionPause = Duration(milliseconds: 350);
  static const _conversionTransferDuration = Duration(milliseconds: 300);
  static const fallAnimationDuration = Duration(milliseconds: 210);
  static const iceSpreadDuration = Duration(milliseconds: 280);
  static const clearAnimationDuration = Duration(
    milliseconds: BonusTiming.clear,
  );
  static const _naturalFallDelay = Duration(milliseconds: BonusTiming.fall);
  static const _bonusIgnitionDelay = Duration(
    milliseconds: BonusTiming.ignition,
  );
  static const _bonusAutoIgnitionDelay = Duration(
    milliseconds: BonusTiming.autoIgnition,
  );

  final BonusPacing bonusPacing;
  final view = ValueNotifier<MatchView?>(null);
  final selected = ValueNotifier<int?>(null);
  final busy = ValueNotifier(false);
  final comboMultiplier = ValueNotifier<int?>(null);
  final comboPraise = ValueNotifier<String?>(null);
  final praiseVoice = ValueNotifier<ComboPraiseEvent?>(null);
  final winCelebration = ValueNotifier(false);
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
  Future<void>? _winPlayback;
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

  Duration transferDuration(BoardFrame frame) => frame.bonusAt != null
      ? const Duration(milliseconds: BonusTiming.transfer)
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

  void restart({int? seed, MatchTheme? theme, Future<void>? entranceReady}) {
    if (_disposed || !canRestart) return;
    _emitSound(MatchSound.reset);
    _resultAnnounced = false;
    _cancelDelays();
    _animationEpoch++;
    _invalidSwapEpoch++;
    _board = MatchBoard.random(
      seed: seed,
      theme: theme ?? _board?.theme ?? MatchTheme.classic,
    );
    busy.value = false;
    invalidSwap.value = null;
    invalidSwapAnimating.value = false;
    comboMultiplier.value = null;
    comboPraise.value = null;
    bonusTime.value = false;
    selected.value = null;
    _startBoardEntrance(ready: entranceReady);
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
    final result = _board!.playSwap(a, b, bonusPacing: bonusPacing);
    if (result == null) {
      if (_board!.adjacent(a, b) &&
          _board!.ice[a] == 0 &&
          _board!.ice[b] == 0) {
        showInvalidSwap(a, b);
      }
      return;
    }
    unawaited(_animate(result));
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
    final result = _board!.playSwap(a, b, bonusPacing: bonusPacing);
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
            _board!.theme != next.theme ||
            _board!.moveNumber > 0);
    final sameBoard = _board?.seed == next.seed && _board?.theme == next.theme;
    SwapResult? result;
    if (_publishedResult != null &&
        _board?.moveNumber == next.moveNumber &&
        sameBoard) {
      result = _publishedResult;
      _publishedResult = null;
    } else if (_board != null &&
        sameBoard &&
        next.moveNumber > _board!.moveNumber &&
        next.lastSwap != null) {
      // 普通成员用上一步快照重演动画；判定结果仍以发布者快照为准。
      final swap = next.lastSwap!;
      final previous = _board!.toJson();
      final expected = jsonEncode(next.toJson());
      for (final pacing in BonusPacing.values) {
        final replay = MatchBoard.fromJson(previous);
        final candidate = replay.playSwap(
          swap.$1,
          swap.$2,
          bonusPacing: pacing,
        );
        if (candidate != null && jsonEncode(replay.toJson()) == expected) {
          result = candidate;
          break;
        }
      }
    }
    _board = next;
    selected.value = null;
    _invalidSwapEpoch++;
    invalidSwap.value = null;
    invalidSwapAnimating.value = false;
    if (result != null) {
      unawaited(_animate(result));
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

  void _startBoardEntrance({Future<void>? ready}) {
    _resultAnnounced = false;
    final board = _board!;
    final epoch = ++_animationEpoch;
    _roundNumber++;

    void revealBoard({required bool playedEntrance}) {
      _show(BoardFrame(board, FramePhase.settled));
      if (board.iceLeft > 0) {
        _emitSound(MatchSound.freeze);
      } else if (!playedEntrance) {
        _emitSound(MatchSound.entrance);
      }
      busy.value = false;
    }

    if (reduceMotion) {
      revealBoard(playedEntrance: false);
      return;
    }
    busy.value = true;
    _show(BoardFrame.empty(board));
    unawaited(() async {
      // 首次打开页面时，等转场露脸再播下落；重开只保留原有的短停顿。
      final pause = _delay(const Duration(milliseconds: 100));
      if (ready != null) await ready;
      await pause;
      if (_disposed || epoch != _animationEpoch) return;
      final animate = !reduceMotion;
      if (animate) {
        final frame = BoardFrame(
          board,
          FramePhase.fall,
          isEntrance: true,
          spawnedPieceIds: {
            for (final piece in board.pieces.whereType<Piece>()) piece.id,
          },
        );
        _show(frame);
        _emitSound(MatchSound.entrance);
        await _waitBoardAnimation(frame, fallAnimationDuration);
        if (_disposed || epoch != _animationEpoch) return;
      }
      revealBoard(playedEntrance: animate);
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
    if (frame.phase == FramePhase.fall && frame.spawnedPieceIds.isNotEmpty) {
      _emitSound(
        _isFullBoardSpawn(frame) ? MatchSound.appear : MatchSound.fall,
      );
    }
    switch (frame.phase) {
      case FramePhase.swap:
        _emitSound(MatchSound.swap);
      case FramePhase.freeze:
        _emitSound(MatchSound.freeze);
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

  Future<void> _delay(Duration duration, {Future<void>? until}) {
    final completer = Completer<void>();
    late final Timer timer;
    void finish() {
      if (_pendingDelays.remove(timer) == null) return;
      timer.cancel();
      completer.complete();
    }

    timer = Timer(duration, finish);
    _pendingDelays[timer] = completer;
    if (until != null) unawaited(until.then((_) => finish()));
    return completer.future;
  }

  void _cancelDelays() {
    _winPlayback = null;
    _praisePlayback = null;
    _bonusPlayback = null;
    winCelebration.value = false;
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
    await _delay(
      duration + const Duration(milliseconds: 250),
      until: animation.future,
    );
    if (identical(_boardAnimation, animation)) {
      _boardAnimation = null;
      _boardAnimationFrame = null;
    }
  }

  void trackWinPlayback(Future<void> playback) => _winPlayback = playback;

  void trackPraisePlayback(Future<void> playback) => _praisePlayback = playback;

  void trackBonusPlayback(Future<void> playback) => _bonusPlayback = playback;

  Future<void> _waitForPlayback(Future<void>? playback) => playback == null
      ? Future.value()
      : _delay(const Duration(seconds: 5), until: playback);

  Future<void> _startWin() {
    // 撒花只接收开始信号，由界面自行播放至结束，不参与任何等待。
    winCelebration.value = true;
    _emitSound(MatchSound.win);
    return _waitForPlayback(_winPlayback);
  }

  Future<void> _showPraise(ComboPraise praise) {
    comboPraise.value = praise.label;
    praiseVoice.value = ComboPraiseEvent(praise);
    return Future.wait<void>([
      _delay(const Duration(seconds: 1)),
      _waitForPlayback(_praisePlayback),
    ]);
  }

  void _clearActionFeedback() {
    comboMultiplier.value = null;
    comboPraise.value = null;
  }

  Future<void> _beginBonus() {
    bonusTime.value = true;
    // 先完整播报奖励开场，再触发自动消除及步数转换。
    return _waitForPlayback(_bonusPlayback);
  }

  Future<void> _playBonusFrames(
    List<BoardFrame> frames,
    int start,
    int epoch, {
    required bool animate,
  }) async {
    if (frames[start].bonusAt != null) {
      var elapsed = 0;
      for (var i = start; i < frames.length - 1; i++) {
        final frame = frames[i];
        final at = frame.bonusAt!;
        if (at > elapsed) await _delay(Duration(milliseconds: at - elapsed));
        if (_disposed || epoch != _animationEpoch) return;
        _presentBonusFrame(frame, animate);
        elapsed = at;
      }
      final end = frames.last.bonusAt!;
      if (end > elapsed) await _delay(Duration(milliseconds: end - elapsed));
      return;
    }

    for (var i = start; i < frames.length - 1; i++) {
      if (_disposed || epoch != _animationEpoch) return;
      final frame = frames[i];
      if (frame.phase == FramePhase.clear &&
          !frame.naturalClear &&
          frames[i - 1].convertedPieceIds.isEmpty) {
        // 等待的是主动引爆本身，不是之前的坠落或自然消除。
        await _delay(_bonusAutoIgnitionDelay);
        if (_disposed || epoch != _animationEpoch) return;
      }

      final next = frames[i + 1];
      final beforeTransfer = next.phase == FramePhase.transfer;
      final waitForAnimation = animate
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

      _presentBonusFrame(frame, animate);
      if (waitForAnimation != null) {
        await waitForAnimation;
        continue;
      }
      final duration = switch (frame.phase) {
        FramePhase.transfer => transferDuration(frame),
        FramePhase.bonus when frame.convertedPieceIds.isNotEmpty =>
          _bonusIgnitionDelay,
        _ => _regularFrameDelay(frame),
      };
      if (duration > Duration.zero) await _delay(duration);
    }
  }

  void _presentBonusFrame(BoardFrame frame, bool animate) {
    if (frame.phase == FramePhase.transfer && !animate) {
      _show(frame);
    } else {
      _presentFrame(frame);
    }
  }

  Duration _regularFrameDelay(BoardFrame frame) => switch (frame.phase) {
    FramePhase.clear => clearAnimationDuration,
    FramePhase.freeze => iceSpreadDuration,
    FramePhase.fall when frame.staggeredFall => const Duration(
      milliseconds: 120,
    ),
    FramePhase.settled || FramePhase.bonus => Duration.zero,
    _ => _naturalFallDelay,
  };

  bool _isCurrent(int epoch) => !_disposed && epoch == _animationEpoch;

  Future<void> _playActionFrames(
    SwapResult result,
    int epoch, {
    required bool animate,
    required void Function(BoardFrame) onFrame,
  }) async {
    final frames = result.actionFrames;
    if (!animate) {
      // 减少动画时跳过交换和坠落，但保留转换展示和消除反馈。
      final conversions = frames.where(
        (frame) => frame.convertedPieceIds.isNotEmpty,
      );
      if (result.hasBonus || conversions.isEmpty) {
        _emitSound(MatchSound.swap);
        _emitSound(MatchSound.clear1);
      }
      for (final frame in conversions) {
        _presentFrame(frame);
        await _delay(_conversionPause);
        if (!_isCurrent(epoch)) return;
      }
      final settled = result.actionEndFrame;
      _show(settled);
      if (frames.any((frame) => frame.phase == FramePhase.freeze)) {
        _emitSound(MatchSound.freeze);
      }
      onFrame(settled);
      comboMultiplier.value = result.cascades == 0 ? null : result.cascades;
      return;
    }

    var cascade = 0;
    for (final frame in frames) {
      if (!_isCurrent(epoch)) return;
      if (frame.phase == FramePhase.clear) {
        comboMultiplier.value = ++cascade;
      }
      final transfer = frame.phase == FramePhase.transfer
          ? _waitBoardAnimation(frame, transferDuration(frame))
          : null;
      _presentFrame(frame, cascade: cascade);
      onFrame(frame);
      if (transfer != null) {
        await transfer;
      } else {
        final duration = frame.convertedPieceIds.isNotEmpty
            ? _conversionPause
            : _regularFrameDelay(frame);
        if (duration > Duration.zero) await _delay(duration);
      }
    }
  }

  Future<void> _animate(SwapResult result) async {
    _cancelDelays();
    final epoch = ++_animationEpoch;
    final animate = !reduceMotion;
    _clearActionFeedback();
    bonusTime.value = false;
    busy.value = true;
    comboMultiplier.value = result.cascades == 0 ? null : 1;

    // 胜利音效从达成目标的帧开始，和行动动画、赞美并行。
    Future<void>? winPlayback;
    await _playActionFrames(
      result,
      epoch,
      animate: animate,
      onFrame: (frame) {
        if (frame.goalsMet) winPlayback ??= _startWin();
      },
    );
    if (!_isCurrent(epoch)) return;
    if ((!result.hasBonus && result.shuffled) ||
        (!animate && result.actionFrames.any(_isFullBoardSpawn))) {
      _emitSound(MatchSound.appear);
    }

    if (animate) comboMultiplier.value = null;
    await _showPraise(_praiseFor(result));
    if (!_isCurrent(epoch)) return;
    _clearActionFeedback();
    final win = winPlayback;
    if (win != null) {
      await win;
      if (!_isCurrent(epoch)) return;
    }

    if (result.hasBonus) {
      await _beginBonus();
      if (!_isCurrent(epoch)) return;
      await _playBonusFrames(
        result.frames,
        result.actionEndIndex + 1,
        epoch,
        animate: animate,
      );
      if (!_isCurrent(epoch)) return;
      _show(result.frames.last);
      if (result.shuffled) _emitSound(MatchSound.appear);
      bonusTime.value = false;
    }
    busy.value = false;
    _announceResult();
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
    winCelebration.dispose();
    bonusTime.dispose();
    invalidSwap.dispose();
    invalidSwapAnimating.dispose();
    sound.dispose();
  }
}
