import 'dart:ui';

import 'package:flutter/material.dart';

import 'base.dart';
import 'manager.dart';

class SoftPage extends StatelessWidget {
  final _manager = Manager();

  SoftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (_, __) {
        return Stack(
          children: [
            // 渲染层
            CustomPaint(
              painter: SoftTubePainter(cylinder: _manager.soft),
              size: Size.infinite,
            ),

            // 手势控制
            GestureDetector(
              onScaleUpdate: (details) => _manager.handleDrag(details),
              onDoubleTap: () => _manager.resetImmediate(),
            ),

            // 键盘监听
            KeyboardListener(
              focusNode: _manager.focusNode,
              onKeyEvent: _manager.handleKeyEvent,
              child: const SizedBox.expand(),
            ),
          ],
        );
      },
    );
  }
}

/// 软筒绘制器
class SoftTubePainter extends CustomPainter {
  final SoftTube cylinder;
  final bool showWireframe;

  SoftTubePainter({required this.cylinder, this.showWireframe = false});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawTube(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = HSLColor.fromAHSL(1.0, 200, 0.99, 0.08).toColor(),
    );

    // 添加渐变背景增强深度感
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        HSLColor.fromAHSL(1.0, 200, 0.99, 0.12).toColor(),
        HSLColor.fromAHSL(1.0, 200, 0.99, 0.05).toColor(),
      ],
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
  }

  void _drawTube(Canvas canvas, Size size) {
    final int particleCount = cylinder.particles.length;

    // 1. 计算所有面的深度（中心点 Z 值）
    final List<(int, Vector3)> quadDepths = [];
    for (int i = 0; i < particleCount; i++) {
      final center = cylinder.getQuadCenter(i);
      quadDepths.add((i, center));
    }

    // 2. 按 Z 值从远到近排序（远的先画，近的后画）
    quadDepths.sort((a, b) => b.$2.z.compareTo(a.$2.z));

    // 3. 创建一个临时层，用于深度测试
    final recorder = PictureRecorder();
    final canvas2d = Canvas(recorder);
    final paint = Paint();

    for (final (index, center) in quadDepths) {
      final quad = _getQuadPoints(index);
      if (quad == null) continue;

      final (points, _) = quad;
      final normal = _calculateNormal(points);

      // 背面剔除
      final viewDirection = (center - Constant.observer).normalized();
      final visibility = Vector3.dot(normal, viewDirection);
      if (visibility <= 0) continue;

      // 绘制面（不透明）
      final path = _createQuadPath(points, size);
      final lightIntensity = visibility.clamp(0.0, 1.0);
      final brightness = (lightIntensity * 80).clamp(15.0, 80.0);
      final lightness = brightness / 100.0;
      final saturation = 0.95 - (lightIntensity * 0.3);
      final hue = index % 2 == 0 ? 180.0 : 220.0;

      canvas2d.drawPath(
        path,
        paint
          ..style = PaintingStyle.fill
          ..color = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor()
          ..blendMode = BlendMode.srcOver, // 不透明覆盖
      );

      if (showWireframe) {
        canvas2d.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            // ..color = Colors.white.withAlpha((0.4 * 255).toInt()),
            ..color = HSLColor.fromAHSL(
              0.2,
              hue,
              saturation,
              lightness,
            ).toColor(),
        );
      }
    }

    // 4. 一次性绘制到主画布（避免覆盖）
    final picture = recorder.endRecording();
    canvas.drawPicture(picture);
  }

  (List<Vector3>, Vector3)? _getQuadPoints(int index) {
    final int particleCount = cylinder.particles.length;

    final currentIndex = index;
    final nextIndex = (index + 1) % particleCount;
    final oppositeIndex1 = (index + 3) % particleCount;
    final oppositeIndex2 = (index + 2) % particleCount;

    try {
      final point0 = cylinder.particles[currentIndex].position;
      final point1 = cylinder.particles[nextIndex].position;
      final point2 = cylinder.particles[oppositeIndex1].position;
      final point3 = cylinder.particles[oppositeIndex2].position;

      final center = Vector3(
        (point0.x + point1.x + point2.x + point3.x) / 4,
        (point0.y + point1.y + point2.y + point3.y) / 4,
        (point0.z + point1.z + point2.z + point3.z) / 4,
      );

      return ([point0, point1, point2, point3], center);
    } catch (e) {
      return null;
    }
  }

  Path _createQuadPath(List<Vector3> points, Size size) {
    final path = Path();
    path.moveTo(
      Constant.projectX(points[0], size),
      Constant.projectY(points[0], size),
    );

    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        Constant.projectX(points[i], size),
        Constant.projectY(points[i], size),
      );
    }

    path.close();
    return path;
  }

  Vector3 _calculateNormal(List<Vector3> points) {
    final edge1 = points[1] - points[0];
    final edge2 = points[3] - points[0];
    final normal = Vector3.cross(edge1, edge2);
    return normal.normalized();
  }

  @override
  bool shouldRepaint(covariant SoftTubePainter oldDelegate) => true;
}
