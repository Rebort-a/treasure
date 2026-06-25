import '../00.common/game/gamer.dart';

enum AnimalType { elephant, tiger, lion, leopard, wolf, dog, cat, mouse }

enum CellType { land, river, road, bridge, tree }

enum CellState { normal, highlight, selected }

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

/// 只读动物接口 — 隐藏 isHidden 的写入
abstract interface class AnimalView {
  AnimalType get type;
  TurnGamerType get owner;
  bool get isHidden;
  bool canEat(Animal? other);
  bool canMoveTo(CellType from, CellType target);
}

class Animal implements AnimalView {
  @override
  final AnimalType type;
  @override
  final TurnGamerType owner;
  @override
  bool isHidden;

  Animal({required this.type, required this.owner, this.isHidden = true});

  @override
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

  @override
  bool canMoveTo(CellType from, CellType target) {
    return switch (target) {
      CellType.river => _canEnterRiver(),
      CellType.bridge => _canUseBridge(from),
      CellType.tree => _canClimbTree(),
      _ => true,
    };
  }

  bool _canEnterRiver() =>
      [AnimalType.elephant, AnimalType.dog, AnimalType.mouse].contains(type);
  bool _canUseBridge(CellType from) => from == CellType.river
      ? type == AnimalType.mouse
      : type != AnimalType.elephant;
  bool _canClimbTree() =>
      [AnimalType.leopard, AnimalType.cat, AnimalType.mouse].contains(type);

  Animal clone() => Animal(type: type, owner: owner, isHidden: isHidden);
}

/// 只读格子接口 — 隐藏 animal / state 的写入
abstract interface class CellView {
  int get coordinate;
  CellType get type;
  AnimalView? get animal;
  bool get hasAnimal;
}

class Cell implements CellView {
  @override
  final int coordinate;
  @override
  final CellType type;
  @override
  Animal? animal;
  late CellState _state;

  Cell({required this.coordinate, required this.type, this.animal}) {
    _state = CellState.normal;
  }

  @override
  bool get hasAnimal => animal != null;
  bool get isHightlight => _state == CellState.highlight;
  bool get isSelected => _state == CellState.selected;

  void setHighlight() {
    _state = CellState.highlight;
  }

  void setNormal() {
    _state = CellState.normal;
  }

  void setSelected() {
    if (hasAnimal && !animal!.isHidden) {
      _state = CellState.selected;
    }
  }

  Cell clone() {
    return Cell(coordinate: coordinate, type: type, animal: animal?.clone());
  }
}

sealed class GameAction {
  final int index;
  const GameAction(this.index);

  /// 对称变换：将动作坐标按给定变换函数和棋盘尺寸映射
  GameAction transform(int Function(int, int) t, int size);
}

class FlipAction extends GameAction {
  const FlipAction(super.index);

  @override
  FlipAction transform(int Function(int, int) t, int size) =>
      FlipAction(t(index, size));

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
  MoveAction transform(int Function(int, int) t, int size) =>
      MoveAction(t(from, size), t(to, size));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveAction && from == other.from && to == other.to;

  @override
  int get hashCode => Object.hash(from, to);
}
