import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../base/constant.dart';
import '../middle/control_manager.dart';
import '../middle/manager.dart';
import 'scene_render.dart';
import 'widget.dart';

/// 主游戏页面
class MinecraftPage extends StatefulWidget {
  const MinecraftPage({super.key});

  @override
  State<MinecraftPage> createState() => _MinecraftPageState();
}

class _MinecraftPageState extends State<MinecraftPage> {
  late final Manager manager;

  @override
  void initState() {
    super.initState();
    manager = Manager();
    manager.addListener(_onManagerUpdate);
    // 确保 widget 挂载后再请求焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      manager.controlManager.focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    manager.removeListener(_onManagerUpdate);
    manager.dispose();
    super.dispose();
  }

  void _onManagerUpdate() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cm = manager.controlManager;

    return Scaffold(
      body: Stack(
        children: [
          // 场景渲染
          _buildScene(),

          // 破坏进度指示器
          if (manager.destroyProgress > 0)
            Center(
              child: DestroyProgressIndicator(
                progress: manager.destroyProgress,
              ),
            ),

          // 十字准星
          const IgnorePointer(child: Crosshair()),

          // 输入控制（按平台区分）
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
            _buildDesktopControl(cm),
          if (Platform.isAndroid || Platform.isIOS) _buildMobileGesture(cm),
          if (Platform.isAndroid || Platform.isIOS) _buildMobileControl(cm),

          // 背包栏（竖屏靠上，横屏靠下）
          _buildHotbar(),
        ],
      ),
    );
  }

  Widget _buildScene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: manager,
          builder: (context, child) {
            return CustomPaint(
              painter: ScenePainter(
                manager.sceneInfo,
                manager.debugInfo,
                debugConfig: manager.debugConfig,
              ),
              size: constraints.biggest,
            );
          },
        );
      },
    );
  }

  /// 桌面端：键盘 → 鼠标点击/悬停
  Widget _buildDesktopControl(ControlManager cm) {
    return KeyboardListener(
      focusNode: cm.focusNode,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        cursor: SystemMouseCursors.none,
        onHover: cm.handleMouseHover,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (e.kind == PointerDeviceKind.mouse) {
              if (e.buttons == kPrimaryButton) {
                cm.startDestroy();
              } else if (e.buttons == kSecondaryButton) {
                manager.placeBlock();
              }
            }
          },
          onPointerUp: (_) => cm.stopDestroy(),
          onPointerSignal: _handlePointerSignal,
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    // 数字键切换栏位（仅按下时）
    if (event is KeyDownEvent) {
      final keySlotMap = <LogicalKeyboardKey, int>{
        LogicalKeyboardKey.digit1: 0,
        LogicalKeyboardKey.digit2: 1,
        LogicalKeyboardKey.digit3: 2,
        LogicalKeyboardKey.digit4: 3,
        LogicalKeyboardKey.digit5: 4,
        LogicalKeyboardKey.digit6: 5,
        LogicalKeyboardKey.digit7: 6,
        LogicalKeyboardKey.digit8: 7,
        LogicalKeyboardKey.digit9: 8,
      };
      final slot = keySlotMap[event.logicalKey];
      if (slot != null && slot < manager.slotTypes.length) {
        setState(() => manager.selectedSlot = slot);
        return;
      }
    }

    // WASD/方向键/空格（按下和释放都要传递）
    manager.controlManager.handleKeyEvent(event);
  }

  /// 移动端：触摸手势
  Widget _buildMobileGesture(ControlManager cm) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => manager.placeBlock(),
      onPanStart: cm.handlePanStart,
      onPanUpdate: cm.handlePanUpdate,
      onPanEnd: cm.handlePanEnd,
      onLongPressStart: cm.handleLongPressStart,
      onLongPressEnd: cm.handleLongPressEnd,
      child: Container(color: Colors.transparent),
    );
  }

  /// 移动端：摇杆 + 跳跃
  Widget _buildMobileControl(ControlManager cm) {
    return MobileControls(
      onMove: cm.setMobileMove,
      onJump: cm.setMobileJump,
    );
  }

  Widget _buildHotbar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    return Positioned(
      // 竖屏：摇杆上方留出空间；横屏：贴近底部
      bottom: isPortrait ? 160 : 12,
      left: 0,
      right: 0,
      child: Center(
        child: Hotbar(
          slotTypes: manager.slotTypes,
          getCount: manager.getCount,
          selectedSlot: manager.selectedSlot,
          onSelect: (i) => setState(() => manager.selectedSlot = i),
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        if (event.scrollDelta.dy < 0) {
          manager.selectedSlot =
              (manager.selectedSlot + 1) % Constants.hotbarSlotCount;
        } else if (event.scrollDelta.dy > 0) {
          manager.selectedSlot =
              (manager.selectedSlot - 1 + Constants.hotbarSlotCount) %
                  Constants.hotbarSlotCount;
        }
      });
    }
  }
}
