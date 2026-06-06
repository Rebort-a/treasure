import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';

import '../base/constant.dart';
import '../base/player.dart';
import '../base/vector.dart';
import 'manager.dart';

/// 输入控制处理器
class ControlManager {
  final Player player;
  final Manager manager;
  late final FocusNode focusNode;

  Vector2 _moveInput = Vector2.zero;
  bool _jumpRequested = false;
  Offset? _lastTouchPos;

  // 方块交互状态
  bool _isDestroying = false;
  bool _destroyConsumed = false; // 本次长按已摧毁过，需松开再按

  // 移动端手势状态
  Offset? _touchStartPos;
  double _touchStartTime = 0;
  bool _touchMoved = false;

  ControlManager(this.player, this.manager)
      : focusNode = FocusNode()..requestFocus();

  // ==================== 更新循环 ====================

  /// 每帧调用：更新摧毁进度
  void updateDestroyProgress(double deltaTime) {
    if (!_isDestroying || _destroyConsumed || !manager.isTargetInDestroyRange) {
      manager.destroyProgress = 0;
      return;
    }
    manager.destroyProgress += deltaTime / Constants.destroyTime;
    if (manager.destroyProgress >= 1.0) {
      manager.destroyTargetedBlock();
      manager.destroyProgress = 0;
      _destroyConsumed = true; // 本次长按已消耗，需松开再按
    }
  }

  // ==================== 键盘输入 ====================

  /// 处理键盘事件（WASD / 方向键移动，空格跳跃）
  void handleKeyEvent(KeyEvent event) {
    final isKeyUp = event is KeyUpEvent;
    final key = event.logicalKey;

    switch (key) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        _moveInput = _moveInput.appointY(isKeyUp ? 0.0 : 1.0);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        _moveInput = _moveInput.appointY(isKeyUp ? 0.0 : -1.0);
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _moveInput = _moveInput.appointX(isKeyUp ? 0.0 : -1.0);
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _moveInput = _moveInput.appointX(isKeyUp ? 0.0 : 1.0);
      case LogicalKeyboardKey.space:
        if (!isKeyUp) _jumpRequested = true;
      default:
        break;
    }
  }

  // ==================== 鼠标输入 ====================

  /// 处理鼠标悬停（无按键时的鼠标移动 → 视角旋转）
  void handleMouseHover(PointerHoverEvent event) {
    if (focusNode.hasFocus) {
      player.rotateView(
        event.delta.dx * Constants.mouseSensitivity,
        -event.delta.dy * Constants.mouseSensitivity,
      );
    }
  }

  /// 鼠标左键按下 → 开始摧毁
  void startDestroy() {
    _isDestroying = true;
    _destroyConsumed = false;
  }

  /// 鼠标释放 → 停止摧毁
  void stopDestroy() {
    _isDestroying = false;
    _destroyConsumed = false;
    manager.destroyProgress = 0;
  }

  // ==================== 移动端手势 ====================

  void handlePanStart(DragStartDetails details) {
    _touchStartPos = details.localPosition;
    _touchStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _touchMoved = false;
    _lastTouchPos = details.localPosition;
  }

  void handlePanUpdate(DragUpdateDetails details) {
    if (_touchStartPos != null) {
      final delta = details.localPosition - _touchStartPos!;
      if (delta.distance > Constants.tapMoveThreshold) {
        _touchMoved = true;
      }
    }

    if (_lastTouchPos != null) {
      final delta = details.localPosition - _lastTouchPos!;
      _lastTouchPos = details.localPosition;
      player.rotateView(
        delta.dx * Constants.touchSensitivity,
        -delta.dy * Constants.touchSensitivity,
      );
    }
  }

  void handlePanEnd(DragEndDetails details) {
    _lastTouchPos = null;

    // 未移动 → 点击 → 放置方块
    if (!_touchMoved && _touchStartPos != null) {
      final elapsed =
          DateTime.now().millisecondsSinceEpoch / 1000.0 - _touchStartTime;
      if (elapsed < Constants.longPressTime) {
        manager.placeBlock();
      }
    }

    // 重置长按状态
    _isDestroying = false;
    manager.destroyProgress = 0;
    _touchStartPos = null;
  }

  void handleLongPressStart(LongPressStartDetails details) {
    _isDestroying = true;
    _destroyConsumed = false;
  }

  void handleLongPressEnd(LongPressEndDetails details) {
    _isDestroying = false;
    _destroyConsumed = false;
    manager.destroyProgress = 0;
  }

  // ==================== 移动端摇杆 ====================

  void setMobileMove(Vector2 input) {
    _moveInput = input;
  }

  void setMobileJump() {
    _jumpRequested = true;
  }

  // ==================== 玩家移动 ====================

  void updatePlayerMovement(double deltaTime) {
    if (!_moveInput.isZero) {
      player.move(_moveInput, Constants.moveSpeed);
    } else {
      player.velocity = Vector3(
        player.velocity.x * Constants.friction,
        player.velocity.y,
        player.velocity.z * Constants.friction,
      );
    }

    if (_jumpRequested) {
      player.jump();
      _jumpRequested = false;
    }
  }

  void dispose() {
    focusNode.dispose();
  }
}
