import 'constant.dart';
import 'vector.dart';

/// 轴对齐包围盒（浮点型）
class AABB {
  final Vector3 center;
  final Vector3 min, max;

  AABB(this.min, this.max, {Vector3? center})
    : center = center ?? (min + max) * 0.5;

  /// 从中心点和半径创建 AABB
  factory AABB.fromCenterAndHalfSize(Vector3 center, Vector3 halfSize) {
    return AABB(center - halfSize, center + halfSize, center: center);
  }

  /// 检查与另一AABB是否相交
  bool intersects(AABB other) =>
      _intersectsAxis(min.x, max.x, other.min.x, other.max.x) &&
      _intersectsAxis(min.y, max.y, other.min.y, other.max.y) &&
      _intersectsAxis(min.z, max.z, other.min.z, other.max.z);

  /// 检查是否包含某点
  bool contains(Vector3 point) =>
      _containsAxis(point.x, min.x, max.x) &&
      _containsAxis(point.y, min.y, max.y) &&
      _containsAxis(point.z, min.z, max.z);

  /// 计算与另一AABB的重叠向量（最小重叠方向）
  Vector3 calculateOverlap(AABB other) {
    final overlapX = _calculateAxisOverlap(
      min.x,
      max.x,
      other.min.x,
      other.max.x,
    );
    final overlapY = _calculateAxisOverlap(
      min.y,
      max.y,
      other.min.y,
      other.max.y,
    );
    final overlapZ = _calculateAxisOverlap(
      min.z,
      max.z,
      other.min.z,
      other.max.z,
    );

    return _selectMinOverlap(overlapX, overlapY, overlapZ);
  }

  /// 单个轴的相交检查
  bool _intersectsAxis(double min1, double max1, double min2, double max2) {
    return min2 <= max1 - Constants.epsilon && max2 >= min1 + Constants.epsilon;
  }

  /// 单个轴的包含检查（浮点型）
  bool _containsAxis(double point, double min, double max) {
    return point >= min - Constants.epsilon && point <= max + Constants.epsilon;
  }

  /// 单个轴的重叠量计算（浮点型）
  double _calculateAxisOverlap(
    double min1,
    double max1,
    double min2,
    double max2,
  ) {
    if (max1 <= min2 + Constants.epsilon || min1 >= max2 - Constants.epsilon) {
      return 0;
    }
    final overlap1 = max1 - min2;
    final overlap2 = max2 - min1;
    return overlap1 < overlap2 ? -overlap1 : overlap2;
  }

  /// 选择最小重叠方向（浮点型）
  Vector3 _selectMinOverlap(double x, double y, double z) {
    if (x.abs() <= y.abs() && x.abs() <= z.abs()) {
      return Vector3(x, 0, 0);
    } else if (y.abs() <= x.abs() && y.abs() <= z.abs()) {
      return Vector3(0, y, 0);
    } else {
      return Vector3(0, 0, z);
    }
  }

  AABB expand(double delta) {
    final newMin = Vector3(
      min.x - delta, // 左移
      min.y - delta, // 下移
      min.z - delta, // 前移
    );

    final newMax = Vector3(
      max.x + delta, // 右移
      max.y + delta, // 上移
      max.z + delta, // 后移
    );

    return AABB(newMin, newMax, center: center);
  }

  /// 获取包围盒尺寸
  Vector3 get size => max - min;

  /// 获取包围盒半尺寸
  Vector3 get extents => size * 0.5;
}

/// 整型轴对齐包围盒
class AABBInt {
  final Vector3Int center;
  final Vector3Int min, max;

  AABBInt(this.min, this.max, {Vector3Int? center})
    : center =
          center ??
          Vector3Int(
            (min.x + max.x) ~/ 2,
            (min.y + max.y) ~/ 2,
            (min.z + max.z) ~/ 2,
          );

  /// 从中心点和半尺寸创建AABBInt
  factory AABBInt.fromCenterAndHalfSize(
    Vector3Int center,
    Vector3Int halfSize,
  ) {
    final min = Vector3Int(
      center.x - halfSize.x,
      center.y - halfSize.y,
      center.z - halfSize.z,
    );
    final max = Vector3Int(
      center.x + halfSize.x,
      center.y + halfSize.y,
      center.z + halfSize.z,
    );
    return AABBInt(min, max, center: center);
  }

  /// 检查与另一个整型AABB是否相交
  bool intersects(AABBInt other) =>
      _intersectsAxis(min.x, max.x, other.min.x, other.max.x) &&
      _intersectsAxis(min.y, max.y, other.min.y, other.max.y) &&
      _intersectsAxis(min.z, max.z, other.min.z, other.max.z);

  /// 检查是否包含某个整型点
  bool contains(Vector3Int point) =>
      _containsAxis(point.x, min.x, max.x) &&
      _containsAxis(point.y, min.y, max.y) &&
      _containsAxis(point.z, min.z, max.z);

  /// 计算与另一个整型AABB的重叠向量（最小重叠方向）
  Vector3Int calculateOverlap(AABBInt other) {
    final overlapX = _calculateAxisOverlap(
      min.x,
      max.x,
      other.min.x,
      other.max.x,
    );
    final overlapY = _calculateAxisOverlap(
      min.y,
      max.y,
      other.min.y,
      other.max.y,
    );
    final overlapZ = _calculateAxisOverlap(
      min.z,
      max.z,
      other.min.z,
      other.max.z,
    );

    return _selectMinOverlap(overlapX, overlapY, overlapZ);
  }

  /// 单个轴的相交检查（整型）
  bool _intersectsAxis(int min1, int max1, int min2, int max2) {
    return min1 <= max2 && max1 >= min2;
  }

  /// 单个轴的包含检查（整型）
  bool _containsAxis(int point, int min, int max) {
    return point >= min && point <= max;
  }

  /// 单个轴的重叠量计算（整型）
  int _calculateAxisOverlap(int min1, int max1, int min2, int max2) {
    if (max1 <= min2 || min1 >= max2) {
      return 0; // 无重叠
    }
    final overlap1 = max1 - min2;
    final overlap2 = max2 - min1;
    return overlap1 < overlap2 ? -overlap1 : overlap2;
  }

  /// 选择最小重叠方向（整型）
  Vector3Int _selectMinOverlap(int x, int y, int z) {
    if (x.abs() <= y.abs() && x.abs() <= z.abs()) {
      return Vector3Int(x, 0, 0);
    } else if (y.abs() <= x.abs() && y.abs() <= z.abs()) {
      return Vector3Int(0, y, 0);
    } else {
      return Vector3Int(0, 0, z);
    }
  }

  /// 获取包围盒尺寸（整型向量）
  Vector3Int get size => max - min;

  AABB toAABB() => AABB(min.toVector3(), max.toVector3());
}
