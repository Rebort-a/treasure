import '../base/vector.dart';
import '../base/matrix.dart';
import '../base/aabb.dart';
import '../base/constant.dart';

/// 平面表示（ax + by + cz + d = 0）
class _Plane {
  final Vector3Unit normal;
  final double distance;

  _Plane(this.normal, this.distance);

  factory _Plane.fromCoefficients(double a, double b, double c, double d) {
    final vector = Vector3(a, b, c);
    final length = vector.magnitude;

    if (length < Constants.epsilon) {
      return _Plane(Vector3Unit.up, 0);
    }

    final invLength = 1.0 / length;
    return _Plane(
      Vector3Unit(a * invLength, b * invLength, c * invLength),
      d * invLength,
    );
  }

  bool isPointInside(Vector3 point) =>
      distanceToPoint(point) >= -Constants.epsilon;
  double distanceToPoint(Vector3 point) => normal.dot(point) + distance;
}

/// 视锥体管理器
class FrustumManager {
  final List<_Plane> _planes;

  FrustumManager._(this._planes);

  /// 从视图投影矩阵构造视锥体
  factory FrustumManager.fromViewProjectionMatrix(ColMat4 m) {
    return FrustumManager._([
      _createPlane(m[3] + m[0], m[7] + m[4], m[11] + m[8], m[15] + m[12]),
      _createPlane(m[3] - m[0], m[7] - m[4], m[11] - m[8], m[15] - m[12]),
      _createPlane(m[3] + m[1], m[7] + m[5], m[11] + m[9], m[15] + m[13]),
      _createPlane(m[3] - m[1], m[7] - m[5], m[11] - m[9], m[15] - m[13]),
      _createPlane(m[3] + m[2], m[7] + m[6], m[11] + m[10], m[15] + m[14]),
      _createPlane(
        m[3] - m[2] * 0.99,
        m[7] - m[6] * 0.99,
        m[11] - m[10] * 0.99,
        m[15] - m[14] * 0.99,
      ),
    ]);
  }

  static _Plane _createPlane(double a, double b, double c, double d) {
    final length = Vector3(a, b, c).magnitude;
    return length > Constants.epsilon
        ? _Plane.fromCoefficients(
            a / length,
            b / length,
            c / length,
            d / length,
          )
        : _Plane(Vector3Unit.up, 0);
  }

  /// 检查AABB是否与视锥体相交
  bool intersectsAABB(AABB aabb) {
    final center = aabb.center;
    final extents = aabb.extents;

    for (final plane in _planes) {
      final r =
          extents.x * plane.normal.x.abs() +
          extents.y * plane.normal.y.abs() +
          extents.z * plane.normal.z.abs();

      if (plane.distanceToPoint(center) < -r - Constants.epsilon) {
        return false;
      }
    }
    return true;
  }

  /// 检查点是否在视锥体内
  bool containsPoint(Vector3 point) {
    return _planes.every((plane) => plane.isPointInside(point));
  }

  /// 获取视锥体角点（用于调试）
  List<Vector3> getCorners(ColMat4 inverseViewProjection) {
    const homogenousCorners = [
      Vector4(-1, -1, -1, 1),
      Vector4(1, -1, -1, 1),
      Vector4(-1, 1, -1, 1),
      Vector4(1, 1, -1, 1),
      Vector4(-1, -1, 1, 1),
      Vector4(1, -1, 1, 1),
      Vector4(-1, 1, 1, 1),
      Vector4(1, 1, 1, 1),
    ];

    return homogenousCorners.map((corner) {
      final worldCorner = inverseViewProjection.multiplyVector4(corner);
      return Vector3(
        worldCorner.x / worldCorner.w,
        worldCorner.y / worldCorner.w,
        worldCorner.z / worldCorner.w,
      );
    }).toList();
  }
}
