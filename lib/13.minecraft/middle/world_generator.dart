import 'dart:math' as math;

import '../base/block.dart';
import '../base/chunk.dart';
import '../base/constant.dart';
import '../base/vector.dart';

enum BiomeType { plains, forest, desert, mountains, snowy, beach, swamp }

/// 确定性的程序化世界生成器。
///
/// 地形由连续分形噪声生成，地下为实体石层并包含洞穴和矿石；低地会被
/// 海水填充。树木和仙人掌使用坐标哈希生成，因此区块生成顺序不会改变
/// 世界结果，也能自然跨越区块边界。
class WorldGenerator {
  static const int _blockSize = Constants.blockSize;
  static const int _half = Constants.blockSizeHalf;
  static const int _chunkSize = Constants.chunkBlockCount * Constants.blockSize;

  final int seed;

  const WorldGenerator(this.seed);

  void generateChunk(Chunk chunk) {
    _generateTerrain(chunk);
    _generateStructures(chunk);
  }

  /// 指定 (x, z) 列的地表高度（仅地形，不含树木等结构）。
  /// 用于在不加载区块的情况下估算出生点高度。
  int surfaceHeightAt(int x, int z) => _columnInfo(x, z).surfaceY;

  void _generateTerrain(Chunk chunk) {
    for (var localX = _half; localX < _chunkSize; localX += _blockSize) {
      for (var localZ = _half; localZ < _chunkSize; localZ += _blockSize) {
        final worldX = chunk.min.x + localX;
        final worldZ = chunk.min.z + localZ;
        final column = _columnInfo(worldX, worldZ);

        for (var y = chunk.min.y; y < chunk.max.y; y += _blockSize) {
          final type = _blockAt(worldX, y, worldZ, column);
          if (type != BlockType.air) {
            chunk.addBlock(
              Block(position: Vector3Int(worldX, y, worldZ), type: type),
            );
          }
        }
      }
    }
  }

  BlockType _blockAt(int x, int y, int z, _ColumnInfo column) {
    if (y < Constants.worldBedrockLevel || y >= Constants.worldMaxHeight) {
      return BlockType.air;
    }
    if (y == Constants.worldBedrockLevel) return BlockType.bedrock;

    if (y > column.surfaceY) {
      if (y <= Constants.worldSeaLevel) {
        if (column.biome == BiomeType.snowy && y == Constants.worldSeaLevel) {
          return BlockType.ice;
        }
        return BlockType.water;
      }
      return BlockType.air;
    }

    final depth = column.surfaceY - y;
    if (depth == 0) return _surfaceBlock(column.biome, column.surfaceY);
    if (depth <= _blockSize * 3) {
      return switch (column.biome) {
        BiomeType.desert || BiomeType.beach => BlockType.sand,
        _ => BlockType.dirt,
      };
    }

    if (_isCave(x, y, z, column.surfaceY)) return BlockType.air;
    return _oreAt(x, y, z) ?? BlockType.stone;
  }

  _ColumnInfo _columnInfo(int x, int z) {
    final continental = _fbm2(x * 0.012, z * 0.012, 11);
    final detail = _fbm2(x * 0.035, z * 0.035, 23);
    final temperature = (_fbm2(x * 0.004, z * 0.004, 37) + 1) * 0.5;
    final humidity = (_fbm2(x * 0.005, z * 0.005, 53) + 1) * 0.5;

    var height = Constants.worldSurfaceLevel + continental * 13 + detail * 4;
    final preliminaryHeight = _snapVertical(height.round());
    final biome = _selectBiome(
      temperature: temperature,
      humidity: humidity,
      elevation: continental,
      surfaceY: preliminaryHeight,
    );

    if (biome == BiomeType.mountains) {
      height += 8 + continental.abs() * 12;
    } else if (biome == BiomeType.swamp) {
      height = Constants.worldSeaLevel - 2 + detail * 2;
    } else if (biome == BiomeType.beach) {
      height = height.clamp(
        Constants.worldSeaLevel - 2,
        Constants.worldSeaLevel + 2,
      );
    }

    return _ColumnInfo(
      surfaceY: _snapVertical(
        height
            .clamp(
              Constants.worldBedrockLevel + 8,
              Constants.worldMaxHeight - 20,
            )
            .round(),
      ),
      biome: biome,
    );
  }

  BiomeType _selectBiome({
    required double temperature,
    required double humidity,
    required double elevation,
    required int surfaceY,
  }) {
    if ((surfaceY - Constants.worldSeaLevel).abs() <= 2) {
      return BiomeType.beach;
    }
    if (elevation > 0.48) return BiomeType.mountains;
    if (temperature < 0.28 || surfaceY > 42) return BiomeType.snowy;
    if (surfaceY < Constants.worldSeaLevel - 2 && humidity > 0.55) {
      return BiomeType.swamp;
    }
    if (temperature > 0.68 && humidity < 0.42) {
      return BiomeType.desert;
    }
    if (humidity > 0.62) return BiomeType.forest;
    return BiomeType.plains;
  }

  BlockType _surfaceBlock(BiomeType biome, int surfaceY) {
    return switch (biome) {
      BiomeType.desert || BiomeType.beach => BlockType.sand,
      BiomeType.snowy => BlockType.snow,
      BiomeType.mountains when surfaceY > 46 => BlockType.stone,
      _ => BlockType.grass,
    };
  }

  BlockType? _oreAt(int x, int y, int z) {
    final value = _hash01(x, y, z, 71);
    final depthFactor = ((Constants.worldSeaLevel - y) / 80).clamp(0.0, 1.0);

    if (y < -28 && value < 0.004 + depthFactor * 0.004) {
      return BlockType.diamondOre;
    }
    if (y < -12 && value < 0.012) return BlockType.goldOre;
    if (y < 8 && value < 0.025) return BlockType.ironOre;
    if (value < 0.055) return BlockType.coalOre;
    if (y < -20 && value > 0.992) return BlockType.emeraldOre;
    return null;
  }

  bool _isCave(int x, int y, int z, int surfaceY) {
    if (y >= surfaceY - 6 || y <= Constants.worldBedrockLevel + 4) {
      return false;
    }
    final waves =
        math.sin((x + seed) * 0.10) +
        math.sin((y - seed) * 0.13) +
        math.sin((z + seed * 2) * 0.09);
    final variation = _fbm2((x + y) * 0.025, (z - y) * 0.025, 89);
    return waves + variation * 1.2 > 2.45;
  }

  void _generateStructures(Chunk chunk) {
    const margin = 6;
    final minX = chunk.min.x - margin;
    final maxX = chunk.max.x + margin;
    final minZ = chunk.min.z - margin;
    final maxZ = chunk.max.z + margin;

    for (var x = _snapHorizontal(minX.toDouble()); x < maxX; x += _blockSize) {
      for (
        var z = _snapHorizontal(minZ.toDouble());
        z < maxZ;
        z += _blockSize
      ) {
        final column = _columnInfo(x, z);
        if (column.surfaceY < Constants.worldSeaLevel) continue;

        if (column.biome == BiomeType.desert) {
          if (_hash01(x, 0, z, 101) < 0.018) {
            _placeCactus(chunk, x, column.surfaceY + _blockSize, z);
          }
          continue;
        }

        final chance = switch (column.biome) {
          BiomeType.forest => 0.10,
          BiomeType.plains => 0.022,
          BiomeType.swamp => 0.055,
          BiomeType.snowy => 0.025,
          _ => 0.0,
        };
        if (_hash01(x, 0, z, 103) < chance) {
          _placeTree(chunk, x, column.surfaceY + _blockSize, z);
        }
      }
    }
  }

  void _placeTree(Chunk chunk, int x, int baseY, int z) {
    final trunkBlocks = 3 + (_hash(x, baseY, z, 107) % 3);
    final trunkTop = baseY + (trunkBlocks - 1) * _blockSize;

    for (var i = 0; i < trunkBlocks; i++) {
      _placeIfInside(
        chunk,
        Vector3Int(x, baseY + i * _blockSize, z),
        BlockType.wood,
      );
    }

    for (var dx = -4; dx <= 4; dx += _blockSize) {
      for (var dz = -4; dz <= 4; dz += _blockSize) {
        for (var dy = -2; dy <= 4; dy += _blockSize) {
          final horizontal = dx.abs() + dz.abs();
          final allowed = dy >= 2 ? 4 : 6;
          if (horizontal > allowed) continue;
          if (dx == 0 && dz == 0 && dy <= 0) continue;
          _placeIfInside(
            chunk,
            Vector3Int(x + dx, trunkTop + dy, z + dz),
            BlockType.leaf,
            replaceSolid: false,
          );
        }
      }
    }
  }

  void _placeCactus(Chunk chunk, int x, int baseY, int z) {
    final height = 2 + (_hash(x, baseY, z, 109) % 2);
    for (var i = 0; i < height; i++) {
      _placeIfInside(
        chunk,
        Vector3Int(x, baseY + i * _blockSize, z),
        BlockType.cactus,
      );
    }
  }

  void _placeIfInside(
    Chunk chunk,
    Vector3Int position,
    BlockType type, {
    bool replaceSolid = true,
  }) {
    if (!chunk.aabb.contains(position)) return;
    final existing = chunk.getBlock(position);
    if (existing != null && !replaceSolid) return;
    chunk.addBlock(Block(position: position, type: type));
  }

  double _fbm2(double x, double z, int salt) {
    var amplitude = 0.55;
    var frequency = 1.0;
    var total = 0.0;
    var normalization = 0.0;

    for (var octave = 0; octave < 4; octave++) {
      total +=
          _valueNoise2(x * frequency, z * frequency, salt + octave * 17) *
          amplitude;
      normalization += amplitude;
      amplitude *= 0.5;
      frequency *= 2.0;
    }
    return total / normalization;
  }

  double _valueNoise2(double x, double z, int salt) {
    final x0 = x.floor();
    final z0 = z.floor();
    final tx = _smooth(x - x0);
    final tz = _smooth(z - z0);

    final a = _hash01(x0, 0, z0, salt) * 2 - 1;
    final b = _hash01(x0 + 1, 0, z0, salt) * 2 - 1;
    final c = _hash01(x0, 0, z0 + 1, salt) * 2 - 1;
    final d = _hash01(x0 + 1, 0, z0 + 1, salt) * 2 - 1;

    return _lerp(_lerp(a, b, tx), _lerp(c, d, tx), tz);
  }

  int _hash(int x, int y, int z, int salt) {
    var value = seed ^ salt;
    value = (value ^ (x * 0x45d9f3b)) & 0x7fffffff;
    value = (value ^ (y * 0x119de1f3)) & 0x7fffffff;
    value = (value ^ (z * 0x3449f5d)) & 0x7fffffff;
    value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff;
    value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff;
    return value ^ (value >> 16);
  }

  double _hash01(int x, int y, int z, int salt) =>
      (_hash(x, y, z, salt) & 0x7fffffff) / 0x7fffffff;

  static double _smooth(double value) => value * value * (3 - 2 * value);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static int _snapHorizontal(double value) =>
      (value / _blockSize).floor() * _blockSize + _half;

  static int _snapVertical(int value) =>
      (value / _blockSize).round() * _blockSize;
}

class _ColumnInfo {
  final int surfaceY;
  final BiomeType biome;

  const _ColumnInfo({required this.surfaceY, required this.biome});
}
