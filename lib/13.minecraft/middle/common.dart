import '../base/block.dart';
import '../base/vector.dart';

class SceneInfo {
  final Vector3 position;
  final Vector3 orientation;
  final List<Block> blocks;

  const SceneInfo({
    required this.position,
    required this.orientation,
    required this.blocks,
  });
}
