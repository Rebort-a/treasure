import 'package:flutter/material.dart';

import '../middle/manager.dart';
import 'scene_render.dart';
import 'widget.dart';

/// 主游戏页面
class MinecraftPage extends StatelessWidget {
  final Manager manager = Manager();

  MinecraftPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 场景
          _buildScene(),

          // 十字准星
          const Crosshair(),

          // 输入处理
          _buildHostControl(),

          // 移动端控制
          _buildMobileControl(),
        ],
      ),
    );
  }

  /// 构建游戏场景
  Widget _buildScene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: manager,
          builder: (context, child) {
            return CustomPaint(
              painter: ScenePainter(manager.sceneInfo, manager.debugInfo),
              size: constraints.biggest,
            );
          },
        );
      },
    );
  }

  /// 构建输入处理器
  Widget _buildHostControl() {
    final controlMnager = manager.controlManager;

    return KeyboardListener(
      focusNode: controlMnager.focusNode,
      onKeyEvent: controlMnager.handleKeyEvent,
      child: MouseRegion(
        cursor: SystemMouseCursors.none,
        onHover: controlMnager.handleMouseHover,
        child: GestureDetector(
          onPanStart: controlMnager.handleTouchStart,
          onPanUpdate: controlMnager.handleTouchMove,
          onPanEnd: controlMnager.handleTouchEnd,
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  /// 构建移动端控制
  Widget _buildMobileControl() {
    final controlMnager = manager.controlManager;

    return MobileControls(
      onMove: controlMnager.setMobileMove,
      onJump: controlMnager.setMobileJump,
    );
  }
}
