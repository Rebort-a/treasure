import 'package:flutter/material.dart';

class CircleButton extends StatefulWidget {
  final Function(bool) onToggle;
  final IconData icon;

  const CircleButton({super.key, required this.onToggle, required this.icon});

  @override
  State<CircleButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleButton> {
  bool _isPressed = false;
  static const double _buttonRadius = 60;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _update(true),
      onTapUp: (_) => _update(false),
      onTapCancel: () => _update(false),
      child: Container(
        width: _buttonRadius * 2,
        height: _buttonRadius * 2,
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.black.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
        child: Center(child: Icon(widget.icon, color: Colors.white, size: 30)),
      ),
    );
  }

  void _update(bool isPressed) {
    widget.onToggle(isPressed);
    setState(() {
      _isPressed = isPressed;
    });
  }
}
