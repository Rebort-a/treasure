import '../base/block.dart';
import '../base/vector.dart';

class SceneInfo {
  final Vector3 position;
  final Vector3 orientation;
  final List<Block> blocks;
  final Block? targetedBlock;
  final Vector3Int? targetedFaceNormal;

  const SceneInfo({
    required this.position,
    required this.orientation,
    required this.blocks,
    this.targetedBlock,
    this.targetedFaceNormal,
  });
}
