import '../image/entity.dart';

enum Direction { down, left, up, right }

const List<(int, int)> planeAround = [(-1, 0), (1, 0), (0, -1), (0, 1)];

const List<(int, int)> planeConnection = [(1, 0), (0, 1), (1, 1), (-1, 1)];

// 可移动的实体
mixin MovableEntity {
  late final EntityType id;
  late int y, x;

  void updatePosition(int newY, int newX) {
    y = newY;
    x = newX;
  }
}
