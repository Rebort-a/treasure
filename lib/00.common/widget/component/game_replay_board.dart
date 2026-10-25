import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// 单机、联机共用的棋盘结算显示，只在中央提示下绘制固定底板。
/// 结束或等待时仍锁定整个棋盘操作，不负责匹配、状态重置或路由跳转。
class GameReplayBoard extends StatefulWidget {
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
  State<GameReplayBoard> createState() => _GameReplayBoardState();
}

class _GameReplayBoardState extends State<GameReplayBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _appearance;
  Timer? _delay;
  bool _visible = false;

  bool get _waiting => widget.waiting || widget.preparing;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _appearance = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _updatePresentation();
  }

  @override
  void didUpdateWidget(covariant GameReplayBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.finished != widget.finished ||
        oldWidget.waiting != widget.waiting ||
        oldWidget.preparing != widget.preparing) {
      _updatePresentation();
    }
  }

  void _updatePresentation() {
    _delay?.cancel();
    if (_waiting) {
      _visible = true;
      _controller.forward();
    } else if (!widget.finished) {
      _visible = false;
      _controller.reset();
    } else if (!_visible) {
      // 先保留最终棋盘供玩家查看，延时期间仍立即阻止棋盘操作。
      _delay = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _visible = true);
        _controller.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _appearance.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = widget.finished || _waiting;
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeFocus(
          excluding: blocked,
          child: AbsorbPointer(absorbing: blocked, child: widget.child),
        ),
        if (_visible)
          // 无边距定位沿用 Stack 的居中对齐，底板不参与棋盘尺寸计算。
          Positioned(
            child: FadeTransition(
              opacity: _appearance,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1).animate(_appearance),
                child: SizedBox.square(
                  key: const ValueKey('game-replay-panel'),
                  dimension: 96,
                  child: ColoredBox(
                    color: Colors.grey.withValues(alpha: 0.55),
                    child: Center(
                      child: _waiting
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
                                      widget.preparing
                                          ? S.wait
                                          : S.matchingPlayers,
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
                              onPressed: widget.onReplay,
                              icon: const Icon(Icons.replay_circle_filled),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
