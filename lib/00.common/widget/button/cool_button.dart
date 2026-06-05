import 'package:flutter/material.dart';

class CoolButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  final double width;
  final double height;

  final double radius;
  final double padding;

  final TextStyle textStyle;
  final double iconSize;
  final double gap;

  final Duration duration;

  const CoolButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
    this.width = 180,
    this.height = 60,
    this.radius = 30,
    this.padding = 16.0,
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      fontFamily: 'Orbitron',
    ),
    this.iconSize = 22,
    this.gap = 10,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<CoolButton> createState() => _CoolButtonState();
}

class _CoolButtonState extends State<CoolButton>
    with SingleTickerProviderStateMixin {
  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  // 交互状态
  bool _isHovered = false;
  bool _isPressed = false;

  // 霓虹色定义
  final Color _neonBlue = const Color(0xFF00F0FF);
  final Color _neonPurple = const Color(0xFFBF00FF);

  @override
  void initState() {
    super.initState();

    // 初始化发光动画
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    // 发光强度动画
    _glowAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        // 根据动画值计算发光强度
        final glowValue = 5.0 + (_glowAnimation.value * 25.0);

        return MouseRegion(
          // 鼠标悬停检测
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),

          child: GestureDetector(
            // 点击状态检测
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,

            child: Transform.scale(
              // 交互缩放效果
              scale: _isPressed ? 0.95 : (_isHovered ? 1.05 : 1.0),
              child: Container(
                width: widget.width,
                height: widget.height,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.padding * 2,
                  vertical: widget.padding,
                ),
                decoration: BoxDecoration(
                  // 渐变背景
                  gradient: LinearGradient(
                    colors: [_neonBlue, _neonPurple],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  // 圆角
                  borderRadius: BorderRadius.circular(widget.radius),
                  // 动态发光效果
                  boxShadow: [
                    BoxShadow(
                      color: _neonBlue.withValues(
                        alpha: 0.5 + _glowAnimation.value * 0.4,
                      ),
                      blurRadius: glowValue,
                      spreadRadius: 1.0,
                    ),
                  ],
                ),

                // 按钮内容（图标+文字）
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: widget.iconSize,
                    ),
                    SizedBox(width: widget.gap),
                    Text(widget.text, style: widget.textStyle),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
