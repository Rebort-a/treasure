import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/match_board.dart';
import '../middle/match_manager.dart';

/// 结算后的一次性撒花层，不占布局空间，也不拦截重开、聊天等操作。
class MatchCelebration extends StatefulWidget {
  /// 仅决定庆祝强度，不作为通关条件，也不保存历史成绩。
  static const richScoreThreshold = 3000;
  final MatchManager manager;
  final Widget child;

  const MatchCelebration({
    super.key,
    required this.manager,
    required this.child,
  });

  @override
  State<MatchCelebration> createState() => _MatchCelebrationState();
}

class _MatchCelebrationState extends State<MatchCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..addStatusListener(_onAnimationStatus);
  bool _celebrated = false;
  bool _visible = false;
  bool _reduceMotion = true;
  bool _rich = false;

  @override
  void initState() {
    super.initState();
    _listen(widget.manager, true);
  }

  void _listen(MatchManager manager, bool add) {
    for (final notifier in [manager.view, manager.busy, manager.bonusTime]) {
      if (add) {
        notifier.addListener(_sync);
      } else {
        notifier.removeListener(_sync);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(MatchCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      _listen(oldWidget.manager, false);
      _listen(widget.manager, true);
      _celebrated = false;
      _hide();
      _sync();
    }
  }

  void _hide() {
    _controller.stop();
    if (_visible) setState(() => _visible = false);
  }

  void _sync() {
    final manager = widget.manager;
    if (manager.view.value?.status != MatchStatus.won) {
      // 本地重开、联机清空快照或失败均立即撤下旧局特效。
      _celebrated = false;
      _hide();
      return;
    }
    if (_reduceMotion) _hide();
    // 胜利状态在奖励结算中已经成立，必须等最终提示真正出现。
    if (_celebrated || manager.busy.value || manager.bonusTime.value) return;
    _celebrated = true;
    if (_reduceMotion) return;
    _rich = manager.view.value!.score > MatchCelebration.richScoreThreshold;
    setState(() => _visible = true);
    _controller.forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _hide();
  }

  @override
  void dispose() {
    _listen(widget.manager, false);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_visible)
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('match-celebration'),
                painter: MatchConfettiPainter(_controller, rich: _rich),
              ),
            ),
          ),
        ),
    ],
  );
}

class MatchConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final bool rich;

  MatchConfettiPainter(this.animation, {required this.rich})
    : super(repaint: animation);

  static const _colors = [
    Color(0xFFFFCF55),
    Color(0xFFFF718F),
    Color(0xFF65DCC3),
    Color(0xFF74BFFF),
    Color(0xFFBA99FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 固定随机种子保证逐帧轨迹连续；彩纸从两侧向上喷出再自然落下。
    final random = math.Random(18);
    final elapsed = animation.value * 3.2;
    final scale = (size.width / 480).clamp(0.65, 1.3);
    final paint = Paint();
    for (var i = 0; i < (rich ? 112 : 80); i++) {
      final right = i.isOdd;
      final delay = random.nextDouble() * 0.45;
      final speedX = (65 + random.nextDouble() * 180) * scale;
      final speedY = (270 + random.nextDouble() * 170) * scale;
      final originY = size.height * (0.45 + random.nextDouble() * 0.14);
      final radius = (3 + random.nextDouble() * 4) * scale;
      final spin = random.nextDouble() * math.pi * 2;
      final color = rich && i % 3 == 0
          ? _colors.first
          : _colors[random.nextInt(_colors.length)];
      final t = elapsed - delay;
      if (t < 0) continue;
      final opacity = ((3.2 - elapsed) / 0.7).clamp(0.0, 1.0);
      final x = (right ? size.width : 0) + (right ? -1 : 1) * speedX * t;
      final y = originY - speedY * t + 210 * scale * t * t;
      paint.color = color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin + t * (right ? -5 : 5));
      if (i % (rich ? 3 : 7) == 0) {
        final star = Path();
        for (var point = 0; point < 10; point++) {
          final angle = point * math.pi / 5 - math.pi / 2;
          final r = radius * (point.isEven ? 1.6 : 0.7);
          final dx = math.cos(angle) * r;
          final dy = math.sin(angle) * r;
          if (point == 0) {
            star.moveTo(dx, dy);
          } else {
            star.lineTo(dx, dy);
          }
        }
        canvas.drawPath(star..close(), paint);
      } else {
        // 彩纸翻转时厚度变化，避免只像静态彩色方块。
        final width = radius * (0.25 + math.cos(spin + t * 8).abs());
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: width * 2,
              height: radius * 2.5,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(MatchConfettiPainter oldDelegate) =>
      oldDelegate.rich != rich || oldDelegate.animation != animation;
}
