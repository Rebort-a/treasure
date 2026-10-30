import 'dart:math';
import 'dart:ui';

/// 方向枚举（4 向网格移动）
enum Direction {
  up,
  down,
  left,
  right;

  /// 单位向量（屏幕坐标，y 向下）
  Offset get vector => switch (this) {
    up => const Offset(0, -1),
    down => const Offset(0, 1),
    left => const Offset(-1, 0),
    right => const Offset(1, 0),
  };

  /// 渲染旋转角度（弧度），默认坦克朝上绘制
  double get angle => switch (this) {
    up => -pi / 2,
    right => 0.0,
    down => pi / 2,
    left => pi,
  };

  static Direction fromName(String name) =>
      values.firstWhere((d) => d.name == name, orElse: () => Direction.up);
}

const List<(int, int)> planeAround = [(-1, 0), (1, 0), (0, -1), (0, 1)];

const List<(int, int)> planeConnection = [(1, 0), (0, 1), (1, 1), (-1, 1)];
