import 'constant.dart';
import 'vector.dart';

/// 体素世界坐标转换。
///
/// 本项目使用边长为 2 的方块：X/Z 中心位于奇数坐标，Y 中心位于偶数坐标。
/// 所有网格、区块和区块组换算集中在这里，避免负坐标和奇偶规则不一致。
class VoxelCoordinates {
  const VoxelCoordinates._();

  static int floorDiv(int value, int divisor) => (value / divisor).floor();

  static int floorMod(int value, int divisor) {
    final result = value % divisor;
    return result < 0 ? result + divisor : result;
  }

  static int snapHorizontal(double value) =>
      (value / Constants.blockSize).floor() * Constants.blockSize +
      Constants.blockSizeHalf;

  static int snapVertical(double value) =>
      (value / Constants.blockSize).floor() * Constants.blockSize;

  static Vector3Int snapBlockCenter(Vector3 value) => Vector3Int(
    snapHorizontal(value.x),
    snapVertical(value.y),
    snapHorizontal(value.z),
  );

  static Vector3Int worldToChunk(Vector3 value, int chunkSize) => Vector3Int(
    (value.x / chunkSize).floor(),
    (value.y / chunkSize).floor(),
    (value.z / chunkSize).floor(),
  );

  static Vector3Int chunkToGroup(Vector3Int chunk, int groupSize) => Vector3Int(
    floorDiv(chunk.x, groupSize),
    floorDiv(chunk.y, groupSize),
    floorDiv(chunk.z, groupSize),
  );

  static Vector3Int chunkOffsetInGroup(Vector3Int chunk, int groupSize) =>
      Vector3Int(
        floorMod(chunk.x, groupSize),
        floorMod(chunk.y, groupSize),
        floorMod(chunk.z, groupSize),
      );
}
