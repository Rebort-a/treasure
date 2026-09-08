import 'vector.dart';
import 'aabb.dart';

/// 碰撞体类型
enum ColliderType { fixedBox, movedBox }

class FixedBoxCollider {
  ColliderType get colliderType => ColliderType.fixedBox;
  final Vector3Int position;
  final Vector3Int halfSize;
  final AABBInt aabb;

  FixedBoxCollider({required this.position, required this.halfSize})
    : aabb = AABBInt.fromCenterAndHalfSize(position, halfSize);
}

class MovedBoxCollider {
  ColliderType get colliderType => ColliderType.movedBox;
  Vector3 position;
  final Vector3 size;
  AABB aabb;

  MovedBoxCollider({required this.position, required this.size})
    : aabb = _calculateAABB(position, size);

  /// 更新位置并重新计算AABB
  void updatePosition(Vector3 newPosition) {
    position = newPosition;
    aabb = _calculateAABB(position, size);
  }

  /// 根据眼睛位置和尺寸计算AABB，使眼睛靠近顶部和前端
  static AABB _calculateAABB(Vector3 position, Vector3 size) {
    // 1. 左右方向（X轴）：对称分布
    final halfWidth = size.x / 2.0;
    final minX = position.x - halfWidth;
    final maxX = position.x + halfWidth;

    // 2. 上下方向（Y轴）：眼睛靠近顶部（顶部占比小，底部占比大）
    // 例如：顶部占总高度的25%，底部占75%
    const topRatio = 0.25; // 顶部距离占总高度比例
    final bottomRatio = 1.0 - topRatio; // 底部距离占总高度比例
    final topHalfY = size.y * topRatio; // 眼睛到顶部的距离
    final bottomHalfY = size.y * bottomRatio; // 眼睛到底部的距离
    final minY = position.y - bottomHalfY; // 碰撞体底部
    final maxY = position.y + topHalfY; // 碰撞体顶部

    // 3. 水平方向保持对称。碰撞盒不应沿世界 Z 轴产生固定偏移；
    // 玩家朝向只影响移动和视角，不改变身体中心。
    final halfDepth = size.z / 2.0;
    final minZ = position.z - halfDepth;
    final maxZ = position.z + halfDepth;

    // 构建AABB的min和max
    final min = Vector3(minX, minY, minZ);
    final max = Vector3(maxX, maxY, maxZ);
    return AABB(min, max);
  }

  bool checkFixedBox(FixedBoxCollider collider) {
    return aabb.intersects(collider.aabb.toAABB());
  }

  // 计算与另一个 Collider 的重叠量（用于碰撞响应）
  Vector3 resolveFixedBox(FixedBoxCollider other) {
    return aabb.calculateOverlap(other.aabb.toAABB());
  }
}
