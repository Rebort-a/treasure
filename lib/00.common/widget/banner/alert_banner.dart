import 'package:flutter/material.dart';

class AlertBanner extends StatefulWidget {
  final String text;
  final Color color;
  final Duration duration;

  const AlertBanner({
    super.key,
    required this.text,
    this.color = Colors.redAccent,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

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
      child: SlideTransition(
        position: _slideAnimation,

        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(191),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.color.withAlpha(229),
                  width: 2,
                ),
              ),
              child: Text(
                widget.text,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
