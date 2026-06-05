import 'dart:math';

import 'package:flutter/material.dart';

import 'base.dart';

class DrawRegion extends StatelessWidget {
  final int identity;
  final Color backgroundColor;
  final Map<int, Snake> snakes;
  final List<GridEntry> foods;

  const DrawRegion({
    super.key,
    required this.identity,
    required this.backgroundColor,
    required this.snakes,
    required this.foods,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final viewOffset =
            snakes[identity]?.calculateViewOffset(viewSize) ?? Offset.zero;

        return Stack(
          children: [
            Container(
              color: backgroundColor,
              child: CustomPaint(
                painter: BackgroundPainter(viewOffset: viewOffset),
                size: viewSize,
              ),
            ),
            CustomPaint(
              painter: SnakePainter(
                viewOffset: viewOffset,
                snakes: snakes.values.toList(),
              ),
              size: viewSize,
            ),
            CustomPaint(
              painter: FoodPainter(viewOffset: viewOffset, foods: foods),
              size: viewSize,
            ),
          ],
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final Offset viewOffset;

  BackgroundPainter({required this.viewOffset});

  @override
  void paint(Canvas canvas, Size size) {
    _drawColor(canvas);
    _drawGrid(canvas, size);
    _drawBounds(canvas);
  }

  void _drawColor(Canvas canvas) {
    final mapRect = Rect.fromLTWH(
      -viewOffset.dx,
      -viewOffset.dy,
      mapWidth,
      mapHeight,
    );
    canvas.drawRect(mapRect, Paint()..color = Colors.green[900]!);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const gridSize = 50.0;
    final viewRect = Rect.fromLTRB(
      viewOffset.dx,
      viewOffset.dy,
      viewOffset.dx + size.width,
      viewOffset.dy + size.height,
    );

    // Vertical lines
    for (
      double x = _alignCoordinate(viewRect.left, gridSize);
      x <= viewRect.right;
      x += gridSize
    ) {
      if (x < 0 || x > mapWidth) continue;

      final lineStart = Offset(
        x - viewOffset.dx,
        max(0, viewOffset.dy) - viewOffset.dy,
      );
      final lineEnd = Offset(
        x - viewOffset.dx,
        min(mapHeight, viewOffset.dy + size.height) - viewOffset.dy,
      );
      canvas.drawLine(lineStart, lineEnd, gridPaint);
    }

    // Horizontal lines
    for (
      double y = _alignCoordinate(viewRect.top, gridSize);
      y <= viewRect.bottom;
      y += gridSize
    ) {
      if (y < 0 || y > mapHeight) continue;

      final lineStart = Offset(
        max(0, viewOffset.dx) - viewOffset.dx,
        y - viewOffset.dy,
      );
      final lineEnd = Offset(
        min(mapWidth, viewOffset.dx + size.width) - viewOffset.dx,
        y - viewOffset.dy,
      );
      canvas.drawLine(lineStart, lineEnd, gridPaint);
    }
  }

  double _alignCoordinate(double value, double grid) =>
      (value / grid).floor() * grid;

  void _drawBounds(Canvas canvas) {
    final boundsPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(
      Rect.fromLTWH(-viewOffset.dx, -viewOffset.dy, mapWidth, mapHeight),
      boundsPaint,
    );
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) =>
      oldDelegate.viewOffset != viewOffset;
}

class SnakePainter extends CustomPainter {
  final Offset viewOffset;
  final List<Snake> snakes;

  SnakePainter({required this.viewOffset, required this.snakes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final snake in snakes) {
      _drawSnakeBody(canvas, snake);
      _drawSnakeHead(canvas, snake);
    }
  }

  void _drawSnakeBody(Canvas canvas, Snake snake) {
    if (snake.body.length < 2) return;

    final path = Path();
    final first = snake.body.first - viewOffset;
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < snake.body.length; i++) {
      final point = snake.body[i] - viewOffset;
      path.lineTo(point.dx, point.dy);
    }

    final paint = Paint()
      ..color = snake.style.bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = snake.style.bodySize * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  void _drawSnakeHead(Canvas canvas, Snake snake) {
    final headPaint = Paint()
      ..color = snake.style.headColor
      ..style = PaintingStyle.fill;

    final eyePaint = Paint()
      ..color = snake.style.eyeColor
      ..style = PaintingStyle.fill;

    final headPosition = snake.head - viewOffset;
    canvas.drawCircle(headPosition, snake.style.headSize, headPaint);

    final eyeDistance = snake.style.headSize * 0.6;
    final eyeSize = snake.style.headSize * 0.3;

    final eye1Position = Offset(
      headPosition.dx + cos(snake.angle - pi / 4) * eyeDistance,
      headPosition.dy + sin(snake.angle - pi / 4) * eyeDistance,
    );

    final eye2Position = Offset(
      headPosition.dx + cos(snake.angle + pi / 4) * eyeDistance,
      headPosition.dy + sin(snake.angle + pi / 4) * eyeDistance,
    );

    canvas.drawCircle(eye1Position, eyeSize, eyePaint);
    canvas.drawCircle(eye2Position, eyeSize, eyePaint);
  }

  @override
  bool shouldRepaint(SnakePainter oldDelegate) {
    if (oldDelegate.viewOffset != viewOffset) return true;
    if (oldDelegate.snakes.length != snakes.length) return true;

    for (int i = 0; i < snakes.length; i++) {
      final oldSnake = oldDelegate.snakes[i];
      final newSnake = snakes[i];

      if (oldSnake.head != newSnake.head ||
          oldSnake.style != newSnake.style ||
          oldSnake.body.length != newSnake.body.length ||
          (oldSnake.body.isNotEmpty &&
              newSnake.body.isNotEmpty &&
              (oldSnake.body.first != newSnake.body.first ||
                  oldSnake.body.last != newSnake.body.last))) {
        return true;
      }
    }
    return false;
  }
}

class FoodPainter extends CustomPainter {
  final Offset viewOffset;
  final List<GridEntry> foods;

  FoodPainter({required this.viewOffset, required this.foods});

  @override
  void paint(Canvas canvas, Size size) {
    final foodPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    for (final food in foods) {
      final position = food.position - viewOffset;
      canvas.drawCircle(position, food.radius, foodPaint);
    }
  }

  @override
  bool shouldRepaint(FoodPainter oldDelegate) {
    return oldDelegate.viewOffset != viewOffset ||
        !_listsEqual(oldDelegate.foods, foods);
  }

  bool _listsEqual(List<GridEntry> a, List<GridEntry> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].position != b[i].position) return false;
    }
    return true;
  }
}
