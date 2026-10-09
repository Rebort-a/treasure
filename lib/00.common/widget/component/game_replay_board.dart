import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// 单机、联机共用的棋盘结算显示，只在中央提示下绘制固定底板。
/// 结束或等待时仍锁定整个棋盘操作，不负责匹配、状态重置或路由跳转。
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
          // 无边距定位沿用 Stack 的居中对齐，底板不参与棋盘尺寸计算。
          Positioned(
            child: SizedBox.square(
              key: const ValueKey('game-replay-panel'),
              dimension: 96,
              child: ColoredBox(
                color: Colors.grey.withValues(alpha: 0.55),
                child: Center(
                  child: waiting || preparing
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  preparing ? S.wait : S.matchingPlayers,
                                ),
                              ),
                            ],
                          ),
                        )
                      : IconButton(
                          key: const ValueKey('round-replay'),
                          tooltip: S.restartGame,
                          iconSize: 96,
                          padding: EdgeInsets.zero,
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: onReplay,
                          icon: const Icon(Icons.replay_circle_filled),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
