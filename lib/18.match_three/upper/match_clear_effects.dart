import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/match_board.dart';
import 'animal_piece.dart';

/// 消除演出只读取帧快照，不改变棋盘，也不消耗内核的随机序列。
class MatchClearEffects extends StatefulWidget {
  final BoardFrame frame;

  const MatchClearEffects({super.key, required this.frame});

  @override
  State<MatchClearEffects> createState() => _MatchClearEffectsState();
}

class _MatchClearEffectsState extends State<MatchClearEffects>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool _animated = false;
  Set<int> _crackedIce = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animated = !MediaQuery.disableAnimationsOf(context);
    if (!_animated) {
      _clock.stop();
    } else if (widget.frame.phase == FramePhase.clear) {
      _clock.forward();
    }
  }

  @override
  void didUpdateWidget(MatchClearEffects oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.frame, oldWidget.frame)) return;
    _clock.stop();
    _crackedIce = {
      for (var i = 0; i < MatchBoard.cells; i++)
        if (oldWidget.frame.ice[i] > widget.frame.ice[i]) i,
    };
    if (_animated && widget.frame.phase == FramePhase.clear) {
      _clock.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_animated || widget.frame.phase != FramePhase.clear) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('match-clear-effects'),
          painter: MatchClearPainter(widget.frame, _clock, _crackedIce),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }
}

class MatchClearPainter extends CustomPainter {
  final BoardFrame frame;
  final Animation<double> progress;
  final Set<int> crackedIce;

  MatchClearPainter(this.frame, this.progress, this.crackedIce)
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / MatchBoard.side;
    final t = progress.value;
    final fade = 1 - t;
    final spread = Curves.easeOut.transform(t);
    final paint = Paint()..strokeCap = StrokeCap.round;
    Offset center(int index) => Offset(
      (index % MatchBoard.side + 0.5) * cell,
      (index ~/ MatchBoard.side + 0.5) * cell,
    );

    for (final index in frame.clearing) {
      final piece = frame.pieces[index];
      if (piece == null) continue;
      final origin = center(index);
      final color = AnimalPiecePainter.palette[piece.kind];
      paint
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: fade);
      // 小范围粒子保留棋盘可读性，避免每次三连都整屏闪光。
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + piece.id * 0.4;
        final distance = cell * (0.08 + spread * 0.42);
        canvas.drawCircle(
          origin +
              Offset(math.cos(angle), math.sin(angle)) * distance +
              Offset(0, t * t * cell * 0.15),
          cell * 0.055 * fade,
          paint,
        );
      }
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.07 * fade
        ..color = color.withValues(alpha: fade * 0.8);
      switch (piece.effect) {
        case PieceEffect.row:
          final reach = size.width * spread;
          canvas.drawLine(
            origin - Offset(reach, 0),
            origin + Offset(reach, 0),
            paint,
          );
        case PieceEffect.column:
          final reach = size.height * spread;
          canvas.drawLine(
            origin - Offset(0, reach),
            origin + Offset(0, reach),
            paint,
          );
        case PieceEffect.bomb:
          canvas.drawCircle(origin, cell * 1.5 * spread, paint);
          canvas.drawCircle(origin, cell * 0.85 * spread, paint);
        case PieceEffect.rainbow:
          // 连线对应实际被消除的格子，不猜测彩虹组合的规则结果。
          for (final target in frame.clearing) {
            if (target == index) continue;
            paint.color = AnimalPiecePainter
                .palette[frame.pieces[target]?.kind ?? piece.kind]
                .withValues(alpha: fade * 0.55);
            canvas.drawLine(
              origin,
              Offset.lerp(origin, center(target), spread)!,
              paint,
            );
          }
        case PieceEffect.none:
          break;
      }
    }
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFD9F5FF).withValues(alpha: fade);
    for (final index in crackedIce) {
      for (var i = 0; i < 4; i++) {
        final angle = math.pi / 4 + i * math.pi / 2;
        final position =
            center(index) +
            Offset(math.cos(angle), math.sin(angle)) * cell * spread * 0.48;
        canvas.save();
        canvas.translate(position.dx, position.dy);
        canvas.rotate(angle + t * 2);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: cell * 0.09 * fade,
            height: cell * 0.17 * fade,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(MatchClearPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.progress != progress ||
      oldDelegate.crackedIce != crackedIce;
}

/// 新棋子挂载时就从棋盘上方进入，而不是先停在格子上方等下一帧。
class MatchPieceEntrance extends StatelessWidget {
  final bool spawned;
  final bool animated;
  final int row;
  final double cell;
  final Widget child;

  const MatchPieceEntrance({
    super.key,
    required this.spawned,
    required this.animated,
    required this.row,
    required this.cell,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: spawned && animated ? 1 : 0, end: 0),
    duration: animated ? const Duration(milliseconds: 210) : Duration.zero,
    curve: Curves.easeOutBack,
    child: child,
    builder: (context, value, child) => Transform.translate(
      key: const ValueKey('match-piece-entrance'),
      // 落差大的补块也只轻微回弹，避免弹出目标格一整行。
      offset: Offset(
        0,
        (-cell * (row + 1) * value)
            .clamp(-cell * (row + 1), cell * 0.1)
            .toDouble(),
      ),
      child: child,
    ),
  );
}
