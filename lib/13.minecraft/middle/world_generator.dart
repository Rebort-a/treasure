import 'dart:math' as math;

import '../base/aabb.dart';
import '../base/block.dart';
import '../base/constant.dart';
import '../base/chunk.dart';
import '../base/vector.dart';

/// 预计算的树木数据
class PrecomputedTree {
  final Vector3Int coord; // 树干基部坐标（实际地表高度）
  final int trunkHeight; // 树干高度
  final AABBInt treeAABB; // 整棵树包围盒

  PrecomputedTree({
    required this.coord,
    required this.trunkHeight,
    required this.treeAABB,
  });
}

/// 生物群系类型
enum BiomeType {
  plains, // 平原
  forest, // 森林
  desert, // 沙漠
  mountains, // 山脉
  snowy, // 雪地
  beach, // 海滩
  swamp, // 沼泽
}

/// 世界生成器
class WorldGenerator {
  // ---------------------- 核心常量 ----------------------
  static const int _blockSize = Constants.blockSize;
  static const int _blockSizeHalf = Constants.blockSizeHalf; // 确保为奇数（如1,3等）
  static const int _chunkBlockCount = Constants.chunkBlockCount;
  static const int _groupSize = Constants.chunkGroupSize;

  // 衍生尺寸
  static const int _chunkSize = _chunkBlockCount * _blockSize;
  static const int _groupTotalSize = _chunkSize * _groupSize;

  // 树木配置
  static const int _treeCanopyRadius = 2 * _blockSize;
  static const int _treeCanopyHeight = 4 * _blockSize;
  static const int _canopyHalfHeight = _treeCanopyHeight ~/ 2;

  // 世界高度（worldSurfaceLevel为地表最低高度基准）
  static const int _minSurfaceY =
      Constants.worldSurfaceLevel; // 地表最低高度（符合y坐标规则）
  static const int _bedrockY = Constants.worldBedrockLevel;

  // 地表层数配置（最少1层，最多6层，零层概率1%）
  static const int _minSurfaceLayers = 1;
  static const int _maxSurfaceLayers = 6;
  static const double _zeroLayerChance = 0.01;

  // 噪音配置
  static const double _noiseTempScale = 0.002;
  static const double _noiseHumidityScale = 0.003;

  // 生物群系-树木映射
  static const Map<BiomeType, double> _treeSpawnChances = {
    BiomeType.forest: 0.1,
    BiomeType.plains: 0.025,
    BiomeType.swamp: 0.075,
  };
  static const Map<BiomeType, (int base, int range)> _treeHeightConfig = {
    BiomeType.forest: (4, 3),
    BiomeType.plains: (3, 2),
    BiomeType.swamp: (2, 2),
  };

  // ---------------------- 缓存与成员变量 ----------------------
  final Map<Vector3Int, int> _groupSeeds = {};
  final Map<Vector3Int, List<List<BiomeType>>> _groupBiomeMaps = {};
  final Map<Vector3Int, List<List<int>>> _groupSurfaceTopYs =
      {}; // 存储每个(x,z)的地表顶层Y坐标
  final Map<Vector3Int, List<PrecomputedTree>> _groupPrecomputedTrees = {};
  final int index;

  WorldGenerator(this.index);

  // ---------------------- 通用工具：缓存获取 ----------------------
  T _getCached<T>(
    Map<Vector3Int, T> cache,
    Vector3Int key,
    T Function() generator,
  ) => cache.putIfAbsent(key, generator);

  // ---------------------- 坐标转换 ----------------------
  static Vector3Int _getGroupCoord(Vector3Int chunkCoord) => Vector3Int(
    chunkCoord.x ~/ _groupSize,
    chunkCoord.y ~/ _groupSize,
    chunkCoord.z ~/ _groupSize,
  );

  static Vector3Int _getGroupOffset(Vector3Int chunkCoord) => Vector3Int(
    chunkCoord.x % _groupSize,
    chunkCoord.y % _groupSize,
    chunkCoord.z % _groupSize,
  );

  // ---------------------- 种子与生物群系生成 ----------------------
  int _getGroupSeed(Vector3Int groupCoord) =>
      _getCached(_groupSeeds, groupCoord, () {
        final baseSeed = math.Random(index).nextInt(0x7FFFFFFF);
        return (baseSeed ^ groupCoord.x ^ groupCoord.y ^ groupCoord.z) &
            0x7FFFFFFF;
      });

  List<List<BiomeType>> _getGroupBiomeMap(
    Vector3Int groupCoord,
    math.Random groupRandom,
  ) => _getCached(_groupBiomeMaps, groupCoord, () {
    final groupWorldX = groupCoord.x * _groupTotalSize;
    final groupWorldZ = groupCoord.z * _groupTotalSize;
    final biomeMap = List.generate(
      _groupTotalSize,
      (_) => List.filled(_groupTotalSize, BiomeType.plains),
    );

    for (int x = _blockSizeHalf; x < _groupTotalSize; x += _blockSize) {
      for (int z = _blockSizeHalf; z < _groupTotalSize; z += _blockSize) {
        final worldX = groupWorldX + x;
        final worldZ = groupWorldZ + z;

        final temperature =
            _simpleNoise(
                  worldX * _noiseTempScale,
                  worldZ * _noiseTempScale,
                  groupRandom,
                ) *
                0.5 +
            0.5;
        final humidity =
            _simpleNoise(
                  worldX * _noiseHumidityScale,
                  worldZ * _noiseHumidityScale,
                  groupRandom,
                ) *
                0.5 +
            0.5;

        biomeMap[x][z] = _getBiomeType(temperature, humidity);
      }
    }
    return biomeMap;
  });

  // ---------------------- 地表高度生成（核心修改） ----------------------
  /// 获取地表层数（1-6层为主，1%概率0层）
  int _getSurfaceLayers(math.Random random) {
    if (random.nextDouble() < _zeroLayerChance) {
      return 0; // 零层（空）
    }
    return _minSurfaceLayers +
        random.nextInt(_maxSurfaceLayers - _minSurfaceLayers + 1);
  }

  /// 计算地表顶层Y坐标（基于层数，确保符合y坐标规则）
  int _getSurfaceTopY(int layers) {
    if (layers == 0) {
      return _minSurfaceY - _blockSize; // 零层时低于最低高度
    }
    // 层数为n时，顶层Y = 最低高度 + (n-1)*blockSize（确保步进为blockSize）
    return _minSurfaceY + (layers - 1) * _blockSize;
  }

  /// 获取群组内所有位置的地表顶层Y坐标缓存
  List<List<int>> _getGroupSurfaceTopYs(
    Vector3Int groupCoord,
    math.Random groupRandom,
  ) => _getCached(_groupSurfaceTopYs, groupCoord, () {
    final surfaceTopYs = List.generate(
      _groupTotalSize,
      (_) => List.filled(_groupTotalSize, _minSurfaceY),
    );

    for (int x = _blockSizeHalf; x < _groupTotalSize; x += _blockSize) {
      for (int z = _blockSizeHalf; z < _groupTotalSize; z += _blockSize) {
        final layers = _getSurfaceLayers(groupRandom);
        surfaceTopYs[x][z] = _getSurfaceTopY(layers);
      }
    }
    return surfaceTopYs;
  });

  // ---------------------- 生物群系判断 ----------------------
  BiomeType _getBiomeType(double temperature, double humidity) {
    if (temperature > 0.7) {
      return humidity < 0.3 ? BiomeType.desert : BiomeType.plains;
    }
    if (temperature < 0.3) return BiomeType.swamp;
    if (humidity > 0.6) return BiomeType.forest;
    return BiomeType.plains;
  }

  // ---------------------- 树木生成辅助（修改基准为实际地表高度） ----------------------
  bool _shouldGenerateTree(BiomeType biome, math.Random groupRandom) =>
      groupRandom.nextDouble() < (_treeSpawnChances[biome] ?? 0.0);

  int _getTreeHeight(BiomeType biome, math.Random groupRandom) {
    final (base, range) = _treeHeightConfig[biome] ?? (3, 0);
    return base * _blockSize + groupRandom.nextInt(range) * _blockSize;
  }

  bool _isAwayFromGroupEdge(
    int worldX,
    int worldZ,
    int groupWorldX,
    int groupWorldZ,
  ) {
    final edgeMargin = _treeCanopyRadius;
    final innerX = worldX - groupWorldX;
    final innerZ = worldZ - groupWorldZ;
    return innerX >= edgeMargin &&
        innerX <= _groupTotalSize - edgeMargin &&
        innerZ >= edgeMargin &&
        innerZ <= _groupTotalSize - edgeMargin;
  }

  // ---------------------- 地表方块类型 ----------------------
  BlockType _getSurfaceBlockType(BiomeType biome) => switch (biome) {
    BiomeType.desert || BiomeType.beach => BlockType.sand,
    BiomeType.snowy => BlockType.snow,
    _ => BlockType.grass,
  };

  // ---------------------- 噪音生成 ----------------------
  static double _simpleNoise(double x, double z, math.Random groupRandom) {
    final seed =
        (((x * 73856093).toInt()) ^ ((z * 19349663).toInt())) & 0x7FFFFFFF;
    return math.Random(seed ^ groupRandom.nextInt(0x7FFFFFFF)).nextDouble() *
            2 -
        1;
  }

  // ---------------------- 区块生成核心（修改地表和树木生成逻辑） ----------------------
  void generateChunk(Chunk chunk) {
    final chunkCoord = chunk.chunkCoord;
    final groupCoord = _getGroupCoord(chunkCoord);
    final groupRandom = math.Random(_getGroupSeed(groupCoord));
    final groupBiomeMap = _getGroupBiomeMap(groupCoord, groupRandom);
    final groupSurfaceTopYs = _getGroupSurfaceTopYs(groupCoord, groupRandom);
    final groupTrees = _precomputeTrees(
      groupCoord,
      groupBiomeMap,
      groupSurfaceTopYs,
      groupRandom,
    );

    // 计算区块坐标范围
    final groupOffset = _getGroupOffset(chunkCoord);
    final chunkXStart = groupOffset.x * _chunkSize;
    final chunkZStart = groupOffset.z * _chunkSize;
    final worldXBase = chunkCoord.x * _chunkSize;
    final worldZBase = chunkCoord.z * _chunkSize;

    // 生成地表（多层结构，基于实际高度）
    for (int x = _blockSizeHalf; x < _chunkSize; x += _blockSize) {
      for (int z = _blockSizeHalf; z < _chunkSize; z += _blockSize) {
        final mapX = chunkXStart + x;
        final mapZ = chunkZStart + z;
        final biome = groupBiomeMap[mapX][mapZ];
        final surfaceTopY = groupSurfaceTopYs[mapX][mapZ];
        final layers = (surfaceTopY - _minSurfaceY) ~/ _blockSize + 1;

        // 生成地表层（顶层为生物群系对应类型，下层为泥土）
        if (layers > 0) {
          for (int i = 0; i < layers; i++) {
            final y = surfaceTopY - i * _blockSize; // y坐标步进为blockSize，保持奇数
            final blockType = i == 0
                ? _getSurfaceBlockType(biome)
                : BlockType.dirt; // 下层用泥土

            final surfaceBlock = Block(
              position: Vector3Int(worldXBase + x, y, worldZBase + z),
              type: blockType,
            );
            chunk.addBlock(surfaceBlock);
          }
        }

        // 生成基岩（固定高度，确保y坐标符合规则）
        final bedrockBlock = Block(
          position: Vector3Int(worldXBase + x, _bedrockY, worldZBase + z),
          type: BlockType.bedrock,
        );
        chunk.addBlock(bedrockBlock);
      }
    }

    // 生成重叠的树木部分
    for (final tree in groupTrees) {
      if (tree.treeAABB.intersects(chunk.aabb)) {
        _generateOverlappedTreePart(chunk, tree, groupRandom);
      }
    }
  }

  // ---------------------- 树木预计算（基于实际地表高度） ----------------------
  List<PrecomputedTree> _precomputeTrees(
    Vector3Int groupCoord,
    List<List<BiomeType>> groupBiomeMap,
    List<List<int>> groupSurfaceTopYs,
    math.Random groupRandom,
  ) => _getCached(_groupPrecomputedTrees, groupCoord, () {
    final groupWorldX = groupCoord.x * _groupTotalSize;
    final groupWorldZ = groupCoord.z * _groupTotalSize;
    final trees = <PrecomputedTree>[];

    for (int x = _blockSizeHalf; x < _groupTotalSize; x += _blockSize) {
      for (int z = _blockSizeHalf; z < _groupTotalSize; z += _blockSize) {
        final worldX = groupWorldX + x;
        final worldZ = groupWorldZ + z;
        final biome = groupBiomeMap[x][z];
        final surfaceTopY = groupSurfaceTopYs[x][z];
        final layers = (surfaceTopY - _minSurfaceY) ~/ _blockSize + 1;

        // 零层地表不生成树木
        if (layers <= 0) continue;

        if (_shouldGenerateTree(biome, groupRandom) &&
            _isAwayFromGroupEdge(worldX, worldZ, groupWorldX, groupWorldZ)) {
          final trunkHeight = _getTreeHeight(biome, groupRandom);
          final trunkBaseY = surfaceTopY; // 树干从实际地表顶层开始

          // 计算树木包围盒（基于实际地表高度）
          final treeMin = Vector3Int(
            worldX - _treeCanopyRadius,
            trunkBaseY, // 包围盒从树干基部（实际地表）开始
            worldZ - _treeCanopyRadius,
          );
          final treeMax = Vector3Int(
            worldX + _treeCanopyRadius,
            trunkBaseY + trunkHeight + _treeCanopyHeight,
            worldZ + _treeCanopyRadius,
          );

          trees.add(
            PrecomputedTree(
              coord: Vector3Int(worldX, trunkBaseY, worldZ),
              trunkHeight: trunkHeight,
              treeAABB: AABBInt(treeMin, treeMax),
            ),
          );
        }
      }
    }
    return trees;
  });

  // ---------------------- 生成重叠树木（确保y坐标符合规则） ----------------------
  void _generateOverlappedTreePart(
    Chunk chunk,
    PrecomputedTree tree,
    math.Random groupRandom,
  ) {
    final (trunkX, trunkBaseY, trunkZ) = (
      tree.coord.x,
      tree.coord.y,
      tree.coord.z,
    );
    final trunkHeight = tree.trunkHeight;
    final canopyBaseY = trunkBaseY + trunkHeight;

    // 1. 生成树干（y坐标步进为blockSize，保持奇数）
    for (int y = trunkBaseY; y < trunkBaseY + trunkHeight; y += _blockSize) {
      final pos = Vector3Int(trunkX, y, trunkZ);
      if (chunk.aabb.contains(pos)) {
        chunk.addBlock(Block(position: pos, type: BlockType.wood));
      }
    }

    // 2. 生成树叶（y坐标符合规则）
    final canopyMin = -_treeCanopyRadius;
    final canopyMax = _treeCanopyRadius;
    final step = _blockSize;

    for (int xOff = canopyMin; xOff <= canopyMax; xOff += step) {
      for (int zOff = canopyMin; zOff <= canopyMax; zOff += step) {
        for (int yOff = 0; yOff < _treeCanopyHeight; yOff += step) {
          final leafPos = Vector3Int(
            trunkX + xOff,
            canopyBaseY + yOff, // yOff步进为blockSize，确保整体为奇数
            trunkZ + zOff,
          );
          if (!chunk.aabb.contains(leafPos)) continue;

          // 球形树冠判断
          final dist2D = math.sqrt((xOff * xOff + zOff * zOff).toDouble());
          final heightFactor = 1.0 - (yOff / _treeCanopyHeight);
          final maxDist = _treeCanopyRadius * (0.3 + 0.7 * heightFactor);
          final yDiff = yOff - _canopyHalfHeight;
          final dist3D = math.sqrt(dist2D * dist2D + (yDiff / 2) * (yDiff / 2));

          if (dist3D <= maxDist) {
            chunk.addBlock(Block(position: leafPos, type: BlockType.leaf));
          }
        }
      }
    }
  }
}
