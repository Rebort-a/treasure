import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// 单机、联机共用的棋盘结算显示，不负责匹配、状态重置或路由跳转。
class GameReplayBoard extends StatelessWidget {
  final bool finished;
  final bool waiting;
  final bool preparing;
  final VoidCallback onReplay;
  final Widget child;

  const GameReplayBoard({
    super.key,
    required this.finished,
    required this.onReplay,
    required this.child,
    this.waiting = false,
    this.preparing = false,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = finished || waiting || preparing;
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeFocus(
          excluding: blocked,
          child: AbsorbPointer(absorbing: blocked, child: child),
        ),
        if (blocked)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.grey.withValues(alpha: 0.55),
              child: Center(
                child: waiting || preparing
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(preparing ? S.wait : S.matchingPlayers),
                        ],
                      )
                    : IconButton(
                        key: const ValueKey('round-replay'),
                        tooltip: S.restartGame,
                        iconSize: 96,
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: onReplay,
                        icon: const Icon(Icons.replay_circle_filled),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
