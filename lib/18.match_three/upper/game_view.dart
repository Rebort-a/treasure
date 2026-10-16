import 'dart:async';

import 'package:flutter/material.dart';

import '../../00.common/l10n/strings.dart';
import '../../00.common/network/client/net_multi_turn_engine.dart';
import '../../00.common/network/widget/round_replay_board.dart';
import '../../00.common/widget/component/game_replay_board.dart';
import '../base/match_board.dart';
import '../middle/match_manager.dart';
import '../middle/match_audio.dart';
import '../middle/net_manager.dart';
import 'animal_piece.dart';
import 'match_board_widget.dart';
import 'match_celebration.dart';
import 'team_chat_sheet.dart';

/// 本地与联机共用游戏界面，页面不负责创建/销毁 Manager 或连接。
class MatchGameView extends StatefulWidget {
  final MatchManager manager;
  final VoidCallback onExit;
  final NetMultiTurnEngine? engine;

  const MatchGameView({
    super.key,
    required this.manager,
    required this.onExit,
    this.engine,
  });

  @override
  State<MatchGameView> createState() => _MatchGameViewState();
}

class _MatchGameViewState extends State<MatchGameView>
    with WidgetsBindingObserver {
  late MatchAudioController _audio;
  bool _routeCurrent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createAudio();
  }

  void _createAudio() {
    _audio = MatchAudioController(manager: widget.manager);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _audio.setActive(
      _routeCurrent &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = TickerMode.valuesOf(context).enabled;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _audio.setActive(
      _routeCurrent &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audio.setActive(_routeCurrent && state == AppLifecycleState.resumed);
  }

  @override
  void didUpdateWidget(MatchGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      unawaited(_audio.dispose());
      _createAudio();
    }
  }

  @override
  Widget build(BuildContext context) => _MatchGameContent(
    manager: widget.manager,
    onExit: widget.onExit,
    engine: widget.engine,
    audio: _audio,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_audio.dispose());
    super.dispose();
  }
}

class _MatchGameContent extends StatelessWidget {
  final MatchManager manager;
  final VoidCallback onExit;
  final NetMultiTurnEngine? engine;
  final MatchAudioController audio;

  const _MatchGameContent({
    required this.manager,
    required this.onExit,
    required this.engine,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    manager.reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onExit,
        ),
        title: Text(S.matchThree),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: audio.enabled,
            builder: (context, enabled, _) => IconButton(
              tooltip: enabled ? S.matchMuteSound : S.matchEnableSound,
              icon: Icon(
                enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              ),
              onPressed: () => audio.setEnabled(!enabled),
            ),
          ),
          if (engine != null)
            IconButton(
              tooltip: S.matchTeamChat,
              icon: const Icon(Icons.forum_outlined),
              onPressed: () => _showChat(context),
            )
          else
            IconButton(
              key: const ValueKey('match-restart'),
              tooltip: S.matchNewRound,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: manager.restart,
            ),
        ],
      ),
      body: SafeArea(
        child: MatchCelebration(
          manager: manager,
          child: ValueListenableBuilder<MatchView?>(
            valueListenable: manager.view,
            builder: (context, view, _) {
              if (view == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(S.matchSynchronizing),
                    ],
                  ),
                );
              }
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(context, view),
                        const SizedBox(height: 12),
                        _goals(context, view),
                        const SizedBox(height: 14),
                        if (engine == null)
                          ValueListenableBuilder<bool>(
                            valueListenable: manager.busy,
                            builder: (_, busy, _) =>
                                ValueListenableBuilder<bool>(
                                  valueListenable: manager.bonusTime,
                                  builder: (_, bonus, _) => GameReplayBoard(
                                    finished:
                                        view.status != MatchStatus.playing &&
                                        !busy &&
                                        !bonus,
                                    onReplay: manager.restart,
                                    child: MatchBoardWidget(
                                      key: ValueKey(manager.roundNumber),
                                      manager: manager,
                                      view: view,
                                    ),
                                  ),
                                ),
                          )
                        else
                          ValueListenableBuilder<bool>(
                            valueListenable: manager.busy,
                            builder: (_, busy, _) =>
                                ValueListenableBuilder<bool>(
                                  valueListenable: manager.bonusTime,
                                  builder: (_, bonus, _) => RoundReplayBoard(
                                    engine: engine!,
                                    presentationReady: manager.roundSettled,
                                    child: MatchBoardWidget(
                                      key: ValueKey(manager.roundNumber),
                                      manager: manager,
                                      view: view,
                                    ),
                                  ),
                                ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 88,
                          child: _statusIndicator(context, view),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _multiplierIndicator(BuildContext context, int multiplier) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.close_rounded,
          size: 34,
          color: Theme.of(context).colorScheme.primary,
        ),
        Text(
          '$multiplier',
          key: const ValueKey('match-multiplier'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _statusIndicator(BuildContext context, MatchView view) =>
      ValueListenableBuilder<bool>(
        valueListenable: manager.busy,
        builder: (context, busy, _) => ValueListenableBuilder<bool>(
          valueListenable: manager.bonusTime,
          builder: (context, bonusTime, _) {
            final showingBonus = view.status == MatchStatus.won && bonusTime;
            final showingResult = !busy && view.status != MatchStatus.playing;
            if (showingBonus || showingResult) {
              final message = showingBonus
                  ? S.matchBonusTime
                  : view.status == MatchStatus.won
                  ? S.matchWon
                  : S.matchLost;
              return _resultIndicator(context, message, view.status);
            }
            if (busy) {
              return ValueListenableBuilder<String?>(
                valueListenable: manager.comboPraise,
                builder: (context, praise, _) {
                  if (praise != null) {
                    return _celebrationIndicator(context, praise);
                  }
                  return ValueListenableBuilder<int?>(
                    valueListenable: manager.comboMultiplier,
                    builder: (context, multiplier, _) =>
                        _multiplierIndicator(context, multiplier ?? 1),
                  );
                },
              );
            }
            return ValueListenableBuilder<String?>(
              valueListenable: manager.comboPraise,
              builder: (context, praise, _) {
                if (praise != null) {
                  return _celebrationIndicator(context, praise);
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: manager.invalidSwapAnimating,
                  builder: (context, invalidSwapAnimating, _) {
                    if (invalidSwapAnimating) {
                      return _multiplierIndicator(context, 0);
                    }
                    final message = switch (view.status) {
                      MatchStatus.won => S.matchWon,
                      MatchStatus.lost => S.matchLost,
                      MatchStatus.playing => null,
                    };
                    if (message == null) {
                      return const SizedBox.shrink();
                    }
                    return _resultIndicator(context, message, view.status);
                  },
                );
              },
            );
          },
        ),
      );

  Widget _celebrationIndicator(BuildContext context, String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _resultIndicator(
    BuildContext context,
    String message,
    MatchStatus status,
  ) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == MatchStatus.won
                ? Icons.emoji_events_rounded
                : Icons.eco_rounded,
            size: 30,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context, MatchView view) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF246D56), Color(0xFF469D78)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _movesMetric(context, view.movesLeft)),
        const SizedBox(width: 12),
        Expanded(child: _scoreMetric(context, view.score)),
        const SizedBox(width: 12),
        // 单机保留相同栏位，步数与分数不会因缺少联机信息而改变布局。
        Expanded(
          child: engine == null ? const SizedBox.shrink() : _team(context),
        ),
      ],
    ),
  );

  Widget _scoreMetric(BuildContext context, int score) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        S.matchScore,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      TweenAnimationBuilder<double>(
        // 新局重建数字动画，避免沿用上一局的分数向下滚动。
        key: ValueKey(manager.roundNumber),
        tween: Tween(begin: score.toDouble(), end: score.toDouble()),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (_, value, __) => Text(
          '${value.round()}',
          key: const ValueKey('match-score'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );

  Widget _movesMetric(BuildContext context, int movesLeft) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        S.matchMoves,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      ClipRect(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          transitionBuilder: (child, animation) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) {
              final offsetY = animation.status == AnimationStatus.reverse
                  ? animation.value - 1
                  : 1 - animation.value;
              return FractionalTranslation(
                translation: Offset(0, offsetY),
                child: child,
              );
            },
          ),
          child: Text(
            '$movesLeft',
            key: ValueKey(movesLeft),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _goals(BuildContext context, MatchView view) => LayoutBuilder(
    builder: (context, constraints) {
      final iconSize = (constraints.maxWidth - 16) / MatchBoard.side;
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final valueWidth = 60 * textScale;
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final entry in view.targets.entries)
            _goal(
              context,
              S.matchAnimalNames[entry.key],
              '${view.collected[entry.key].clamp(0, entry.value)} / ${entry.value}',
              view.collected[entry.key] >= entry.value,
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: CustomPaint(
                  painter: AnimalPiecePainter(
                    piece: Piece(entry.key + 1, entry.key),
                    clock: const AlwaysStoppedAnimation(0),
                    animated: false,
                  ),
                ),
              ),
              valueWidth: valueWidth,
            ),
          _goal(
            context,
            S.matchIceLeft,
            '${view.iceLeft}',
            view.iceLeft == 0,
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: Icon(
                Icons.ac_unit_rounded,
                color: const Color(0xFF73B9D8),
                size: iconSize * 0.72,
              ),
            ),
            valueWidth: valueWidth,
          ),
        ],
      );
    },
  );

  /// 目标条目：左侧图标，右侧两行。第一行是名称或"剩余冰块"，
  /// 第二行是原数字，两行都靠左显示。
  ///
  /// 右侧宽度沿用 [valueWidth] 不再加宽，仅靠行高增加容纳两行文字。
  Widget _goal(
    BuildContext context,
    String label,
    String value,
    bool done,
    Widget icon, {
    required double valueWidth,
  }) => Container(
    padding: const EdgeInsets.only(left: 4, right: 0, top: 2, bottom: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(
          width: valueWidth,
          child: done
              ? const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF469D78),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  // SizedBox 已给定固定宽度，stretch 让两行都占满该宽度，
                  // 名称与数字都从左侧开始。
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );

  Widget _team(BuildContext context) {
    final netManager = manager;
    if (netManager is! NetMatchManager) return _turnMetric(context);
    return ValueListenableBuilder<bool>(
      valueListenable: netManager.showPersonalScore,
      child: _turnMetric(context),
      builder: (context, showScore, turnInfo) => !showScore
          ? turnInfo!
          : ValueListenableBuilder<Map<int, int>>(
              valueListenable: netManager.playerScores,
              builder: (_, _, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.matchYourRank(netManager.personalRank),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${netManager.personalScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _turnMetric(BuildContext context) {
    final engine = this.engine!;
    final order = engine.participants.keys.toList();
    final current = order.indexOf(engine.currentPlayer.value ?? -1);
    final own = order.indexOf(engine.identity);
    // 与引擎的入局轮转顺序一致，计算轮到自己前还需经过几人。
    final waiting = current < 0 || own < 0
        ? null
        : (own - current + order.length) % order.length;
    final currentName = engine.participants[engine.currentPlayer.value];
    final turnLabel = engine.currentPlayer.value == engine.identity
        ? S.matchYourTurn
        : currentName == null
        ? S.matchSynchronizing
        : S.matchPlayerTurn(currentName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          turnLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          '${waiting ?? "–"}/${order.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  void _showChat(BuildContext context) {
    final engine = this.engine!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MatchTeamChatSheet(engine: engine),
    );
  }
}
