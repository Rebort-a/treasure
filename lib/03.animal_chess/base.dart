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

  Animal clone() => Animal(
    type: type,
    owner: owner,
    isSelected: isSelected,
    isHidden: isHidden,
  );
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

  Grid clone() {
    return Grid(
      coordinate: coordinate,
      type: type,
      isHighlighted: isHighlighted,
      animal: animal?.clone(),
    );
  }
}

sealed class GameAction {
  final int index;
  const GameAction(this.index);
}

class FlipAction extends GameAction {
  const FlipAction(super.index);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FlipAction && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

class MoveAction extends GameAction {
  final int from;
  final int to;
  const MoveAction(this.from, this.to) : super(from);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveAction && from == other.from && to == other.to;

  @override
  int get hashCode => Object.hash(from, to);
}
