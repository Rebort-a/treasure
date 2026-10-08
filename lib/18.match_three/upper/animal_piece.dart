import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/match_board.dart';

/// 原创矢量小动物。所有棋子共享棋盘的一个动画时钟，只重绘 Canvas。
///
/// 不依赖图片资源或逐格计时器；待机时整体轻微上下浮动，眨眼仅影响表情展示。
class AnimalPiecePainter extends CustomPainter {
  static const palette = [
    Color(0xFF58C994),
    Color(0xFFF49C52),
    Color(0xFF78BCEB),
    Color(0xFFF2CC59),
    Color(0xFFF28CAE),
    Color(0xFFB77A52),
  ];

  final Piece piece;
  final Animation<double> clock;
  final bool animated;

  AnimalPiecePainter({
    required this.piece,
    required this.clock,
    this.animated = true,
  }) : super(repaint: animated ? clock : null);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 64 * 0.78;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    final phase = animated ? (clock.value + piece.id * 0.173) % 1 : 0.25;
    final wave = animated ? math.sin(phase * math.pi * 2) : 0.0;
    canvas.translate(0, wave * 1.0);
    final color = palette[piece.kind];
    final paint = Paint()..isAntiAlias = true;
    canvas.drawOval(
      const Rect.fromLTWH(-22, 21, 44, 6),
      paint..color = Colors.black.withValues(alpha: 0.12),
    );

    if (piece.kind == 1 || piece.kind == 2) {
      for (final sign in [-1.0, 1.0]) {
        final ear = Path()
          ..moveTo(sign * 9, -16)
          ..lineTo(sign * 23, -29)
          ..lineTo(sign * 24, -7)
          ..close();
        canvas.drawPath(ear, paint..color = color);
        canvas.drawCircle(
          Offset(sign * 17, -16),
          4,
          paint..color = const Color(0xFFFFCDD2),
        );
      }
    } else if (piece.kind == 0 || piece.kind == 4 || piece.kind == 5) {
      for (final sign in [-1.0, 1.0]) {
        canvas.drawCircle(
          Offset(sign * 16, -17),
          piece.kind == 5 ? 10 : 9,
          paint..color = color,
        );
        if (piece.kind == 5) {
          canvas.drawCircle(
            Offset(sign * 16, -17),
            5,
            paint..color = const Color(0xFFFFD9A6),
          );
        }
        if (piece.kind == 4) {
          canvas.drawCircle(
            Offset(sign * 16, -18),
            4,
            paint..color = const Color(0xFFFFC3D5),
          );
        }
      }
    } else {
      canvas.drawOval(
        const Rect.fromLTWH(-3, -28, 7, 16),
        paint..color = const Color(0xFFF4A350),
      );
    }
    final face = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-24, -21, 48, 46),
      const Radius.circular(18),
    );
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(color, Colors.white, 0.30)!, color],
    ).createShader(face.outerRect);
    canvas.drawRRect(face, paint);
    paint.shader = null;
    canvas.drawOval(
      const Rect.fromLTWH(-17, 0, 34, 22),
      paint..color = Colors.white.withValues(alpha: 0.72),
    );
    final closed = animated && phase > 0.93 && phase < 0.985;
    final foxWinkMoment =
        animated && piece.kind == 1 && phase > 0.46 && phase < 0.52;
    for (final sign in [-1.0, 1.0]) {
      final foxWink = foxWinkMoment && sign > 0;
      final foxOpenEye = foxWinkMoment && sign < 0;
      if (piece.kind == 1) {
        if (foxOpenEye) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(sign * 10, -3), width: 5, height: 7),
            paint..color = const Color(0xFF354052),
          );
          canvas.drawCircle(
            Offset(sign * 10 + 0.6, -4.5),
            1.1,
            paint..color = Colors.white,
          );
        } else {
          paint
            ..color = const Color(0xFF354052)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round;
          final eyeX = sign * 10;
          final eye = Path()
            ..moveTo(eyeX - (foxWink ? 4 : 3), -2)
            ..quadraticBezierTo(eyeX, foxWink ? -9 : -6, eyeX + 3, -2);
          canvas.drawPath(eye, paint);
          if (foxWink) {
            canvas.drawLine(Offset(eyeX + 3, -2), Offset(eyeX + 5, -5), paint);
          }
          paint.style = PaintingStyle.fill;
        }
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(sign * 10, -3),
            width: 5,
            height: closed ? 1.2 : 7,
          ),
          paint..color = const Color(0xFF354052),
        );
        if (!closed) {
          canvas.drawCircle(
            Offset(sign * 10 + 0.6, -4.5),
            1.1,
            paint..color = Colors.white,
          );
        }
      }
      canvas.drawOval(
        Rect.fromCenter(center: Offset(sign * 17, 6), width: 7, height: 4),
        paint..color = const Color(0xFFFF7D9B).withValues(alpha: 0.55),
      );
    }
    if (piece.kind == 4) {
      canvas.drawOval(
        const Rect.fromLTWH(-8, 3, 16, 9),
        paint..color = const Color(0xFFF28CAE),
      );
      for (final x in [-3.0, 3.0]) {
        canvas.drawCircle(
          Offset(x, 7),
          1.4,
          paint..color = const Color(0xFFAB5274),
        );
      }
    } else if (piece.kind == 5) {
      canvas.drawOval(
        const Rect.fromLTWH(-9, 3, 18, 12),
        paint..color = const Color(0xFFFFE7C4),
      );
      canvas.drawOval(
        const Rect.fromLTWH(-3, 3, 6, 4),
        paint..color = const Color(0xFF70432F),
      );
      canvas.drawLine(
        const Offset(0, 7),
        const Offset(0, 9),
        paint
          ..color = const Color(0xFF70432F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        const Rect.fromLTWH(-3, 7, 6, 4),
        0,
        math.pi,
        false,
        paint,
      );
      paint.style = PaintingStyle.fill;
    } else if (piece.kind == 3) {
      canvas.drawPath(
        Path()
          ..moveTo(-5, 3)
          ..lineTo(5, 3)
          ..lineTo(0, 9)
          ..close(),
        paint..color = const Color(0xFFE99139),
      );
    } else if (piece.kind == 0) {
      paint
        ..color = const Color(0xFF354052)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        const Rect.fromLTWH(-5, 4, 10, 7),
        0,
        math.pi,
        false,
        paint,
      );
      paint.style = PaintingStyle.fill;
    } else if (piece.kind == 2) {
      final catHissing = animated && phase > 0.46 && phase < 0.52;
      if (catHissing) {
        canvas.drawCircle(
          const Offset(0, 7),
          4,
          paint..color = const Color(0xFF354052),
        );
        canvas.drawCircle(
          const Offset(0, 7),
          2,
          paint..color = const Color(0xFFF28CAE),
        );
      } else {
        canvas.drawLine(
          const Offset(-4, 7),
          const Offset(4, 7),
          paint
            ..color = const Color(0xFF354052)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7
            ..strokeCap = StrokeCap.round,
        );
        paint.style = PaintingStyle.fill;
      }
    } else {
      paint
        ..color = const Color(0xFF354052)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        const Rect.fromLTWH(-5, 4, 10, 7),
        0,
        math.pi,
        false,
        paint,
      );
      paint.style = PaintingStyle.fill;
    }
    if (piece.effect != PieceEffect.none) {
      final effectColor = switch (piece.effect) {
        PieceEffect.none => Colors.white,
        PieceEffect.row => const Color(0xFF49C6D8),
        PieceEffect.column => const Color(0xFF6688F5),
        PieceEffect.bomb => const Color(0xFFFF8A3D),
        PieceEffect.rainbow => const Color(0xFFE15AA7),
      };
      paint
        ..color = effectColor.withValues(alpha: 0.96)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(face.inflate(2), paint);
      if (piece.effect == PieceEffect.row ||
          piece.effect == PieceEffect.column) {
        final vertical = piece.effect == PieceEffect.column;
        for (final offset in [-3.0, 3.0]) {
          canvas.drawLine(
            vertical ? Offset(offset, 15) : Offset(-13, 18 + offset),
            vertical ? Offset(offset, 25) : Offset(13, 18 + offset),
            paint,
          );
        }
      } else if (piece.effect == PieceEffect.bomb) {
        canvas.drawCircle(const Offset(0, 21), 7, paint);
      } else {
        paint.style = PaintingStyle.fill;
        for (var i = 0; i < palette.length; i++) {
          canvas.drawCircle(
            Offset(-15 + i * 6, 20),
            3.5,
            paint..color = palette[i],
          );
        }
      }
      paint.style = PaintingStyle.fill;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AnimalPiecePainter oldDelegate) =>
      oldDelegate.piece != piece ||
      oldDelegate.animated != animated ||
      oldDelegate.clock != clock;
}
