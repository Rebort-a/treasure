import 'dart:math' as math;
import '../base/vector.dart';
import '../base/aabb.dart';
import '../base/constant.dart';

/// 遮挡查询结果
enum OcclusionResult { fullyVisible, fullyOccluded, partiallyOccluded }

/// 射线表示
class _OcclusionRay {
  final Vector3 origin;
  final Vector3 direction;
  final Vector3 inverseDirection;

  _OcclusionRay({required this.origin, required this.direction})
    : inverseDirection = Vector3(
        1.0 /
            (direction.x.abs() > Constants.epsilon
                ? direction.x
                : Constants.epsilon),
        1.0 /
            (direction.y.abs() > Constants.epsilon
                ? direction.y
                : Constants.epsilon),
        1.0 /
            (direction.z.abs() > Constants.epsilon
                ? direction.z
                : Constants.epsilon),
      );
}

/// 优化的遮挡剔除器
class OcclusionCuller {
  final List<AABB> _occluders = [];
  final List<Vector3> _aabbCornerCache = List.filled(8, Vector3.zero);

  void clear() => _occluders.clear();
  void addOccluder(AABB occluder) => _occluders.add(occluder);
  int get occluderCount => _occluders.length;

  /// 检查AABB的遮挡状态
  OcclusionResult checkOcclusion(AABB targetBounds, Vector3 cameraPosition) {
    if (_occluders.isEmpty) return OcclusionResult.fullyVisible;

    // 近距离物体总是可见
    final distanceSquared =
        (targetBounds.center - cameraPosition).magnitudeSquare;
    if (distanceSquared < Constants.blockSize) {
      return OcclusionResult.fullyVisible;
    }

    final visibleCornerCount = _countVisibleCorners(
      targetBounds,
      cameraPosition,
    );

    return switch (visibleCornerCount) {
      0 => OcclusionResult.fullyOccluded,
      8 => OcclusionResult.fullyVisible,
      _ => OcclusionResult.partiallyOccluded,
    };
  }

  /// 统计可见角点数量
  int _countVisibleCorners(AABB bounds, Vector3 camera) {
    final corners = _getAABBCorners(bounds);
    return corners.where((corner) => _isCornerVisible(corner, camera)).length;
  }

  /// 检查单个角点是否可见
  bool _isCornerVisible(Vector3 corner, Vector3 camera) {
    final ray = _OcclusionRay(
      origin: camera,
      direction: (corner - camera).normalized,
    );
    final maxDistance = (corner - camera).magnitude;

    if (maxDistance < Constants.blockSizeHalf) return true;

    for (final occluder in _occluders) {
      final intersection = _rayAABBIntersection(ray, occluder, maxDistance);
      if (intersection != null && intersection < maxDistance) {
        return false;
      }
    }
    return true;
  }

  /// 射线-AABB相交检测（优化版）
  double? _rayAABBIntersection(
    _OcclusionRay ray,
    AABB aabb,
    double maxDistance,
  ) {
    final t1 = (aabb.min.x - ray.origin.x) * ray.inverseDirection.x;
    final t2 = (aabb.max.x - ray.origin.x) * ray.inverseDirection.x;
    final t3 = (aabb.min.y - ray.origin.y) * ray.inverseDirection.y;
    final t4 = (aabb.max.y - ray.origin.y) * ray.inverseDirection.y;
    final t5 = (aabb.min.z - ray.origin.z) * ray.inverseDirection.z;
    final t6 = (aabb.max.z - ray.origin.z) * ray.inverseDirection.z;

    final tmin = math.max(
      math.max(math.min(t1, t2), math.min(t3, t4)),
      math.min(t5, t6),
    );
    final tmax = math.min(
      math.min(math.max(t1, t2), math.max(t3, t4)),
      math.max(t5, t6),
    );

    return (tmax >= 0 && tmin <= tmax && tmin <= maxDistance) ? tmin : null;
  }

  /// 获取AABB的8个角点（使用缓存优化）
  List<Vector3> _getAABBCorners(AABB aabb) {
    final min = aabb.min;
    final max = aabb.max;

    _aabbCornerCache[0] = min;
    _aabbCornerCache[1] = Vector3(max.x, min.y, min.z);
    _aabbCornerCache[2] = Vector3(min.x, max.y, min.z);
    _aabbCornerCache[3] = Vector3(max.x, max.y, min.z);
    _aabbCornerCache[4] = Vector3(min.x, min.y, max.z);
    _aabbCornerCache[5] = Vector3(max.x, min.y, max.z);
    _aabbCornerCache[6] = Vector3(min.x, max.y, max.z);
    _aabbCornerCache[7] = max;

    return _aabbCornerCache;
  }

  int get occludersCount => _occluders.length;
}
