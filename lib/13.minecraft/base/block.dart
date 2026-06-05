import 'dart:ui';
import 'collider.dart';
import 'constant.dart';
import 'face.dart';
import 'vector.dart';

/// 方块类型
enum BlockType {
  // 基础地形方块
  bedrock, // 基岩
  stone, // 石头
  dirt, // 泥土
  grass, // 草方块
  sand, // 沙子
  snow, // 雪
  ice, // 冰
  // 矿石
  coalOre, // 煤矿石
  ironOre, // 铁矿石
  goldOre, // 金矿石
  diamondOre, // 钻石矿石
  emeraldOre, // 绿宝石矿石
  // 植物相关
  wood, // 树干
  leaf, // 树叶
  sapling, // 树苗
  cactus, // 仙人掌
  // 液体
  water, // 水
  lava, // 岩浆
  // 人造方块
  glass, // 玻璃
  planks, // 木板
  brick, // 砖块
  // 特殊类型
  air, // 空气
}

extension BlockTypeProperties on BlockType {
  Color get color => {
    BlockType.bedrock: const Color(0xFF424242),
    BlockType.stone: const Color(0xFF9E9E9E),
    BlockType.dirt: const Color(0xFF8D6E63),
    BlockType.grass: const Color(0xFF4CAF50),
    BlockType.sand: const Color(0xFFFFF3E0),
    BlockType.snow: const Color(0xFFFFFFFF),
    BlockType.ice: const Color(0xAAE0F7FA),
    BlockType.coalOre: const Color(0xFF212121),
    BlockType.ironOre: const Color(0xFFB0BEC5),
    BlockType.goldOre: const Color(0xFFFFD700),
    BlockType.diamondOre: const Color(0xFF00BCD4),
    BlockType.emeraldOre: const Color(0xFF00E676),
    BlockType.wood: const Color(0xFF795548),
    BlockType.leaf: const Color(0xCC4CAF50),
    BlockType.sapling: const Color(0xFF795548),
    BlockType.cactus: const Color(0xFF4CAF50),
    BlockType.water: const Color(0x882196F3),
    BlockType.lava: const Color(0xFFFF5722),
    BlockType.glass: const Color(0xCCFFFFFF),
    BlockType.planks: const Color(0xFF8D6E63),
    BlockType.brick: const Color(0xFFB71C1C),
    BlockType.air: const Color(0x00000000),
  }[this]!;

  bool get isPenetrate =>
      [BlockType.air, BlockType.water, BlockType.leaf].contains(this);

  bool get isTransparent => [
    BlockType.leaf,
    BlockType.water,
    BlockType.glass,
    BlockType.ice,
    BlockType.air,
  ].contains(this);

  bool get isLiquid => [BlockType.water, BlockType.lava].contains(this);

  bool get isOre => [
    BlockType.coalOre,
    BlockType.ironOre,
    BlockType.goldOre,
    BlockType.diamondOre,
    BlockType.emeraldOre,
  ].contains(this);
}

/// 方块面数据
class BlockFace {
  final BlockType type;
  final Vector3Int center;
  final Vector3Int normal;
  final List<Vector3Int> vertices;

  const BlockFace({
    required this.type,
    required this.center,
    required this.normal,
    required this.vertices,
  });
}

/// 方块
class Block {
  final Vector3Int position;
  final BlockType type;
  final FixedBoxCollider collider;
  final List<Vector3Int> _vertices;
  late final List<BlockFace> _faces;

  Vector3? _lastCameraPosition;
  List<BlockFace>? _cachedVisibleFaces;

  Block({required this.position, required this.type})
    : collider = FixedBoxCollider(
        position: position,
        halfSize: Vector3Int.all(Constants.blockSizeHalf),
      ),
      _vertices = _getVertices(position) {
    _faces = _getFaces(position, type, _vertices);
  }

  static List<Vector3Int> _getVertices(Vector3Int position) {
    final half = Constants.blockSizeHalf;
    final p = position;
    return [
      Vector3Int(p.x - half, p.y - half, p.z - half),
      Vector3Int(p.x + half, p.y - half, p.z - half),
      Vector3Int(p.x + half, p.y + half, p.z - half),
      Vector3Int(p.x - half, p.y + half, p.z - half),
      Vector3Int(p.x - half, p.y - half, p.z + half),
      Vector3Int(p.x + half, p.y - half, p.z + half),
      Vector3Int(p.x + half, p.y + half, p.z + half),
      Vector3Int(p.x - half, p.y + half, p.z + half),
    ];
  }

  // 初始化方块的所有面（计算每个面的中心点）
  static List<BlockFace> _getFaces(
    Vector3Int position,
    BlockType type,
    List<Vector3Int> vertices,
  ) {
    final halfSize = Constants.blockSizeHalf;

    return FaceIdentify.hexahedron.map((face) {
      final faceCenter = position + face.normal * halfSize;
      final faceVertices = face.indices
          .map((index) => vertices[index])
          .toList();

      return BlockFace(
        type: type,
        center: faceCenter,
        normal: face.normal,
        vertices: faceVertices,
      );
    }).toList();
  }

  /// 获取可见的面（剔除背向相机的面）
  List<BlockFace> getVisibleFaces(Vector3 cameraPosition) {
    if (_lastCameraPosition == cameraPosition && _cachedVisibleFaces != null) {
      return _cachedVisibleFaces!;
    }

    _lastCameraPosition = cameraPosition;

    // 透明方块不进行背面剔除，返回所有面
    if (type.isTransparent) {
      _cachedVisibleFaces = _faces;
    } else {
      _cachedVisibleFaces = _faces.where((face) {
        // 使用预计算的面中心点和法向量进行可见性判断
        final toCamera = (cameraPosition - face.center.toVector3()).normalized;
        return face.normal.dotWithVector3(toCamera) > 0; // 面朝向相机则可见
      }).toList();
    }

    return _cachedVisibleFaces!;
  }

  List<Vector3Int> get vertices => _vertices;
  List<BlockFace> get faces => _faces;
}
