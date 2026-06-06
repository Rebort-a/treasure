import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../base/block.dart';
import '../base/vector.dart';
import '../base/constant.dart';

/// 移动端控制组件
class MobileControls extends StatelessWidget {
  final void Function(Vector2) onMove;
  final VoidCallback onJump;

  const MobileControls({super.key, required this.onMove, required this.onJump});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(left: 20, bottom: 20, child: Joystick(onMove: onMove)),
        Positioned(right: 20, bottom: 20, child: JumpButton(onPressed: onJump)),
      ],
    );
  }
}

/// 虚拟摇杆
class Joystick extends StatefulWidget {
  final void Function(Vector2) onMove;

  const Joystick({super.key, required this.onMove});

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double _baseRadius = Constants.joystickBaseRadius;
  static const double _stickRadius = Constants.joystickStickRadius;
  Offset _stickPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onDragStart,
      onPanUpdate: _onDragUpdate,
      onPanEnd: _onDragEnd,
      child: Container(
        width: _baseRadius * 2,
        height: _baseRadius * 2,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Transform.translate(
            offset: _stickPosition,
            child: Container(
              width: _stickRadius * 2,
              height: _stickRadius * 2,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) =>
      _updateStick(details.localPosition);
  void _onDragUpdate(DragUpdateDetails details) =>
      _updateStick(details.localPosition);

  void _onDragEnd(DragEndDetails _) {
    setState(() => _stickPosition = Offset.zero);
    widget.onMove(Vector2.zero);
  }

  void _updateStick(Offset localPosition) {
    final center = Offset(_baseRadius, _baseRadius);
    final relative = localPosition - center;
    final distance = relative.distance;

    final normalized = distance > 0 ? relative / distance : Offset.zero;
    final double clampedDistance = distance.clamp(0, _baseRadius);
    final clampedPosition = normalized * clampedDistance;

    widget.onMove(Vector2(normalized.dx, -normalized.dy));

    setState(() => _stickPosition = clampedPosition);
  }
}

/// 跳跃按钮
class JumpButton extends StatefulWidget {
  final VoidCallback onPressed;

  const JumpButton({super.key, required this.onPressed});

  @override
  State<JumpButton> createState() => _JumpButtonState();
}

class _JumpButtonState extends State<JumpButton> {
  bool _isPressed = false;
  static const double _buttonSize = Constants.jumpButtonSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: Container(
        width: _buttonSize * 2,
        height: _buttonSize * 2,
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.black.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(_buttonSize),
        ),
        child: const Center(
          child: Icon(Icons.arrow_upward, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  void _setPressed(bool pressed) {
    if (pressed) widget.onPressed();
    setState(() => _isPressed = pressed);
  }
}

/// 十字准星组件
class Crosshair extends StatelessWidget {
  const Crosshair({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: Constants.crosshairSize,
        height: Constants.crosshairSize,
        child: CustomPaint(painter: CrosshairPainter()),
      ),
    );
  }
}

/// 十字准星
class CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = Constants.crosshairStroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    const crossSize = Constants.crosshairCrossSize;

    canvas.drawLine(
      Offset(center.dx, center.dy - crossSize),
      Offset(center.dx, center.dy + crossSize),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - crossSize, center.dy),
      Offset(center.dx + crossSize, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 背包栏
class Hotbar extends StatelessWidget {
  final List<BlockType> slotTypes;
  final int Function(BlockType) getCount;
  final int selectedSlot;
  final void Function(int) onSelect;

  const Hotbar({
    super.key,
    required this.slotTypes,
    required this.getCount,
    required this.selectedSlot,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 竖屏缩放：9 格全宽 432px 超出手机宽度时按比例缩小
    final scale = screenWidth < 480 ? screenWidth / 480 : 1.0;
    final slotSize = 44.0 * scale;
    final margin = 2.0 * scale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4),
      color: Colors.black.withValues(alpha: 0.35),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(Constants.hotbarSlotCount, (i) {
          final type = i < slotTypes.length ? slotTypes[i] : null;
          final count = type != null ? getCount(type) : 0;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: _HotbarSlot(
              type: type,
              count: count,
              selected: i == selectedSlot,
              slotSize: slotSize,
              margin: margin,
            ),
          );
        }),
      ),
    );
  }
}

class _HotbarSlot extends StatelessWidget {
  final BlockType? type;
  final int count;
  final bool selected;
  final double slotSize;
  final double margin;

  const _HotbarSlot({
    required this.type,
    required this.count,
    required this.selected,
    this.slotSize = 44,
    this.margin = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: slotSize,
      height: slotSize,
      margin: EdgeInsets.symmetric(horizontal: margin),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.25),
        border: Border.all(
          color: selected ? Colors.white : Colors.white24,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: type != null
          ? Stack(
              children: [
                Center(
                  child: CustomPaint(
                    size: const Size(24, 24),
                    painter: _BlockIconPainter(type!),
                  ),
                ),
                if (count > 1)
                  Positioned(
                    right: 2,
                    bottom: 1,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 2, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

/// 方块等距图标绘制
class _BlockIconPainter extends CustomPainter {
  final BlockType type;
  _BlockIconPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.38;

    final baseColor = type.color.withValues(alpha: 1.0);
    final topColor = baseColor;
    final leftColor = Color.fromARGB(
      baseColor.a.toInt(),
      (baseColor.r * 0.7).toInt(),
      (baseColor.g * 0.7).toInt(),
      (baseColor.b * 0.7).toInt(),
    );
    final rightColor = Color.fromARGB(
      baseColor.a.toInt(),
      (baseColor.r * 0.5).toInt(),
      (baseColor.g * 0.5).toInt(),
      (baseColor.b * 0.5).toInt(),
    );

    // 顶面
    final top = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + s, cy - s / 2)
      ..lineTo(cx, cy)
      ..lineTo(cx - s, cy - s / 2)
      ..close();
    canvas.drawPath(top, Paint()..color = topColor);

    // 左面
    final left = Path()
      ..moveTo(cx - s, cy - s / 2)
      ..lineTo(cx, cy)
      ..lineTo(cx, cy + s)
      ..lineTo(cx - s, cy + s / 2)
      ..close();
    canvas.drawPath(left, Paint()..color = leftColor);

    // 右面
    final right = Path()
      ..moveTo(cx + s, cy - s / 2)
      ..lineTo(cx, cy)
      ..lineTo(cx, cy + s)
      ..lineTo(cx + s, cy + s / 2)
      ..close();
    canvas.drawPath(right, Paint()..color = rightColor);

    // 边框
    final outline = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawPath(top, outline);
    canvas.drawPath(left, outline);
    canvas.drawPath(right, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 方块破坏进度指示器（十字准星处圆环）
class DestroyProgressIndicator extends StatelessWidget {
  final double progress;

  const DestroyProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    return CustomPaint(
      size: const Size(36, 36),
      painter: _DestroyProgressPainter(progress),
    );
  }
}

class _DestroyProgressPainter extends CustomPainter {
  final double progress;
  _DestroyProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 背景圆环
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 进度弧
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DestroyProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
