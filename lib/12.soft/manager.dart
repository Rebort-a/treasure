import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'base.dart';

/// 常量类，规定坐标系与边界规则
class Constant {
  /// 以窗口中心建立三维坐标系，x向右增大，y向上增大，z向内增大

  // ------------------------------ 观察者相关常量 ------------------------------
  /// 观察者视角所在坐标
  static const Vector3 observer = Vector3(0, 0, 0);

  /// 观察者视线方向
  static const Vector3 eyeline = Vector3(0, 0, 1);

  /// 观察者焦点
  static const Vector3 focus = Vector3(0, 0, 300);

  /// 观察者焦距
  static double get focalLength => focus.z;

  // ------------------------------ 边界相关常量（核心优化） ------------------------------
  /// 边界中心（业务定义：以 (0,0,500) 为中心）
  static const Vector3 boundaryCenter = Vector3(0, 0, 500);

  /// 边界半范围（业务定义：各方向延伸 400，即上下左右前后各 400）
  static const Vector3 boundaryHalfExtents = Vector3(400, 400, 400);

  /// 碰撞恢复系数（物体碰撞后保留的速度比例）
  static const double restitution = 0.8;

  // ------------------------------ 投影方法 ------------------------------
  /// 将3D x坐标投影到2D屏幕坐标
  static double projectX(Vector3 point, Size screenSize) {
    if (point.z <= 0) return screenSize.width / 2; // 处理负深度（避免投影异常）
    final scale = focalLength / point.z;
    return point.x * scale + screenSize.width / 2;
  }

  /// 将3D y坐标投影到2D屏幕坐标（屏幕Y轴与3D Y轴方向相反，需翻转）
  static double projectY(Vector3 point, Size screenSize) {
    if (point.z <= 0) return screenSize.height / 2; // 处理负深度
    final scale = focalLength / point.z;
    return -point.y * scale + screenSize.height / 2;
  }

  // ------------------------------ 碰撞处理（核心优化） ------------------------------
  /// 边界碰撞总处理（调用单轴通用方法，消除重复逻辑）
  static void handleBoundaryCollision(Particle p) {
    // 处理 X 轴碰撞（左右边界）
    final xResult = _handleAxisCollision(
      currentPos: p.position.x,
      currentVel: p.velocity.x,
      centerAxis: boundaryCenter.x,
      halfExtent: boundaryHalfExtents.x,
    );

    // 处理 Y 轴碰撞（上下边界）
    final yResult = _handleAxisCollision(
      currentPos: p.position.y,
      currentVel: p.velocity.y,
      centerAxis: boundaryCenter.y,
      halfExtent: boundaryHalfExtents.y,
    );

    // 处理 Z 轴碰撞（前后边界）
    final zResult = _handleAxisCollision(
      currentPos: p.position.z,
      currentVel: p.velocity.z,
      centerAxis: boundaryCenter.z,
      halfExtent: boundaryHalfExtents.z,
    );

    // 更新粒子的位置和速度（整合三个轴的处理结果）
    p.position = Vector3(xResult.newPos, yResult.newPos, zResult.newPos);
    p.velocity = Vector3(xResult.newVel, yResult.newVel, zResult.newVel);

    // 反向修正上一帧位置
    if (p.verlet) {
      p.previousPosition = Vector3(
        2 * p.position.x - p.previousPosition.x,
        2 * p.position.y - p.previousPosition.y,
        2 * p.position.z - p.previousPosition.z,
      );
    }
  }

  /// 单轴碰撞处理通用方法（核心逻辑复用）
  /// [currentPos]：粒子在当前轴的位置
  /// [currentVel]：粒子在当前轴的速度
  /// [centerAxis]：边界在当前轴的中心
  /// [halfExtent]：边界在当前轴的半范围（中心到边界的距离）
  /// 返回：处理后的「位置+速度」
  static ({double newPos, double newVel}) _handleAxisCollision({
    required double currentPos,
    required double currentVel,
    required double centerAxis,
    required double halfExtent,
  }) {
    // 计算当前轴的边界范围（中心 ± 半范围）
    final axisMin = centerAxis - halfExtent;
    final axisMax = centerAxis + halfExtent;

    // 未碰撞：直接返回原位置和速度
    if (currentPos >= axisMin && currentPos <= axisMax) {
      return (newPos: currentPos, newVel: currentVel);
    }

    // 碰撞处理：计算反弹后的位置和速度
    double newPos;
    if (currentPos < axisMin) {
      // 超出左/下/前边界：反弹（位置 = 2*最小边界 - 当前位置）
      newPos = 2 * axisMin - currentPos;
    } else {
      // 超出右/上/后边界：反弹（位置 = 2*最大边界 - 当前位置）
      newPos = 2 * axisMax - currentPos;
    }

    // 速度反向 + 应用恢复系数（碰撞后速度衰减）
    final newVel = -currentVel * restitution;

    return (newPos: newPos, newVel: newVel);
  }
}

class Manager with ChangeNotifier implements TickerProvider {
  late Ticker _ticker;
  double _lastElapsed = 0; // 上次更新时间
  final FocusNode focusNode = FocusNode();

  SoftTube _soft = SoftTube(center: Constant.focus); // 在焦点处生成圆环
  Vector3 _externalForce = Vector3.zero(); // 所有粒子都受相同的外力
  bool impulse = false; // 是否脉冲模式

  double _lastScale = 1.0; // 上次缩放比例

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  Manager() {
    _initFocusNode();
    _initTicker();
  }

  void _initFocusNode() {
    focusNode.requestFocus();
  }

  void _initTicker() {
    _ticker = createTicker(_update);
    _ticker.start();
  }

  void _update(Duration elapsed) {
    final currentTime = elapsed.inMilliseconds;

    final currentElapsed = currentTime / 1000.0;
    final deltaTime = currentElapsed - _lastElapsed;
    _lastElapsed = currentElapsed;

    final clampedDeltaTime = deltaTime.clamp(0.004, 0.02); // 限制帧率

    Vector3 force = _externalForce;

    // 在脉冲模式下十倍力
    if (impulse) {
      force *= 10;
    }

    _soft.simulateStep(
      clampedDeltaTime,
      force,
      Constant.handleBoundaryCollision,
    );

    // 在脉冲模式下每帧清除外力
    if (impulse) {
      _externalForce = Vector3.zero();
    }

    notifyListeners();
  }

  /// 立即重置
  void resetImmediate() {
    _externalForce = Vector3.zero();
    _lastScale = 1.0;
    _soft = SoftTube(center: Constant.focus);
    notifyListeners();
  }

  /// 处理键盘事件
  void handleKeyEvent(KeyEvent event) {
    const double keyForceStep = 0.1;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      switch (event.logicalKey) {
        // 上方向：上箭头、W/w
        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.keyW:
          _externalForce += Vector3(0, keyForceStep, 0);
          break;
        // 下方向：下箭头、S/s
        case LogicalKeyboardKey.arrowDown:
        case LogicalKeyboardKey.keyS:
          _externalForce += Vector3(0, -keyForceStep, 0);
          break;
        // 左方向：左箭头、A/a
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.keyA:
          _externalForce += Vector3(-keyForceStep, 0, 0);
          break;
        // 右方向：右箭头、D/d
        case LogicalKeyboardKey.arrowRight:
        case LogicalKeyboardKey.keyD:
          _externalForce += Vector3(keyForceStep, 0, 0);
          break;
        // 向外：O/o
        case LogicalKeyboardKey.keyO:
          _externalForce += Vector3(0, 0, -keyForceStep);
          break;
        // 向内：I/i
        case LogicalKeyboardKey.keyI:
          _externalForce += Vector3(0, 0, keyForceStep);
          break;
      }
    }
  }

  /// 处理手势事件
  void handleDrag(ScaleUpdateDetails details) {
    const double dragSensitivity = 0.01;
    const double scaleSensitivity = 0.8;

    // 根据手指数量区分操作类型
    if (details.pointerCount == 1) {
      // 1. 单指操作 - 只处理平移
      final delta = details.focalPointDelta;
      _externalForce += Vector3(delta.dx * dragSensitivity, 0, 0);
      _externalForce += Vector3(0, -delta.dy * dragSensitivity, 0);
    } else if (details.pointerCount >= 2) {
      // 2. 双指及以上操作 - 只处理缩放
      final scaleDiff = _lastScale - details.scale;
      _externalForce += Vector3(0, 0, scaleDiff * scaleSensitivity);
      _lastScale = details.scale;
    }
  }

  SoftTube get soft => _soft;

  @override
  void dispose() {
    _ticker.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
