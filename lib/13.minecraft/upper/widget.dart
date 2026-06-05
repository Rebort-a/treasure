import 'package:flutter/material.dart';

import '../base/vector.dart';
import '../base/constant.dart';

/// 移动端控制组件
class MobileControls extends StatelessWidget {
  final Function(Vector2) onMove;
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
  final Function(Vector2) onMove;

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
