import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/match_board.dart';
import '../middle/match_manager.dart';
import 'animal_piece.dart';

/// 彩虹与奖励步数共用转换连线，仅在棋盘内绘制且不参与命中测试。
class MatchConversionTransfer extends StatelessWidget {
  final BoardFrame frame;
  final bool animated;
  final VoidCallback? onCompleted;

  const MatchConversionTransfer({
    super.key,
    required this.frame,
    required this.animated,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (!animated ||
        frame.phase != FramePhase.transfer ||
        frame.transferringPieceIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(frame),
          tween: Tween(begin: 0, end: 1),
          duration: MatchManager.conversionTransferDuration,
          curve: Curves.easeInOutCubic,
          onEnd: onCompleted,
          builder: (_, progress, _) =>
              CustomPaint(painter: _ConversionTransferPainter(frame, progress)),
        ),
      ),
    );
  }
}

class _ConversionTransferPainter extends CustomPainter {
  final BoardFrame frame;
  final double progress;

  _ConversionTransferPainter(this.frame, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / MatchBoard.side;
    Offset center(int index) => Offset(
      (index % MatchBoard.side + 0.5) * cell,
      (index ~/ MatchBoard.side + 0.5) * cell,
    );
    final sourceId = frame.transferSourcePieceId;
    final sourceIndex = sourceId == null
        ? -1
        : frame.pieces.indexWhere((piece) => piece?.id == sourceId);
    if (sourceId != null && sourceIndex < 0) return;
    // 彩虹从自身位置发出连线；步数从顶部左栏对应的棋盘边缘进入。
    final origin = sourceId == null
        ? Offset(size.width / 6, 0)
        : center(sourceIndex);
    for (var index = 0; index < frame.pieces.length; index++) {
      final piece = frame.pieces[index];
      if (piece == null || !frame.transferringPieceIds.contains(piece.id)) {
        continue;
      }
      final target = center(index);
      final head = Offset.lerp(origin, target, progress)!;
      final color = sourceId == null
          ? const Color(0xFFFFD65B)
          : AnimalPiecePainter.palette[piece.kind];
      // 完整路径标明所有终点，亮线同时延长，到达前目标动物保持普通状态。
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = math.max(1, cell * 0.035);
      canvas.drawLine(origin, target, paint);
      paint
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = math.max(2, cell * 0.07);
      canvas.drawLine(origin, head, paint);
      paint
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = math.max(1, cell * 0.025);
      canvas.drawLine(origin, head, paint);
      paint.color = AnimalPiecePainter.palette[piece.kind];
      canvas.drawCircle(head, cell * 0.1, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.04
        ..color = color.withValues(alpha: 0.8);
      canvas.drawCircle(target, cell * (0.12 + progress * 0.35), paint);
    }
  }

  @override
  bool shouldRepaint(_ConversionTransferPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.progress != progress;
}
