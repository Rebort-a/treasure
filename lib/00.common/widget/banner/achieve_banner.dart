import 'dart:ui';

import 'package:flutter/material.dart';

class AchieveBanner extends StatefulWidget {
  final String title;
  final String description;

  const AchieveBanner({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  State<AchieveBanner> createState() => _AchieveBannerState();
}

class _AchieveBannerState extends State<AchieveBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 滑入动画：从右侧屏幕外滑到目标位置
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0), // 初始位置（屏幕右侧外）
      end: const Offset(0, 0), // 目标位置
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 启动动画
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); // 释放资源
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: _GlassMorphism(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                // 成就图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFBF00FF), // 霓虹紫色
                  ),
                ),
                const SizedBox(width: 12),
                // 成就信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Color(0xFFBF00FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 玻璃态效果组件
class _GlassMorphism extends StatelessWidget {
  final Widget child;

  const _GlassMorphism({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.05),
          child: child,
        ),
      ),
    );
  }
}
