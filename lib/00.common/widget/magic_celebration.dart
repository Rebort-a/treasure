import 'package:flutter/material.dart';

import '../style/theme.dart';

class MagicCelebrationAnimation extends StatefulWidget {
  const MagicCelebrationAnimation({super.key});

  @override
  State<MagicCelebrationAnimation> createState() =>
      _MagicCelebrationAnimationState();
}

class _MagicCelebrationAnimationState extends State<MagicCelebrationAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 魔法粒子效果
            for (int i = 0; i < 8; i++)
              Positioned(
                child: Transform.rotate(
                  angle: i * 0.785 + _animation.value * 3.14,
                  child: Transform.scale(
                    scale: 0.5 + _animation.value * 0.5,
                    child: const Icon(
                      Icons.star,
                      color: MagicTheme.gold,
                      size: 32,
                    ),
                  ),
                ),
              ),
            // 中心魔法符号
            Transform.scale(
              scale: 1 + _animation.value * 0.2,
              child: const Icon(
                Icons.emoji_events,
                color: MagicTheme.gold,
                size: 48,
              ),
            ),
          ],
        );
      },
    );
  }
}
