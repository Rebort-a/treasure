import 'package:flutter/material.dart';

import '../../00.common/l10n/strings.dart';
import '../../00.common/network/client/net_multi_turn_engine.dart';
import '../../00.common/widget/component/chat_component.dart';
import '../base/match_board.dart';
import '../middle/match_manager.dart';
import 'animal_piece.dart';
import 'match_board_widget.dart';

/// 本地与联机共用游戏界面，页面不负责创建/销毁 Manager 或连接。
class MatchGameView extends StatelessWidget {
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
          IconButton(
            tooltip: S.matchRulesTitle,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(S.matchRulesTitle),
                content: SingleChildScrollView(child: Text(S.matchRules)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(S.ok),
                  ),
                ],
              ),
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
                      if (engine != null) ...[
                        const SizedBox(height: 12),
                        _team(context),
                      ],
                      const SizedBox(height: 14),
                      MatchBoardWidget(manager: manager, view: view),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: manager.busy,
                        builder: (_, busy, __) {
                          if (!busy && view.status != MatchStatus.playing) {
                            return _result(context, view);
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  S.matchGestureHint,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                key: const ValueKey('match-hint'),
                                onPressed: manager.canInteract
                                    ? manager.showHint
                                    : null,
                                icon: const Icon(Icons.lightbulb_outline),
                                label: Text(S.matchHint),
                              ),
                            ],
                          );
                        },
                      ),
                      ValueListenableBuilder<MatchFeedback?>(
                        valueListenable: manager.feedback,
                        builder: (_, feedback, __) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            switch (feedback) {
                              MatchFeedback.invalidSwap => S.matchInvalidSwap,
                              MatchFeedback.hint => S.matchHintShown,
                              MatchFeedback.shuffled => S.matchShuffled,
                              MatchFeedback.combo => S.matchCombo,
                              null => '',
                            },
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context, MatchView view) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF246D56), Color(0xFF469D78)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.matchRandomRound,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _metric(S.matchMoves, '${view.movesLeft}'),
            _metric(S.matchScore, '${view.score} / ${view.scoreTarget}'),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (view.score / view.scoreTarget).clamp(0.0, 1.0),
            minHeight: 5,
            color: const Color(0xFFFFD65B),
            backgroundColor: Colors.white24,
          ),
        ),
      ],
    ),
  );

  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _goals(BuildContext context, MatchView view) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in view.targets.entries)
        _goal(
          context,
          S.matchAnimalNames[entry.key],
          '${view.collected[entry.key].clamp(0, entry.value)} / ${entry.value}',
          view.collected[entry.key] >= entry.value,
          SizedBox(
            width: 32,
            height: 32,
            child: CustomPaint(
              painter: AnimalPiecePainter(
                piece: Piece(entry.key + 1, entry.key),
                clock: const AlwaysStoppedAnimation(0),
                animated: false,
              ),
            ),
          ),
        ),
      _goal(
        context,
        S.matchIce,
        '${view.iceLeft}',
        view.iceLeft == 0,
        const Icon(Icons.ac_unit_rounded, color: Color(0xFF73B9D8), size: 28),
      ),
    ],
  );

  Widget _goal(
    BuildContext context,
    String label,
    String value,
    bool done,
    Widget icon,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        if (done) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: Color(0xFF469D78),
          ),
        ],
      ],
    ),
  );

  Widget _team(BuildContext context) {
    final engine = this.engine!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          engine.pendingAction.value || !engine.synchronized.value
              ? S.matchSynchronizing
              : engine.currentPlayer.value == engine.identity
              ? S.matchYourTurn
              : S.matchPlayerTurn(
                  engine.participants[engine.currentPlayer.value] ?? '',
                ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final id in (engine.participants.keys.toList()..sort()))
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  id == engine.currentPlayer.value
                      ? Icons.play_arrow_rounded
                      : Icons.person_outline,
                  size: 18,
                ),
                label: Text(engine.participants[id]!),
                backgroundColor: id == engine.currentPlayer.value
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _result(BuildContext context, MatchView view) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            view.status == MatchStatus.won
                ? Icons.emoji_events_rounded
                : Icons.eco_rounded,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            view.status == MatchStatus.won ? S.matchWon : S.matchLost,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: engine == null ? manager.restart : onExit,
            child: Text(engine == null ? S.matchNewRound : S.matchBackToRoom),
          ),
        ],
      ),
    ),
  );

  void _showChat(BuildContext context) {
    final engine = this.engine!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: Column(
            children: [
              ListTile(
                title: Text(S.matchTeamChat),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ),
              Expanded(
                child: MessageList(
                  identity: engine.identity,
                  userName: engine.userName,
                  messageList: engine.gameMessageList,
                ),
              ),
              SafeArea(
                top: false,
                child: MessageInput(onSendText: engine.sendGameText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
