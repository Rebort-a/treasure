import '../../00.common/game/map.dart';
import '../../00.common/image/entity.dart';
import '../../00.common/l10n/strings.dart';

import 'elemental.dart';
import 'prop.dart';

class NormalPlayer extends ElementalEntity {
  late final Map<EntityType, MapProp> props;
  late int money;
  late int experience;
  Direction lastDirection = Direction.down;
  int col = 0;
  int row = 0;

  NormalPlayer({required super.id, required super.y, required super.x})
    : super(
        baseName: S.traveler,
        configs: EnergyConfigs.defaultConfigs(skillPoints: 1),
        current: 2,
      ) {
    money = 20;
    experience = 60;
    props = PropCollection.totalItems;
  }

  void updateDirection(Direction direction) {
    if (direction == lastDirection) {
      row = (row + 1) % 4;
    } else {
      lastDirection = direction;
      row = 0;
      switch (direction) {
        case Direction.down:
          col = 0;
          break;
        case Direction.left:
          col = 4;
          break;
        case Direction.up:
          col = 8;
          break;
        case Direction.right:
          col = 12;
          break;
      }
    }
  }
}
