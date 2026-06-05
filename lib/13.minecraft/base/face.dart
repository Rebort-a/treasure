import 'vector.dart';

// 面标识
class FaceIdentify {
  final List<int> indices;
  final Vector3Int normal;

  const FaceIdentify(this.indices, this.normal);

  // 六面体模板
  static const List<FaceIdentify> hexahedron = [
    FaceIdentify([0, 1, 2, 3], Vector3Int.back), // 前
    FaceIdentify([7, 6, 5, 4], Vector3Int.forward), // 后
    FaceIdentify([1, 5, 6, 2], Vector3Int.right), // 右
    FaceIdentify([4, 0, 3, 7], Vector3Int.left), // 左
    FaceIdentify([3, 2, 6, 7], Vector3Int.up), // 上
    FaceIdentify([0, 4, 5, 1], Vector3Int.down), // 下
  ];
}
