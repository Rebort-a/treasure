import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/match_board.dart';
import 'animal_piece.dart';

/// 奖励步数转特效的连线仅绘制在棋盘内，不跨越页面布局或参与命中测试。
class MatchBonusTransfer extends StatelessWidget {
  final BoardFrame frame;
  final bool animated;

  const MatchBonusTransfer({
    super.key,
    required this.frame,
    required this.animated,
  });

  @override
  Widget build(BuildContext context) {
    if (!animated ||
        frame.phase != FramePhase.bonus ||
        frame.convertedPieceIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = frame.pieces.indexWhere(
      (piece) => piece != null && frame.convertedPieceIds.contains(piece.id),
    );
    if (index < 0) return const SizedBox.shrink();
    final piece = frame.pieces[index]!;
    return IgnorePointer(
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(piece.id),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          builder: (_, progress, _) => CustomPaint(
            painter: _BonusTransferPainter(index, piece.kind, progress),
          ),
        ),
      ),
    );
  }
}

class _BonusTransferPainter extends CustomPainter {
  final int index;
  final int kind;
  final double progress;

  _BonusTransferPainter(this.index, this.kind, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / MatchBoard.side;
    // 步数面板在顶部左栏，连线从对应方向的棋盘上边缘进入。
    final origin = Offset(size.width / 6, 0);
    final target = Offset(
      (index % MatchBoard.side + 0.5) * cell,
      (index ~/ MatchBoard.side + 0.5) * cell,
    );
    final head = Offset.lerp(origin, target, progress)!;
    final fade = (1 - progress) * 0.8;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFD65B).withValues(alpha: fade)
      ..strokeWidth = math.max(2, cell * 0.07);
    canvas.drawLine(origin, head, paint);
    paint
      ..color = Colors.white.withValues(alpha: 1 - progress)
      ..strokeWidth = math.max(1, cell * 0.025);
    canvas.drawLine(origin, head, paint);
    paint.color = AnimalPiecePainter.palette[kind].withValues(
      alpha: 1 - progress,
    );
    canvas.drawCircle(head, cell * 0.1, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.04
      ..color = const Color(0xFFFFD65B).withValues(alpha: fade);
    canvas.drawCircle(target, cell * (0.12 + progress * 0.35), paint);
  }

  @override
  bool shouldRepaint(_BonusTransferPainter oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.kind != kind ||
      oldDelegate.progress != progress;
}
