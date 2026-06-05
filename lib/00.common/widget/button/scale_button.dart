import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScaleButton extends StatefulWidget {
  final Size size;
  final VoidCallback onPressed;
  final Widget? icon;
  final Color color;
  final bool enableLongPress;

  const ScaleButton({
    super.key,
    required this.size,
    required this.onPressed,
    this.icon,
    this.color = Colors.blue,
    this.enableLongPress = true,
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 100),
        )..addListener(() {
          setState(() {});
        });

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _cancelTimer();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      widget.onPressed();
      HapticFeedback.mediumImpact();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    widget.onPressed();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    // HapticFeedback.lightImpact();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onLongPress() {
    if (widget.enableLongPress) {
      _controller.forward();
      _startTimer();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _onLongPressUp();
  }

  void _onLongPressUp() {
    if (widget.enableLongPress) {
      _controller.reverse();
      _cancelTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: _onLongPress,
      onLongPressUp: _onLongPressUp,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressUp,
      child: Transform.scale(
        scale: _scaleAnimation.value,
        child: Container(
          width: widget.size.width,
          height: widget.size.height,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.5), // 阴影颜色
                spreadRadius: 0, // 阴影扩散半径
                blurRadius: 4, // 阴影模糊半径
                offset: const Offset(0, 4), // 阴影偏移量
              ),
            ],
          ),
          child: Center(child: widget.icon),
        ),
      ),
    );
  }
}
