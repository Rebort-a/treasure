import '../base/aabb.dart';
import '../base/block.dart';
import '../base/constant.dart';
import '../base/vector.dart';

typedef MergedFaceGridLine = ({Vector3Int start, Vector3Int end});

/// 合并后的矩形面。
class MergedFace {
  final BlockType blockType;
  final int powerLevel;
  final Vector3Int normal;
  final Vector3Int minBounds;
  final Vector3Int maxBounds;
  final List<Vector3Int> vertices;

  MergedFace({
    required this.blockType,
    required this.powerLevel,
    required this.normal,
    required this.minBounds,
    required this.maxBounds,
  }) : vertices = _computeFaceVertices(minBounds, maxBounds, normal);

  static List<Vector3Int> _computeFaceVertices(
    Vector3Int min,
    Vector3Int max,
    Vector3Int normal,
  ) {
    if (normal.x != 0) {
      final x = normal.x > 0 ? max.x : min.x;
      return [
        Vector3Int(x, min.y, min.z),
        Vector3Int(x, max.y, min.z),
        Vector3Int(x, max.y, max.z),
        Vector3Int(x, min.y, max.z),
      ];
    }
    if (normal.y != 0) {
      final y = normal.y > 0 ? max.y : min.y;
      return [
        Vector3Int(min.x, y, min.z),
        Vector3Int(max.x, y, min.z),
        Vector3Int(max.x, y, max.z),
        Vector3Int(min.x, y, max.z),
      ];
    }
    final z = normal.z > 0 ? max.z : min.z;
    return [
      Vector3Int(min.x, min.y, z),
      Vector3Int(max.x, min.y, z),
      Vector3Int(max.x, max.y, z),
      Vector3Int(min.x, max.y, z),
    ];
  }

  AABBInt get bounds => AABBInt(minBounds, maxBounds);

  Iterable<MergedFaceGridLine> get gridLines sync* {
    final step = Constants.blockSize;

    if (normal.x != 0) {
      final x = normal.x > 0 ? maxBounds.x : minBounds.x;
      for (var y = minBounds.y + step; y < maxBounds.y; y += step) {
        yield (
          start: Vector3Int(x, y, minBounds.z),
          end: Vector3Int(x, y, maxBounds.z),
        );
      }
      for (var z = minBounds.z + step; z < maxBounds.z; z += step) {
        yield (
          start: Vector3Int(x, minBounds.y, z),
          end: Vector3Int(x, maxBounds.y, z),
        );
      }
      return;
    }

    if (normal.y != 0) {
      final y = normal.y > 0 ? maxBounds.y : minBounds.y;
      for (var x = minBounds.x + step; x < maxBounds.x; x += step) {
        yield (
          start: Vector3Int(x, y, minBounds.z),
          end: Vector3Int(x, y, maxBounds.z),
        );
      }
      for (var z = minBounds.z + step; z < maxBounds.z; z += step) {
        yield (
          start: Vector3Int(minBounds.x, y, z),
          end: Vector3Int(maxBounds.x, y, z),
        );
      }
      return;
    }

    final z = normal.z > 0 ? maxBounds.z : minBounds.z;
    for (var x = minBounds.x + step; x < maxBounds.x; x += step) {
      yield (
        start: Vector3Int(x, minBounds.y, z),
        end: Vector3Int(x, maxBounds.y, z),
      );
    }
    for (var y = minBounds.y + step; y < maxBounds.y; y += step) {
      yield (
        start: Vector3Int(minBounds.x, y, z),
        end: Vector3Int(maxBounds.x, y, z),
      );
    }
  }
}

typedef _Cell = (int, int);
typedef _FaceKey = (BlockType, int, Vector3Int, int);

/// 二维掩码式 greedy meshing。
///
/// 先移除相邻方块之间的内部面，再在同一平面上按材质、视觉状态和
/// 法线寻找最大矩形，不会把 L 形区域或孔洞错误填成完整矩形。
class FaceMerger {
  const FaceMerger._();

  static const _normals = [
    Vector3Int(1, 0, 0),
    Vector3Int(-1, 0, 0),
    Vector3Int(0, 1, 0),
    Vector3Int(0, -1, 0),
    Vector3Int(0, 0, 1),
    Vector3Int(0, 0, -1),
  ];

  static List<MergedFace> mergeVisibleFaces(
    List<Block> blocks,
    Vector3 cameraPosition,
  ) {
    return mergeExposedFaces(blocks).where((face) {
      final toCamera = cameraPosition - face.bounds.center.toVector3();
      return face.normal.dotWithVector3(toCamera) > 0;
    }).toList();
  }

  /// 生成与相机无关的暴露面网格，可在方块集合不变时跨帧复用。
  static List<MergedFace> mergeExposedFaces(List<Block> blocks) {
    if (blocks.isEmpty) return const [];

    final blockByPosition = {for (final block in blocks) block.position: block};
    final masks = <_FaceKey, Set<_Cell>>{};

    for (final block in blocks) {
      for (final normal in _normals) {
        final neighbor =
            blockByPosition[block.position + normal * Constants.blockSize];
        if (!_isFaceExposed(block, neighbor)) continue;

        final faceCenter = block.position + normal * Constants.blockSizeHalf;
        final key = (
          block.type,
          block.powerLevel,
          normal,
          _planeCoordinate(faceCenter, normal),
        );
        masks
            .putIfAbsent(key, () => <_Cell>{})
            .add(_cellCoordinates(block.position, normal));
      }
    }

    final result = <MergedFace>[];
    for (final entry in masks.entries) {
      result.addAll(_mergeMask(entry.key, entry.value));
    }
    return result;
  }

  static bool _isFaceExposed(Block block, Block? neighbor) {
    if (neighbor == null || neighbor.type == BlockType.air) return true;
    if (neighbor.type == block.type && block.type.isTransparent) return false;
    return neighbor.type.isTransparent;
  }

  static List<MergedFace> _mergeMask(_FaceKey key, Set<_Cell> source) {
    final remaining = {...source};
    final sorted = remaining.toList()
      ..sort((a, b) {
        final byV = a.$2.compareTo(b.$2);
        return byV != 0 ? byV : a.$1.compareTo(b.$1);
      });
    final result = <MergedFace>[];
    final step = Constants.blockSize;

    for (final start in sorted) {
      if (!remaining.contains(start)) continue;

      var width = 1;
      while (width < Constants.maxMergedFaceBlocks &&
          remaining.contains((start.$1 + width * step, start.$2))) {
        width++;
      }

      var height = 1;
      while (height < Constants.maxMergedFaceBlocks) {
        final nextV = start.$2 + height * step;
        var completeRow = true;
        for (var x = 0; x < width; x++) {
          if (!remaining.contains((start.$1 + x * step, nextV))) {
            completeRow = false;
            break;
          }
        }
        if (!completeRow) break;
        height++;
      }

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          remaining.remove((start.$1 + x * step, start.$2 + y * step));
        }
      }

      result.add(
        _createMergedFace(
          key,
          minU: start.$1 - Constants.blockSizeHalf,
          minV: start.$2 - Constants.blockSizeHalf,
          maxU: start.$1 + (width - 1) * step + Constants.blockSizeHalf,
          maxV: start.$2 + (height - 1) * step + Constants.blockSizeHalf,
        ),
      );
    }
    return result;
  }

  static MergedFace _createMergedFace(
    _FaceKey key, {
    required int minU,
    required int minV,
    required int maxU,
    required int maxV,
  }) {
    final (type, powerLevel, normal, plane) = key;
    late final Vector3Int minBounds;
    late final Vector3Int maxBounds;

    if (normal.x != 0) {
      minBounds = Vector3Int(plane, minU, minV);
      maxBounds = Vector3Int(plane, maxU, maxV);
    } else if (normal.y != 0) {
      minBounds = Vector3Int(minU, plane, minV);
      maxBounds = Vector3Int(maxU, plane, maxV);
    } else {
      minBounds = Vector3Int(minU, minV, plane);
      maxBounds = Vector3Int(maxU, maxV, plane);
    }

    return MergedFace(
      blockType: type,
      powerLevel: powerLevel,
      normal: normal,
      minBounds: minBounds,
      maxBounds: maxBounds,
    );
  }

  static _Cell _cellCoordinates(Vector3Int position, Vector3Int normal) {
    if (normal.x != 0) return (position.y, position.z);
    if (normal.y != 0) return (position.x, position.z);
    return (position.x, position.y);
  }

  static int _planeCoordinate(Vector3Int point, Vector3Int normal) {
    if (normal.x != 0) return point.x;
    if (normal.y != 0) return point.y;
    return point.z;
  }
}
