import 'dart:collection';

import '../base/aabb.dart';
import '../base/block.dart';
import '../base/chunk.dart';
import '../base/constant.dart';
import '../base/player.dart';
import '../base/vector.dart';
import '../base/voxel_coordinates.dart';
import 'world_generator.dart';

/// 区块管理器
class ChunkManager {
  static const int chunkSize = Constants.chunkBlockCount * Constants.blockSize;
  static const int horizontalDistance = Constants.loadChunkHorizontalCount;
  static const int verticalDistance = Constants.loadChunkVerticalCount;
  final Map<Vector3Int, Chunk> _archivedBlocks = HashMap();
  final Map<Vector3Int, Chunk> _loadedChunks = HashMap();
  final Queue<Vector3Int> _chunkLoadQueue = Queue();
  late final WorldGenerator _worldGenerator;

  Vector3Int? _lastPlayerChunk;
  Set<Vector3Int> _desiredChunks = {};
  bool _initialized = false;

  ChunkManager({int seed = 20260908}) {
    _worldGenerator = WorldGenerator(seed);
  }

  static Vector3Int getChunkCoord(Vector3 worldPos) {
    return VoxelCoordinates.worldToChunk(worldPos, chunkSize);
  }

  /// 指定 (x, z) 列的地表高度（仅地形，不含结构），用于选择出生点。
  int surfaceHeightAt(int x, int z) =>
      _worldGenerator.surfaceHeightAt(x, z);

  /// 区块更新
  void updateChunks(Vector3 playerPos) {
    final playerChunk = getChunkCoord(playerPos);

    if (playerChunk == _lastPlayerChunk) {
      return;
    }

    _lastPlayerChunk = playerChunk;

    // 1.生成需要保留的区块列表
    final aroundChunks = _getAroundChunks(playerChunk);
    _desiredChunks = aroundChunks;

    // 2. 卸载不在需要保留列表中的区块
    final chunksToUnload = _loadedChunks.keys
        .where((coord) => !aroundChunks.contains(coord))
        .toList();
    for (final coord in chunksToUnload) {
      _loadedChunks.remove(coord);
    }

    _chunkLoadQueue.removeWhere((coord) => !aroundChunks.contains(coord));

    final chunksToLoad =
        aroundChunks
            .where(
              (coord) =>
                  !_loadedChunks.containsKey(coord) &&
                  !_chunkLoadQueue.contains(coord),
            )
            .toList()
          ..sort((a, b) {
            final da = (a - playerChunk).magnitudeSquare;
            final db = (b - playerChunk).magnitudeSquare;
            return da.compareTo(db);
          });

    if (!_initialized) {
      // 首屏需要立即可用；之后的区块切换使用加载队列摊平开销。
      for (final chunkCoord in chunksToLoad) {
        _loadChunk(chunkCoord);
      }
      _initialized = true;
    } else {
      _chunkLoadQueue.addAll(chunksToLoad);
    }
  }

  /// 获取玩家周围区块
  Set<Vector3Int> _getAroundChunks(Vector3Int playerChunk) {
    final Set<Vector3Int> chunks = {};

    // 一次遍历生成所有在距离范围内的区块
    for (int x = -horizontalDistance; x <= horizontalDistance; x++) {
      for (int z = -horizontalDistance; z <= horizontalDistance; z++) {
        for (int y = -verticalDistance; y <= verticalDistance; y++) {
          chunks.add(
            Vector3Int(playerChunk.x + x, playerChunk.y + y, playerChunk.z + z),
          );
        }
      }
    }

    return chunks;
  }

  /// 处理加载队列
  bool processLoadQueue({int budget = 1}) {
    var loadedAny = false;
    for (var i = 0; i < budget && _chunkLoadQueue.isNotEmpty; i++) {
      final chunkCoord = _chunkLoadQueue.removeFirst();
      if (!_desiredChunks.contains(chunkCoord)) continue;
      _loadChunk(chunkCoord);
      loadedAny = true;
    }
    return loadedAny;
  }

  /// 加载单个区块
  void _loadChunk(Vector3Int chunkCoord) {
    if (!_loadedChunks.containsKey(chunkCoord)) {
      if (_archivedBlocks.containsKey(chunkCoord)) {
        _loadedChunks[chunkCoord] = _archivedBlocks[chunkCoord]!;
      } else {
        final chunk = Chunk(chunkCoord);
        _worldGenerator.generateChunk(chunk);
        _archivedBlocks[chunkCoord] = chunk;
        _loadedChunks[chunkCoord] = chunk;
      }
    }
  }

  /// 获取玩家附近方块
  List<Block> _getBlocksNearPlayer(AABB aabb) {
    final List<Block> blocks = [];
    for (final chunk in _loadedChunks.values) {
      // 先做区块级 AABB 粗筛，跳过不相交的区块
      if (!aabb.intersects(chunk.aabb.toAABB())) continue;
      final chunkBlocks = chunk.octree.queryRange(aabb);
      blocks.addAll(chunkBlocks);
    }

    return blocks;
  }

  List<Block> getRenderBlocks(Player player) {
    final AABB aabb = AABB.fromCenterAndHalfSize(
      player.position,
      const Vector3(
        Constants.renderDistance,
        Constants.renderVerticalDistance,
        Constants.renderDistance,
      ),
    );

    return _getBlocksNearPlayer(aabb);
  }

  List<Block> getCollisionBlocks(Player player) {
    final AABB aabb = player.collider.aabb.expand(
      Constants.blockSizeHalf.toDouble(),
    );
    return _getBlocksNearPlayer(aabb);
  }

  /// 获取指定坐标的方块
  Block? getBlock(Vector3Int position) {
    final chunkCoord = getChunkCoord(position.toVector3());
    final chunk = _loadedChunks[chunkCoord];
    return chunk?.getBlock(position);
  }

  /// 摧毁指定坐标的方块
  bool destroyBlock(Vector3Int position) {
    final chunkCoord = getChunkCoord(position.toVector3());
    final chunk = _loadedChunks[chunkCoord];
    if (chunk == null) return false;
    final block = chunk.getBlock(position);
    if (block == null) return false;
    chunk.removeBlock(block);
    return true;
  }

  /// 在指定坐标放置方块
  bool placeBlock(Vector3Int position, BlockType type) {
    final chunkCoord = getChunkCoord(position.toVector3());
    final chunk = _loadedChunks[chunkCoord];
    if (chunk == null) return false;
    if (chunk.getBlock(position) != null) return false;
    return chunk.addBlock(Block(position: position, type: type));
  }

  /// 检查是否有待加载区块
  bool get hasPendingChunks => _chunkLoadQueue.isNotEmpty;
}
