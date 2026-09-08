import 'dart:math' as math;

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

/// 跨 ScenePainter 实例复用与相机无关的暴露面网格。
///
/// 相机移动时方块集合通常不变；此时只重新执行背面判断，不重复构建二维
/// mask 和 greedy mesh。签名包含位置、类型和红石功率，世界发生变化时
/// 会自动失效。
class FaceMeshCache {
  int? _geometrySignature;
  List<MergedFace> _exposedFaces = const [];

  List<MergedFace> resolve(List<Block> blocks) {
    final signature = Object.hashAll([
      blocks.length,
      for (final block in blocks)
        Object.hash(block.position, block.type, block.powerLevel),
    ]);
    if (_geometrySignature != signature) {
      _geometrySignature = signature;
      _exposedFaces = FaceMerger.mergeExposedFaces(blocks);
    }
    return _exposedFaces;
  }

  void clear() {
    _geometrySignature = null;
    _exposedFaces = const [];
  }
}

typedef _SplitPlane = ({int axis, int coordinate});

/// 轴对齐方块面的 BSP 排序器。
///
/// 仅按面中心排序无法处理“一个地面同时跨越墙体前后两侧”的情况。BSP
/// 会使用已有面的平面递归划分场景，并在必要时把跨平面的矩形切开，从而
/// 为没有 Z-buffer 的 Canvas 生成稳定的从远到近绘制顺序。
class FaceDepthSorter {
  const FaceDepthSorter._();

  static List<MergedFace> sort(
    List<MergedFace> faces,
    Vector3 cameraPosition,
    Vector3 viewDirection,
  ) {
    return _sortRecursive(faces, cameraPosition, viewDirection, 0);
  }

  static List<MergedFace> _sortRecursive(
    List<MergedFace> faces,
    Vector3 cameraPosition,
    Vector3 viewDirection,
    int depth,
  ) {
    if (faces.length <= 1) return faces;
    if (depth >= 64) {
      return faces..sort((a, b) {
        final depthA = (a.bounds.center.toVector3() - cameraPosition).dot(
          viewDirection,
        );
        final depthB = (b.bounds.center.toVector3() - cameraPosition).dot(
          viewDirection,
        );
        return depthB.compareTo(depthA);
      });
    }

    final plane = _choosePlane(faces);
    final negative = <MergedFace>[];
    final coplanar = <MergedFace>[];
    final positive = <MergedFace>[];

    for (final face in faces) {
      _partitionFace(face, plane, negative, coplanar, positive);
    }

    final cameraCoordinate = _component(cameraPosition, plane.axis);
    final negativeSorted = _sortRecursive(
      negative,
      cameraPosition,
      viewDirection,
      depth + 1,
    );
    final positiveSorted = _sortRecursive(
      positive,
      cameraPosition,
      viewDirection,
      depth + 1,
    );

    // 相机位于正侧时先画负侧；位于负侧时先画正侧。
    return cameraCoordinate >= plane.coordinate
        ? [...negativeSorted, ...coplanar, ...positiveSorted]
        : [...positiveSorted, ...coplanar, ...negativeSorted];
  }

  static _SplitPlane _choosePlane(List<MergedFace> faces) {
    final candidates = <_SplitPlane>[];
    final seen = <_SplitPlane>{};
    final stride = math.max(1, faces.length ~/ 12);

    for (var i = 0; i < faces.length && candidates.length < 12; i += stride) {
      final face = faces[i];
      final plane = _facePlane(face);
      if (seen.add(plane)) candidates.add(plane);
    }
    if (candidates.isEmpty) return _facePlane(faces.first);

    var best = candidates.first;
    var bestScore = 1 << 30;
    for (final candidate in candidates) {
      var negative = 0;
      var positive = 0;
      var spanning = 0;
      for (final face in faces) {
        final min = _component(face.minBounds, candidate.axis);
        final max = _component(face.maxBounds, candidate.axis);
        final parallel = _normalComponent(face.normal, candidate.axis) != 0;
        if (parallel && min == candidate.coordinate) continue;
        if (max <= candidate.coordinate) {
          negative++;
        } else if (min >= candidate.coordinate) {
          positive++;
        } else {
          spanning++;
        }
      }

      final score = (negative - positive).abs() + spanning * 2;
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  static void _partitionFace(
    MergedFace face,
    _SplitPlane plane,
    List<MergedFace> negative,
    List<MergedFace> coplanar,
    List<MergedFace> positive,
  ) {
    final min = _component(face.minBounds, plane.axis);
    final max = _component(face.maxBounds, plane.axis);
    final parallel = _normalComponent(face.normal, plane.axis) != 0;

    if (parallel && min == plane.coordinate) {
      coplanar.add(face);
    } else if (max <= plane.coordinate) {
      negative.add(face);
    } else if (min >= plane.coordinate) {
      positive.add(face);
    } else {
      final (negativePart, positivePart) = _splitFace(
        face,
        plane.axis,
        plane.coordinate,
      );
      negative.add(negativePart);
      positive.add(positivePart);
    }
  }

  static (MergedFace, MergedFace) _splitFace(
    MergedFace face,
    int axis,
    int coordinate,
  ) {
    Vector3Int negativeMax;
    Vector3Int positiveMin;
    switch (axis) {
      case 0:
        negativeMax = face.maxBounds.appointX(coordinate);
        positiveMin = face.minBounds.appointX(coordinate);
      case 1:
        negativeMax = face.maxBounds.appointY(coordinate);
        positiveMin = face.minBounds.appointY(coordinate);
      default:
        negativeMax = face.maxBounds.appointZ(coordinate);
        positiveMin = face.minBounds.appointZ(coordinate);
    }

    MergedFace create(Vector3Int min, Vector3Int max) => MergedFace(
      blockType: face.blockType,
      powerLevel: face.powerLevel,
      normal: face.normal,
      minBounds: min,
      maxBounds: max,
    );

    return (
      create(face.minBounds, negativeMax),
      create(positiveMin, face.maxBounds),
    );
  }

  static _SplitPlane _facePlane(MergedFace face) {
    if (face.normal.x != 0) {
      return (axis: 0, coordinate: face.minBounds.x);
    }
    if (face.normal.y != 0) {
      return (axis: 1, coordinate: face.minBounds.y);
    }
    return (axis: 2, coordinate: face.minBounds.z);
  }

  static int _normalComponent(Vector3Int value, int axis) => switch (axis) {
    0 => value.x,
    1 => value.y,
    _ => value.z,
  };

  static num _component(Object value, int axis) => switch (value) {
    Vector3Int v => switch (axis) {
      0 => v.x,
      1 => v.y,
      _ => v.z,
    },
    Vector3 v => switch (axis) {
      0 => v.x,
      1 => v.y,
      _ => v.z,
    },
    _ => throw ArgumentError.value(value, 'value'),
  };
}

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
  ) => filterVisibleFaces(mergeExposedFaces(blocks), cameraPosition);

  static List<MergedFace> filterVisibleFaces(
    Iterable<MergedFace> faces,
    Vector3 cameraPosition,
  ) {
    return faces.where((face) {
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
