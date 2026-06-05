import 'package:flutter/material.dart';

class TextBanner extends StatefulWidget {
  final String text;
  final Duration duration;

  const TextBanner({
    super.key,
    required this.text,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<TextBanner> createState() => _TextBannerState();
}

class _TextBannerState extends State<TextBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fadeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 1),
          TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1), weight: 1),
          TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 1, curve: Curves.easeInOut),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Text(
          widget.text,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF00C8),
            shadows: [Shadow(color: Color(0xFFFF00C8), blurRadius: 10)],
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
