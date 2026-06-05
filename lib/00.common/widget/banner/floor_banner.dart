import 'dart:async';

import 'package:flutter/material.dart';

class FloorBanner extends StatefulWidget {
  final String text;
  final Duration duration;

  const FloorBanner({
    super.key,
    required this.text,
    this.duration = const Duration(seconds: 1),
  });

  @override
  State<FloorBanner> createState() => _FloorBannerState();
}

class _FloorBannerState extends State<FloorBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isVisible = true;
  Timer? _hideTimer; // 添加计时器引用

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _showBanner();
  }

  // 添加文本变化监听
  @override
  void didUpdateWidget(FloorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当文本变化时重新显示横幅
    if (widget.text != oldWidget.text) {
      _resetAndShow();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel(); // 取消计时器
    _animationController.dispose();
    super.dispose();
  }

  void _showBanner() {
    _animationController.forward();
    // 保存计时器引用以便取消
    _hideTimer = Timer(widget.duration, _hideBanner);
  }

  void _hideBanner() {
    if (!mounted) return;

    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  // 重置状态并重新显示
  void _resetAndShow() {
    _hideTimer?.cancel(); // 取消之前的计时器
    _animationController.reset();

    setState(() => _isVisible = true);
    _showBanner();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
