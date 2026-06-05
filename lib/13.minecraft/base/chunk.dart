import 'aabb.dart';
import 'block.dart';
import 'constant.dart';
import 'vector.dart';
import 'octree.dart';

/// 区块类
class Chunk {
  static const int chunkSize = Constants.chunkBlockCount * Constants.blockSize;
  static const int chunkSizeHalf =
      Constants.chunkBlockCount * Constants.blockSizeHalf;

  final Vector3Int chunkCoord;
  late final BlockOctree octree;

  Chunk(this.chunkCoord) {
    octree = BlockOctree(center: center, size: chunkSizeHalf);
  }

  Vector3Int get center => Vector3Int(
    chunkCoord.x * chunkSize + chunkSizeHalf,
    chunkCoord.y * chunkSize + chunkSizeHalf,
    chunkCoord.z * chunkSize + chunkSizeHalf,
  );

  Vector3Int get min => Vector3Int(
    chunkCoord.x * chunkSize,
    chunkCoord.y * chunkSize,
    chunkCoord.z * chunkSize,
  );

  Vector3Int get max => min + Vector3Int.all(chunkSize);

  AABBInt get aabb => AABBInt(min, max);

  /// 添加方块到区块
  bool addBlock(Block block) {
    // 检查方块坐标是否在区块范围内
    final pos = block.position;
    if (pos.x < min.x ||
        pos.x >= max.x ||
        pos.y < min.y ||
        pos.y >= max.y ||
        pos.z < min.z ||
        pos.z >= max.z) {
      return false;
    }
    return octree.insertBlock(block);
  }

  /// 从区块移除方块
  bool removeBlock(Block block) => octree.removeBlock(block);

  /// 获取区块内指定位置的方块
  Block? getBlock(Vector3Int position) => octree.getBlock(position);

  void removeBlockByPos(Vector3Int position) {
    Block? block = getBlock(position);
    if (block != null) {
      removeBlock(block);
    }
  }

  /// 获取整个区块内的所有方块
  List<Block> getAllBlocks() {
    return octree.getAllBlocks();
  }

  /// 获取指定位置和半径内的方块
  List<Block> getBlocksInRange(Vector3 position, double radius) {
    return octree.queryRange(
      AABB.fromCenterAndHalfSize(position, Vector3.all(radius)),
    );
  }
}
