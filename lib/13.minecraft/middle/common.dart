import '../base/block.dart';
import '../base/vector.dart';

/// 渲染调试配置。放在 middle 层，避免游戏管理层反向依赖 UI/渲染层。
class RenderDebugConfig {
  bool enableNearClip = true;
  bool enableBackfaceCulling = true;
  bool enableDepthSorting = true;
  bool enableScreenClipping = true;
  bool enableFrustumCulling = true;

  /// 当前射线式遮挡剔除成本较高，默认关闭；可在调试面板中按需比较。
  bool enableOcclusionCulling = false;

  bool enableFaceMerging = true;
  bool showBlockOutline = false;
  bool showDebugInfo = false;
  bool showFaceNormals = false;
  bool showVertexPositions = false;
  bool showFrustum = false;

  int get signature => Object.hashAll([
    enableNearClip,
    enableBackfaceCulling,
    enableDepthSorting,
    enableScreenClipping,
    enableFrustumCulling,
    enableOcclusionCulling,
    enableFaceMerging,
    showBlockOutline,
    showDebugInfo,
    showFaceNormals,
    showVertexPositions,
    showFrustum,
  ]);
}

class SceneInfo {
  final Vector3 position;
  final Vector3 orientation;
  final List<Block> blocks;
  final Block? targetedBlock;
  final Vector3Int? targetedFaceNormal;
  final int revision;

  const SceneInfo({
    required this.position,
    required this.orientation,
    required this.blocks,
    this.targetedBlock,
    this.targetedFaceNormal,
    this.revision = 0,
  });
}
