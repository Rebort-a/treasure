import 'package:flutter/material.dart';

// 自定义网格绘制器
class GridBoundary extends CustomPainter {
  final int columnCount;
  final int rowCount;
  final Color lineColor;
  final double lineWidth;

  GridBoundary({
    required this.columnCount,
    required this.rowCount,
    required this.lineColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // 计算网格间距
    final double columnWidth = size.width / columnCount;
    final double rowHeight = size.height / rowCount;

    // 绘制垂直线
    for (int i = 0; i <= columnCount; i++) {
      final x = i * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 绘制水平线
    for (int i = 0; i <= rowCount; i++) {
      final y = i * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridBoundary oldDelegate) {
    // 只有当参数变化时才重绘
    return columnCount != oldDelegate.columnCount ||
        rowCount != oldDelegate.rowCount ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth;
  }
}
