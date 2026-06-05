import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../base/constant.dart';
import '../base/player.dart';
import '../base/vector.dart';

/// 输入控制处理器
class ControlManager {
  final Player player;
  late final FocusNode focusNode;

  Vector2 _moveInput = Vector2.zero;
  bool _jumpRequested = false;
  Offset? _lastTouchPos;

  ControlManager(this.player) : focusNode = FocusNode()..requestFocus();

  /// 处理键盘事件
  void handleKeyEvent(KeyEvent event) {
    final isKeyUp = event is KeyUpEvent;
    final key = event.logicalKey;

    switch (key) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        _moveInput = _moveInput.appointY(isKeyUp ? 0.0 : 1.0);
        break;
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        _moveInput = _moveInput.appointY(isKeyUp ? 0.0 : -1.0);
        break;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _moveInput = _moveInput.appointX(isKeyUp ? 0.0 : -1.0);
        break;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _moveInput = _moveInput.appointX(isKeyUp ? 0.0 : 1.0);
        break;
      case LogicalKeyboardKey.space:
        if (!isKeyUp) _jumpRequested = true;
        break;
    }
  }

  /// 处理触摸开始
  void handleTouchStart(DragStartDetails details) {
    _lastTouchPos = details.localPosition;
  }

  /// 处理触摸移动
  void handleTouchMove(DragUpdateDetails details) {
    if (_lastTouchPos != null) {
      final delta = details.localPosition - _lastTouchPos!;
      _lastTouchPos = details.localPosition;

      player.rotateView(
        delta.dx * Constants.touchSensitivity,
        -delta.dy * Constants.touchSensitivity,
      );
    }
  }

  /// 处理触摸结束
  void handleTouchEnd(DragEndDetails details) {
    _lastTouchPos = null;
  }

  /// 处理鼠标悬停
  void handleMouseHover(PointerHoverEvent event) {
    if (focusNode.hasFocus) {
      player.rotateView(
        event.delta.dx * Constants.mouseSensitivity,
        -event.delta.dy * Constants.mouseSensitivity,
      );
    }
  }

  /// 移动端移动输入
  void setMobileMove(Vector2 input) {
    _moveInput = input;
  }

  /// 移动端跳跃输入
  void setMobileJump() {
    _jumpRequested = true;
  }

  /// 更新玩家移动
  void updatePlayerMovement(double deltaTime) {
    if (!_moveInput.isZero) {
      player.move(_moveInput, Constants.moveSpeed);
    } else {
      // 平滑减速
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

  /// 获取移动状态
  bool get isMoving => !_moveInput.isZero;

  void dispose() {
    focusNode.dispose();
  }
}
