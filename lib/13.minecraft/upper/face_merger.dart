import 'dart:collection';
import 'dart:math' as math;
import '../base/aabb.dart';
import '../base/block.dart';
import '../base/constant.dart';
import '../base/vector.dart';

/// 2D矩形表示
class _FaceRectangle {
  final int minU, minV, maxU, maxV;
  const _FaceRectangle(this.minU, this.minV, this.maxU, this.maxV);
}

/// 合并后的面数据
class MergedFace {
  final BlockType blockType;
  final Vector3Int normal;
  final Vector3Int minBounds;
  final Vector3Int maxBounds;
  final List<Vector3Int> vertices;

  MergedFace({
    required this.blockType,
    required this.normal,
    required this.minBounds,
    required this.maxBounds,
  }) : vertices = _computeFaceVertices(minBounds, maxBounds, normal);

  static List<Vector3Int> _computeFaceVertices(
    Vector3Int min,
    Vector3Int max,
    Vector3Int normal,
  ) {
    if (normal.x.abs() > 0.5) {
      final x = normal.x > 0 ? max.x : min.x;
      return [
        Vector3Int(x, min.y, min.z),
        Vector3Int(x, max.y, min.z),
        Vector3Int(x, max.y, max.z),
        Vector3Int(x, min.y, max.z),
      ];
    } else if (normal.y.abs() > 0.5) {
      final y = normal.y > 0 ? max.y : min.y;
      return [
        Vector3Int(min.x, y, min.z),
        Vector3Int(max.x, y, min.z),
        Vector3Int(max.x, y, max.z),
        Vector3Int(min.x, y, max.z),
      ];
    } else {
      final z = normal.z > 0 ? max.z : min.z;
      return [
        Vector3Int(min.x, min.y, z),
        Vector3Int(max.x, min.y, z),
        Vector3Int(max.x, max.y, z),
        Vector3Int(min.x, max.y, z),
      ];
    }
  }

  AABBInt get bounds => AABBInt(minBounds, maxBounds);
}

/// 面合并器
class FaceMerger {
  /// 合并可见面
  static List<MergedFace> mergeVisibleFaces(
    List<Block> blocks,
    Vector3 cameraPosition,
  ) {
    final faceGroups = _groupFacesByTypeAndNormal(blocks, cameraPosition);
    final mergedFaces = <MergedFace>[];

    for (final group in faceGroups.values) {
      if (group.isEmpty) continue;
      final normal = group.first.normal;
      final blockType = group.first.type;
      final merged = _mergeFaceGroup(group, normal, blockType, blocks);
      mergedFaces.addAll(merged);
    }

    return mergedFaces;
  }

  /// 按类型和法线分组面
  static Map<String, List<BlockFace>> _groupFacesByTypeAndNormal(
    List<Block> blocks,
    Vector3 cameraPosition,
  ) {
    final groups = <String, List<BlockFace>>{};

    for (final block in blocks) {
      for (final face in block.getVisibleFaces(cameraPosition)) {
        final chunkX = (block.position.x ~/ 4); // 每4个单位一个区块
        final chunkZ = (block.position.z ~/ 4);
        final key =
            '${face.normal.x},${face.normal.y},${face.normal.z},'
            '${face.type.index},$chunkX,$chunkZ';

        groups.putIfAbsent(key, () => []).add(face);
      }
    }
    return groups;
  }

  /// 合并面组
  static List<MergedFace> _mergeFaceGroup(
    List<BlockFace> faces,
    Vector3Int normal,
    BlockType blockType,
    List<Block> allBlocks,
  ) {
    final mergedFaces = <MergedFace>[];
    final processedFaces = <BlockFace>{};

    for (final face in faces) {
      if (processedFaces.contains(face)) continue;

      final mergeGroup = _findAdjacentFaces(face, faces, normal, allBlocks);
      processedFaces.addAll(mergeGroup);

      if (mergeGroup.length == 1) {
        // 单个面
        final bounds = _computeFaceBounds3D(mergeGroup.first, normal);
        mergedFaces.add(
          MergedFace(
            blockType: blockType,
            normal: normal,
            minBounds: bounds.$1,
            maxBounds: bounds.$2,
          ),
        );
      } else {
        // 合并面
        final merged = _mergeAdjacentFaces(mergeGroup, normal, blockType);
        if (merged != null) mergedFaces.add(merged);
      }
    }
    return mergedFaces;
  }

  /// 查找相邻面
  static List<BlockFace> _findAdjacentFaces(
    BlockFace startFace,
    List<BlockFace> allFaces,
    Vector3Int normal,
    List<Block> allBlocks,
  ) {
    final group = <BlockFace>[startFace];
    final queue = Queue<BlockFace>()..add(startFace);
    final visited = <BlockFace>{startFace};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final neighbor in allFaces) {
        if (!visited.contains(neighbor) &&
            _canMergeFaces(current, neighbor, normal, allBlocks)) {
          visited.add(neighbor);
          group.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    return group;
  }

  /// 判断两个面是否可以合并
  static bool _canMergeFaces(
    BlockFace face1,
    BlockFace face2,
    Vector3Int normal,
    List<Block> allBlocks,
  ) {
    return _areFacesCoplanar(face1, face2, normal) &&
        _areFacesAdjacent(face1, face2, normal) &&
        !_wouldMergeBeOccluded(face1, face2, normal, allBlocks);
  }

  static bool _areFacesCoplanar(
    BlockFace face1,
    BlockFace face2,
    Vector3Int normal,
  ) {
    final planePos1 = _getPlaneCoordinate(face1.center, normal);
    final planePos2 = _getPlaneCoordinate(face2.center, normal);
    return (planePos1 - planePos2).abs() == 0;
  }

  static bool _areFacesAdjacent(
    BlockFace face1,
    BlockFace face2,
    Vector3Int normal,
  ) {
    final rect1 = _computeFaceBounds2D(face1, normal);
    final rect2 = _computeFaceBounds2D(face2, normal);

    final uAdjacent =
        (rect1.maxU == rect2.minU || rect2.maxU == rect1.minU) &&
        (rect1.minV < rect2.maxV && rect1.maxV > rect2.minV);
    final vAdjacent =
        (rect1.maxV == rect2.minV || rect2.maxV == rect1.minV) &&
        (rect1.minU < rect2.maxU && rect1.maxU > rect2.minU);

    return uAdjacent || vAdjacent;
  }

  static bool _wouldMergeBeOccluded(
    BlockFace face1,
    BlockFace face2,
    Vector3Int normal,
    List<Block> allBlocks,
  ) {
    final bounds1 = _computeFaceBounds3D(face1, normal);
    final bounds2 = _computeFaceBounds3D(face2, normal);

    final mergedMin = Vector3Int(
      math.min(bounds1.$1.x, bounds2.$1.x),
      math.min(bounds1.$1.y, bounds2.$1.y),
      math.min(bounds1.$1.z, bounds2.$1.z),
    );
    final mergedMax = Vector3Int(
      math.max(bounds1.$2.x, bounds2.$2.x),
      math.max(bounds1.$2.y, bounds2.$2.y),
      math.max(bounds1.$2.z, bounds2.$2.z),
    );

    final mergedCenter = (mergedMin + mergedMax) ~/ 2;
    for (final block in allBlocks) {
      final blockPos = block.position;
      final blockMin = blockPos - Vector3Int.all(Constants.blockSizeHalf);
      final blockMax = blockPos + Vector3Int.all(Constants.blockSizeHalf);

      if (_isBehindPlane(blockPos, mergedCenter, normal) &&
          _aabbIntersects(blockMin, blockMax, mergedMin, mergedMax)) {
        return true;
      }
    }
    return false;
  }

  /// 合并相邻面
  static MergedFace? _mergeAdjacentFaces(
    List<BlockFace> faces,
    Vector3Int normal,
    BlockType blockType,
  ) {
    if (faces.isEmpty) return null;

    Vector3Int? minBounds, maxBounds;
    for (final face in faces) {
      final bounds = _computeFaceBounds3D(face, normal);
      minBounds ??= bounds.$1;
      maxBounds ??= bounds.$2;

      minBounds = Vector3Int(
        math.min(minBounds.x, bounds.$1.x),
        math.min(minBounds.y, bounds.$1.y),
        math.min(minBounds.z, bounds.$1.z),
      );
      maxBounds = Vector3Int(
        math.max(maxBounds.x, bounds.$2.x),
        math.max(maxBounds.y, bounds.$2.y),
        math.max(maxBounds.z, bounds.$2.z),
      );
    }

    return minBounds != null && maxBounds != null
        ? MergedFace(
            blockType: blockType,
            normal: normal,
            minBounds: minBounds,
            maxBounds: maxBounds,
          )
        : null;
  }

  // 辅助计算方法
  static _FaceRectangle _computeFaceBounds2D(
    BlockFace face,
    Vector3Int normal,
  ) {
    final vertices = face.vertices;
    if (normal.x.abs() > 0.5) {
      final yValues = vertices.map((v) => v.y);
      final zValues = vertices.map((v) => v.z);
      return _FaceRectangle(
        yValues.reduce(math.min),
        zValues.reduce(math.min),
        yValues.reduce(math.max),
        zValues.reduce(math.max),
      );
    } else if (normal.y.abs() > 0.5) {
      final xValues = vertices.map((v) => v.x);
      final zValues = vertices.map((v) => v.z);
      return _FaceRectangle(
        xValues.reduce(math.min),
        zValues.reduce(math.min),
        xValues.reduce(math.max),
        zValues.reduce(math.max),
      );
    } else {
      final xValues = vertices.map((v) => v.x);
      final yValues = vertices.map((v) => v.y);
      return _FaceRectangle(
        xValues.reduce(math.min),
        yValues.reduce(math.min),
        xValues.reduce(math.max),
        yValues.reduce(math.max),
      );
    }
  }

  static (Vector3Int, Vector3Int) _computeFaceBounds3D(
    BlockFace face,
    Vector3Int normal,
  ) {
    final vertices = face.vertices;
    var minX = vertices[0].x, maxX = vertices[0].x;
    var minY = vertices[0].y, maxY = vertices[0].y;
    var minZ = vertices[0].z, maxZ = vertices[0].z;

    for (int i = 1; i < vertices.length; i++) {
      final v = vertices[i];
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
      if (v.z < minZ) minZ = v.z;
      if (v.z > maxZ) maxZ = v.z;
    }

    if (normal.x.abs() > 0.5) {
      final x = face.center.x;
      return (Vector3Int(x, minY, minZ), Vector3Int(x, maxY, maxZ));
    } else if (normal.y.abs() > 0.5) {
      final y = face.center.y;
      return (Vector3Int(minX, y, minZ), Vector3Int(maxX, y, maxZ));
    } else {
      final z = face.center.z;
      return (Vector3Int(minX, minY, z), Vector3Int(maxX, maxY, z));
    }
  }

  static bool _isBehindPlane(
    Vector3Int point,
    Vector3Int planePoint,
    Vector3Int normal,
  ) {
    return (point - planePoint).dot(normal) < 0;
  }

  static bool _aabbIntersects(
    Vector3Int min1,
    Vector3Int max1,
    Vector3Int min2,
    Vector3Int max2,
  ) {
    return min1.x <= max2.x &&
        max1.x >= min2.x &&
        min1.y <= max2.y &&
        max1.y >= min2.y &&
        min1.z <= max2.z &&
        max1.z >= min2.z;
  }

  static int _getPlaneCoordinate(Vector3Int point, Vector3Int normal) {
    return normal.x.abs() > 0
        ? point.x
        : normal.y.abs() > 0
        ? point.y
        : point.z;
  }
}
