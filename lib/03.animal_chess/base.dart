import '../00.common/game/gamer.dart';

enum AnimalType { elephant, tiger, lion, leopard, wolf, dog, cat, mouse }

enum GridType { land, river, road, bridge, tree }

const List<String> animalEmojis = [
  "🐘",
  "🐅",
  "🦁",
  "🐆",
  "🐺",
  "🐕",
  "🐈️",
  "🐭",
];

class Animal {
  final AnimalType type;
  final TurnGamerType owner;
  bool isSelected;
  bool isHidden;

  Animal({
    required this.type,
    required this.owner,
    this.isSelected = false,
    this.isHidden = true,
  });

  bool canEat(Animal? other) {
    if (other == null) return true;
    if (type == other.type) return true;

    // 特殊规则：老鼠吃大象
    if (type == AnimalType.mouse && other.type == AnimalType.elephant) {
      return true;
    } else if (type == AnimalType.elephant && other.type == AnimalType.mouse) {
      return false;
    }

    return type.index < other.type.index;
  }

  bool _canEnterRiver() =>
      [AnimalType.elephant, AnimalType.dog, AnimalType.mouse].contains(type);
  bool _canUseBridge(GridType from) =>
      (from != GridType.river || type == AnimalType.mouse) &&
      type != AnimalType.elephant;
  bool _canClimbTree() =>
      [AnimalType.leopard, AnimalType.cat, AnimalType.mouse].contains(type);

  bool canMoveTo(GridType from, GridType target) {
    return switch (target) {
      GridType.river => _canEnterRiver(),
      GridType.bridge => _canUseBridge(from),
      GridType.tree => _canClimbTree(),
      _ => true,
    };
  }
}

class Grid {
  final int coordinate;
  final GridType type;
  bool isHighlighted;
  Animal? animal;

  Grid({
    required this.coordinate,
    required this.type,
    this.isHighlighted = false,
    this.animal,
  });

  bool get hasAnimal => animal != null;
}
