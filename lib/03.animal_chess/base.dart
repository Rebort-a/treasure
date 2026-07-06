import '../00.common/game/gamer.dart';

enum CellType { land, river, road, bridge, tree }

enum AnimalType { elephant, tiger, lion, leopard, wolf, dog, cat, mouse }

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

enum CellState { normal, highlight, selected }

/// 吃子规则与地形通行
abstract final class Rules {
  /// attacker 能否吃 defender
  static bool canEat(AnimalType attacker, AnimalType defender) =>
      switch ((attacker, defender)) {
        (final a, final d) when a == d => true, // 同级互吃
        (AnimalType.mouse, AnimalType.elephant) => true, // 鼠吃象
        (AnimalType.elephant, AnimalType.mouse) => false, // 象不能吃鼠
        (final a, final d) => a.index < d.index, // 常规：序号小吃大
      };

  /// 可入河流的动物
  static const _riverAnimals = {
    AnimalType.elephant,
    AnimalType.dog,
    AnimalType.mouse,
  };

  /// 可攀树的动物
  static const _treeAnimals = {
    AnimalType.leopard,
    AnimalType.cat,
    AnimalType.mouse,
  };

  /// 能否从 from 地形进入 target 地形
  static bool canEnter(AnimalType type, CellType from, CellType target) =>
      switch (target) {
        CellType.river => _riverAnimals.contains(type),
        CellType.bridge =>
          from == CellType.river
              ? type == AnimalType.mouse
              : type != AnimalType.elephant,
        CellType.tree => _treeAnimals.contains(type),
        _ => true,
      };

  static bool canClimbTree(AnimalType type) => _treeAnimals.contains(type);
}

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
    return Rules.canEat(type, other.type);
  }

  @override
  bool canMoveTo(CellType from, CellType target) {
    return Rules.canEnter(type, from, target);
  }

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
