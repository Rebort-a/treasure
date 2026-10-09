import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../widget/component/game_replay_board.dart';
import '../client/base/game_engine.dart';

/// 只在棋盘中央显示重开或等待底板，结束后仍允许使用页面导航和局内聊天。
class RoundReplayBoard extends StatelessWidget {
  final GameEngine engine;
  final Widget child;

  const RoundReplayBoard({
    super.key,
    required this.engine,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final replay = engine.roundReplay;
    if (replay == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: replay.finished,
      builder: (_, finished, _) => ValueListenableBuilder<bool>(
        valueListenable: replay.waiting,
        builder: (_, waiting, _) => ValueListenableBuilder<bool>(
          valueListenable: replay.preparing,
          builder: (_, preparing, _) => GameReplayBoard(
            finished: finished,
            waiting: waiting,
            preparing: preparing,
            onReplay: engine.requestReplay,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 投降只结束当前轮次，与返回聊天室的退出操作区分。
Future<void> confirmRoundSurrender(
  BuildContext context,
  GameEngine engine,
) async {
  if (!engine.isActive || (engine.roundReplay?.finished.value ?? true)) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(S.surrender),
      content: Text(S.confirmSurrender),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(S.confirm),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(S.cancel),
        ),
      ],
    ),
  );
  if (context.mounted && confirmed == true) engine.completeRound();
}
