import '../base/block.dart';
import '../base/vector.dart';
import 'chunk_manager.dart';

/// 射线检测命中结果
class RaycastHit {
  final Block block;
  final Vector3Int faceNormal;

  const RaycastHit({required this.block, required this.faceNormal});
}

/// X/Z: 方块中心在奇数 (1, 3, 5, ...)
int _snapOdd(double v) => (v / 2).floor() * 2 + 1;

/// Y: 方块中心在偶数 (0, 2, 4, ...)
int _snapEven(double v) => (v / 2).floor() * 2;

/// DDA 射线检测：从 position 沿 direction 找到第一个非空气方块
RaycastHit? raycast(
  Vector3 position,
  Vector3 direction,
  ChunkManager chunkManager,
  double maxDistance,
) {
  final dir = direction.normalized;
  if (dir.isZero) return null;

  int ix = _snapOdd(position.x);
  int iy = _snapEven(position.y);
  int iz = _snapOdd(position.z);

  final stepX = dir.x >= 0 ? 1 : -1;
  final stepY = dir.y >= 0 ? 1 : -1;
  final stepZ = dir.z >= 0 ? 1 : -1;

  final nextX = ix + (stepX > 0 ? 1.0 : -1.0);
  final nextY = iy + (stepY > 0 ? 1.0 : -1.0);
  final nextZ = iz + (stepZ > 0 ? 1.0 : -1.0);

  final tMaxX = dir.x.abs() > 1e-10
      ? (nextX - position.x) / dir.x
      : double.maxFinite;
  final tMaxY = dir.y.abs() > 1e-10
      ? (nextY - position.y) / dir.y
      : double.maxFinite;
  final tMaxZ = dir.z.abs() > 1e-10
      ? (nextZ - position.z) / dir.z
      : double.maxFinite;

  final tDeltaX = dir.x.abs() > 1e-10 ? 2.0 / dir.x.abs() : double.maxFinite;
  final tDeltaY = dir.y.abs() > 1e-10 ? 2.0 / dir.y.abs() : double.maxFinite;
  final tDeltaZ = dir.z.abs() > 1e-10 ? 2.0 / dir.z.abs() : double.maxFinite;

  double tMaxX_ = tMaxX;
  double tMaxY_ = tMaxY;
  double tMaxZ_ = tMaxZ;

  Vector3Int faceNormal = Vector3Int.zero;
  final maxSteps = (maxDistance * 3).ceil();

  for (int i = 0; i < maxSteps; i++) {
    final block = chunkManager.getBlock(Vector3Int(ix, iy, iz));

    if (block != null && block.type != BlockType.air) {
      return RaycastHit(block: block, faceNormal: faceNormal);
    }

    if (tMaxX_ < tMaxY_) {
      if (tMaxX_ < tMaxZ_) {
        if (tMaxX_ > maxDistance) break;
        ix += stepX * 2;
        tMaxX_ += tDeltaX;
        faceNormal = Vector3Int(-stepX, 0, 0);
      } else {
        if (tMaxZ_ > maxDistance) break;
        iz += stepZ * 2;
        tMaxZ_ += tDeltaZ;
        faceNormal = Vector3Int(0, 0, -stepZ);
      }
    } else {
      if (tMaxY_ < tMaxZ_) {
        if (tMaxY_ > maxDistance) break;
        iy += stepY * 2;
        tMaxY_ += tDeltaY;
        faceNormal = Vector3Int(0, -stepY, 0);
      } else {
        if (tMaxZ_ > maxDistance) break;
        iz += stepZ * 2;
        tMaxZ_ += tDeltaZ;
        faceNormal = Vector3Int(0, 0, -stepZ);
      }
    }
  }

  return null;
}
