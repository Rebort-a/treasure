import 'dart:math';

import 'package:flutter/material.dart';

class Joystick extends StatefulWidget {
  /// 方向改变回调函数，参数为弧度值（-π 到 π）
  final void Function(double radians) onDrag;

  /// 松手回调函数，当摇杆被释放时调用
  final void Function() onRelease;

  /// 摇杆球图标（可选，如开火按钮）
  final IconData? icon;

  /// 摇杆球颜色（可选）
  final Color? color;

  const Joystick({
    super.key,
    required this.onDrag,
    required this.onRelease,
    this.icon,
    this.color,
  });

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double _baseRadius = 60;
  static const double _stickRadius = 30;

  Offset _stickPosition = Offset.zero;
  double _currentRadians = 0;

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
              decoration: BoxDecoration(
                color: widget.color ?? Colors.grey,
                shape: BoxShape.circle,
              ),
              child: widget.icon != null
                  ? Icon(widget.icon, color: Colors.white, size: 24)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    _updateStickPosition(details.localPosition);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateStickPosition(details.localPosition);
  }

  void _onDragEnd(DragEndDetails _) {
    setState(() {
      _stickPosition = Offset.zero;
      _currentRadians = 0;
    });
    widget.onRelease();
  }

  void _updateStickPosition(Offset localPosition) {
    final centerOffset = Offset(_baseRadius, _baseRadius);
    final relativePosition = localPosition - centerOffset;
    final distance = relativePosition.distance;

    // 计算弧度值（-π 到 π）
    final radians = atan2(relativePosition.dy, relativePosition.dx);

    // 限制摇杆在基座范围内
    final clampedPosition = distance > _baseRadius
        ? Offset(cos(radians) * _baseRadius, sin(radians) * _baseRadius)
        : relativePosition;

    if (_currentRadians != radians) {
      _currentRadians = radians;
      widget.onDrag(radians);
    }

    setState(() {
      _stickPosition = clampedPosition;
    });
  }
}
