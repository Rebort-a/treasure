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
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  bool _jumpRequested = false;
  final Map<int, Offset> _lastTouchPos = {};

  // 方块交互状态
  bool _isDestroying = false;
  bool _destroyConsumed = false; // 本次长按已摧毁过，需松开再按

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
    final key = event.logicalKey;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressedKeys.add(key);
      if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
        _jumpRequested = true;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }

    final left = _isPressed(
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.keyA,
    );
    final right = _isPressed(
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyD,
    );
    final forward = _isPressed(
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.keyW,
    );
    final backward = _isPressed(
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.keyS,
    );
    _moveInput = Vector2(
      (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0),
      (forward ? 1.0 : 0.0) - (backward ? 1.0 : 0.0),
    );
  }

  bool _isPressed(LogicalKeyboardKey first, LogicalKeyboardKey second) =>
      _pressedKeys.contains(first) || _pressedKeys.contains(second);

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

  /// 按指针分桶记录上次位置，避免多指交替覆盖同一基准导致视角跳变。
  void handleTouchDown(PointerDownEvent event) {
    _lastTouchPos[event.pointer] = event.localPosition;
  }

  void handleTouchMove(PointerMoveEvent event) {
    final previous = _lastTouchPos[event.pointer];
    if (previous == null) return;
    final delta = event.localPosition - previous;
    _lastTouchPos[event.pointer] = event.localPosition;
    player.rotateView(
      delta.dx * Constants.touchSensitivity,
      -delta.dy * Constants.touchSensitivity,
    );
  }

  void handleTouchUp(PointerUpEvent event) {
    _lastTouchPos.remove(event.pointer);
  }

  void handleTouchCancel(PointerCancelEvent event) {
    _lastTouchPos.remove(event.pointer);
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
      player.applyHorizontalDamping(deltaTime);
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
