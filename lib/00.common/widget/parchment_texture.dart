import 'dart:math';

import 'package:flutter/material.dart';

// 羊皮纸噪点纹理
class ParchmentTexture extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    // 生成随机噪点（模拟纸张纹理）
    final random = Random();
    for (int i = 0; i < 1000; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 0.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // 生成细微线条（模拟纸张纤维）
    for (int i = 0; i < 200; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final endX = startX + random.nextDouble() * 20;
      final endY = startY + random.nextDouble() * 5;
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint..strokeWidth = 0.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
