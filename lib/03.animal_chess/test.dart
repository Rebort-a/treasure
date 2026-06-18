import 'dart:math';
import 'package:flutter/foundation.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import 'base.dart';

// ============================================================
// 编码常量 — situation 中每个 int 的位布局
// ============================================================
// bit 0~2 : 地形  (GridType.index, 0~4)
// bit 3~4 : 占据状态 (0=空 1=暗棋 2=己方明棋 3=敌方明棋)
// bit 5~7 : 动物类型 (AnimalType.index, 仅明棋时有效)

const int _kTerrainBits = 0x07;
const int _kOccupyShift = 3;
const int _kOccupyMask = 0x03;
const int _kAnimalShift = 5;
const int _kAnimalMask = 0x07;

const int _kOccupyEmpty = 0;
const int _kOccupyHidden = 1;
const int _kOccupySelf = 2;
const int _kOccupyEnemy = 3;

// ============================================================
// 搜索常量 & 基础分
// ============================================================

const int _kSearchDepth = 4;
const int _kTotalScore = 16;
const double _kFlipThreshold = 0.5;
const int _kFlipEvalMoves = 6; // 翻牌评估时双方各考虑的走法上限

const Map<AnimalType, int> _baseScores = {
  AnimalType.elephant: 3,
  AnimalType.tiger: 1,
  AnimalType.lion: 2,
  AnimalType.leopard: 2,
  AnimalType.wolf: 1,
  AnimalType.dog: 2,
  AnimalType.cat: 1,
  AnimalType.mouse: 2,
};

const _kRiverAnimals = {AnimalType.elephant, AnimalType.dog, AnimalType.mouse};
const _kTreeAnimals = {AnimalType.leopard, AnimalType.cat, AnimalType.mouse};

// ============================================================
// 编码工具（顶层函数，供各处共用）
// ============================================================

bool _cellIsEmpty(int cell) =>
    cell == 0 || ((cell >> _kOccupyShift) & _kOccupyMask) == _kOccupyEmpty;
bool _cellIsHidden(int cell) =>
    ((cell >> _kOccupyShift) & _kOccupyMask) == _kOccupyHidden;
bool _cellIsSelf(int cell) =>
    ((cell >> _kOccupyShift) & _kOccupyMask) == _kOccupySelf;
bool _cellIsEnemy(int cell) =>
    ((cell >> _kOccupyShift) & _kOccupyMask) == _kOccupyEnemy;

AnimalType _cellAnimal(int cell) =>
    AnimalType.values[(cell >> _kAnimalShift) & _kAnimalMask];
GridType _cellTerrain(int cell) => GridType.values[cell & _kTerrainBits];

int _encodeCell(GridType terrain, int occupy, AnimalType? animal) =>
    terrain.index |
    (occupy << _kOccupyShift) |
    ((animal?.index ?? 0) << _kAnimalShift);

bool _canEatType(AnimalType attacker, AnimalType defender) {
  if (attacker == defender) return true;
  if (attacker == AnimalType.mouse && defender == AnimalType.elephant) {
    return true;
  }
  if (attacker == AnimalType.elephant && defender == AnimalType.mouse) {
    return false;
  }
  return attacker.index < defender.index;
}

bool _canEnterTerrain(AnimalType type, GridType from, GridType target) {
  return switch (target) {
    GridType.river => _kRiverAnimals.contains(type),
    GridType.bridge =>
      from == GridType.river
          ? type == AnimalType.mouse
          : type != AnimalType.elephant,
    GridType.tree => _kTreeAnimals.contains(type),
    _ => true,
  };
}

class BoardInfo {
  final int size;
  final List<int> situation;
  final List<AnimalType> selfHidden;
  final List<AnimalType> enemyHidden;

  const BoardInfo(this.size, this.situation, this.selfHidden, this.enemyHidden);
}

// ============================================================
// Zobrist — 单例哈希缓存（含四重对称）
// ============================================================

class Zobrist {
  static final instance = Zobrist._();

  static const _maxCells = 169;
  static const _numCodes = 18;
  static const _numAnimals = 8;

  late final List<List<int>> _cellKeys;
  late final List<int> _selfHiddenKeys;
  late final List<int> _enemyHiddenKeys;
  final Map<int, GameAction> _table = {};
  final Random _rng = Random(2024);

  Zobrist._() {
    _cellKeys = List.generate(
      _maxCells,
      (_) => List.generate(_numCodes, (_) => _rand64()),
    );
    _selfHiddenKeys = List.generate(_numAnimals, (_) => _rand64());
    _enemyHiddenKeys = List.generate(_numAnimals, (_) => _rand64());
  }

  int _rand64() => _rng.nextInt(0x7FFFFFFF) ^ (_rng.nextInt(0x7FFFFFFF) << 31);

  int _cellToCode(int cell) {
    if (cell == 0) return 0;
    final occupy = (cell >> _kOccupyShift) & _kOccupyMask;
    if (occupy == _kOccupyEmpty) return 0;
    if (occupy == _kOccupyHidden) return 17;
    final animal = (cell >> _kAnimalShift) & _kAnimalMask;
    if (occupy == _kOccupySelf) return animal + 1;
    return animal + 9;
  }

  int computeHash(BoardInfo info) {
    int h = 0;
    for (int i = 0; i < info.situation.length; i++) {
      h ^= _cellKeys[i][_cellToCode(info.situation[i])];
    }
    for (final t in info.selfHidden) {
      h ^= _selfHiddenKeys[t.index];
    }
    for (final t in info.enemyHidden) {
      h ^= _enemyHiddenKeys[t.index];
    }
    return h;
  }

  GameAction? lookup(BoardInfo info) => _table[computeHash(info)];

  bool contains(BoardInfo info) => _table.containsKey(computeHash(info));

  /// 存表（四重对称，共 4 条）
  void store(GameAction action, BoardInfo info) {
    for (final t in _kTransforms) {
      final ts = _transformSituation(info.situation, info.size, t);
      _table[computeHash(
            BoardInfo(info.size, ts, info.selfHidden, info.enemyHidden),
          )] =
          action;
    }
  }

  void clear() => _table.clear();

  // --- 四重对称变换 ---

  static int _id(int i, int n) => i;
  static int _hm(int i, int n) => (i ~/ n) * n + (n - 1 - i % n);
  static int _vm(int i, int n) => (n - 1 - i ~/ n) * n + (i % n);
  static int _r180(int i, int n) => (n - 1 - i ~/ n) * n + (n - 1 - i % n);

  static const _kTransforms = [_id, _hm, _vm, _r180];

  static List<int> _transformSituation(
    List<int> situation,
    int n,
    int Function(int, int) t,
  ) {
    final r = List<int>.filled(situation.length, 0);
    for (int i = 0; i < situation.length; i++) {
      r[t(i, n)] = situation[i];
    }
    return r;
  }
}

// ============================================================
// BoardSnapshot — 棋盘快照
// ============================================================

class BoardSnapshot {
  late List<int> situation;
  final TurnGamerType faction;
  final int size;

  Map<AnimalType, int> selfVisible = {};
  Map<AnimalType, int> enemyVisible = {};
  List<AnimalType> selfHidden = [];
  List<AnimalType> enemyHidden = [];

  BoardSnapshot._(this.situation, this.faction, this.size);

  BoardInfo get boardInfo =>
      BoardInfo(size, situation, selfHidden, enemyHidden);

  factory BoardSnapshot.fromBoard(
    List<Grid> board,
    int size,
    TurnGamerType faction,
  ) {
    final snapshot = BoardSnapshot._(
      List<int>.filled(size * size, 0),
      faction,
      size,
    );
    snapshot._buildFrom(board);
    return snapshot;
  }

  void _buildFrom(List<Grid> board) {
    final selfTypeSet = <AnimalType>{};
    final enemyTypeSet = <AnimalType>{};

    for (int i = 0; i < board.length; i++) {
      final grid = board[i];
      int occupyBits;
      int animalBits = 0;

      if (!grid.hasAnimal) {
        occupyBits = _kOccupyEmpty;
      } else if (grid.animal!.isHidden) {
        occupyBits = _kOccupyHidden;
        final isSelf = grid.animal!.owner == faction;
        (isSelf ? selfTypeSet : enemyTypeSet).add(grid.animal!.type);
      } else {
        final isSelf = grid.animal!.owner == faction;
        occupyBits = isSelf ? _kOccupySelf : _kOccupyEnemy;
        animalBits = grid.animal!.type.index;
        (isSelf ? selfVisible : enemyVisible)[grid.animal!.type] = i;
      }

      situation[i] =
          grid.type.index |
          (occupyBits << _kOccupyShift) |
          (animalBits << _kAnimalShift);
    }

    final allTypes = AnimalType.values;
    selfHidden = allTypes.where((t) => !selfTypeSet.contains(t)).toList();
    enemyHidden = allTypes.where((t) => !enemyTypeSet.contains(t)).toList();
    _sortMaps();
  }

  void applyFlip(int index, GridType terrain, AnimalType type, TurnGamerType owner) {
    final isSelf = owner == faction;
    situation[index] = _encodeCell(
      terrain,
      isSelf ? _kOccupySelf : _kOccupyEnemy,
      type,
    );

    if (isSelf) {
      selfHidden.remove(type);
      selfVisible[type] = index;
    } else {
      enemyHidden.remove(type);
      enemyVisible[type] = index;
    }
    _sortMaps();
  }

  void applyMove(
    int from,
    int to,
    GridType fromTerrain,
    GridType toTerrain,
    AnimalType fromType,
    TurnGamerType fromOwner, {
    bool toHasAnimal = false,
    AnimalType? toType,
    TurnGamerType? toOwner,
  }) {
    final isSelf = fromOwner == faction;
    situation[from] = _encodeCell(fromTerrain, _kOccupyEmpty, null);

    if (toHasAnimal && toOwner != fromOwner) {
      final attackerWins = _canEatType(fromType, toType!);
      final defenderWins = _canEatType(toType, fromType);

      if (attackerWins && defenderWins) {
        situation[to] = _encodeCell(toTerrain, _kOccupyEmpty, null);
        _removeVisible(fromType, isSelf);
        _removeVisible(toType, !isSelf);
      } else if (attackerWins) {
        situation[to] = _encodeCell(
          toTerrain,
          isSelf ? _kOccupySelf : _kOccupyEnemy,
          fromType,
        );
        _removeVisible(toType, !isSelf);
        _updateVisible(fromType, isSelf, to);
      } else {
        // 守方胜：移动方消失
        _removeVisible(fromType, isSelf);
      }
    } else {
      situation[to] = _encodeCell(
        toTerrain,
        isSelf ? _kOccupySelf : _kOccupyEnemy,
        fromType,
      );
      _updateVisible(fromType, isSelf, to);
    }
  }

  /// 收集所有暗棋位置
  List<int> findHiddenPositions() {
    final result = <int>[];
    for (int i = 0; i < situation.length; i++) {
      if (_cellIsHidden(situation[i])) result.add(i);
    }
    return result;
  }

  void _removeVisible(AnimalType type, bool isSelf) {
    (isSelf ? selfVisible : enemyVisible).remove(type);
  }

  void _updateVisible(AnimalType type, bool isSelf, int newIndex) {
    (isSelf ? selfVisible : enemyVisible)[type] = newIndex;
  }

  void _sortMaps() {
    selfVisible = Map.fromEntries(
      selfVisible.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );
    enemyVisible = Map.fromEntries(
      enemyVisible.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );
  }

  @override
  String toString() {
    final sb = StringBuffer('BoardSnapshot(faction=$faction)\n');
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cell = situation[r * size + c];
        final tChar = ['L', 'R', 'O', 'B', 'T'][cell & _kTerrainBits];
        final occupy = (cell >> _kOccupyShift) & _kOccupyMask;
        final oChar = ['-', '?', 'S', 'E'][occupy];
        final aChar = occupy >= 2
            ? ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'][(cell >> _kAnimalShift) &
                  _kAnimalMask]
            : ' ';
        sb.write('$tChar$oChar$aChar ');
      }
      sb.writeln();
    }
    sb.writeln('selfVisible: $selfVisible');
    sb.writeln('enemyVisible: $enemyVisible');
    sb.writeln('selfHidden: $selfHidden');
    sb.writeln('enemyHidden: $enemyHidden');
    return sb.toString();
  }
}

// ============================================================
// SearchBoard — 搜索用可变棋盘（undo/redo 模式）
// ============================================================

class _SearchBoard {
  final int size;
  final List<int> situation;
  final List<AnimalType> selfHidden;
  final List<AnimalType> enemyHidden;
  final Map<AnimalType, int> selfPositions;
  final Map<AnimalType, int> enemyPositions;

  _SearchBoard._(
    this.size,
    this.situation,
    this.selfHidden,
    this.enemyHidden,
    this.selfPositions,
    this.enemyPositions,
  );

  factory _SearchBoard.fromSnapshot(BoardSnapshot snapshot) {
    return _SearchBoard._(
      snapshot.size,
      List<int>.from(snapshot.situation),
      List<AnimalType>.from(snapshot.selfHidden),
      List<AnimalType>.from(snapshot.enemyHidden),
      Map<AnimalType, int>.from(snapshot.selfVisible),
      Map<AnimalType, int>.from(snapshot.enemyVisible),
    );
  }

  // --- 走法执行（返回旧值供 undo） ---

  /// 执行移动，返回 {from: 旧from值, to: 旧to值}
  Map<int, int> doMove(int from, int to) {
    final saved = {from: situation[from], to: situation[to]};
    final moving = situation[from];
    final target = situation[to];
    final mType = _cellAnimal(moving);
    final isSelf = _cellIsSelf(moving);

    situation[from] = _cellTerrain(moving).index;

    if (_cellIsEmpty(target)) {
      situation[to] = _encodeCell(
        _cellTerrain(target),
        isSelf ? _kOccupySelf : _kOccupyEnemy,
        mType,
      );
      (isSelf ? selfPositions : enemyPositions)[mType] = to;
    } else if (_cellIsHidden(target)) {
      situation[to] = _encodeCell(
        _cellTerrain(target),
        isSelf ? _kOccupySelf : _kOccupyEnemy,
        mType,
      );
      (isSelf ? selfPositions : enemyPositions)[mType] = to;
    } else {
      final dType = _cellAnimal(target);
      final aWins = _canEatType(mType, dType);
      final dWins = _canEatType(dType, mType);
      if (aWins && dWins) {
        situation[to] = _cellTerrain(target).index;
        (isSelf ? selfPositions : enemyPositions).remove(mType);
        (isSelf ? enemyPositions : selfPositions).remove(dType);
      } else if (aWins) {
        situation[to] = _encodeCell(
          _cellTerrain(target),
          isSelf ? _kOccupySelf : _kOccupyEnemy,
          mType,
        );
        (isSelf ? selfPositions : enemyPositions)[mType] = to;
        (isSelf ? enemyPositions : selfPositions).remove(dType);
      } else {
        (isSelf ? selfPositions : enemyPositions).remove(mType);
      }
    }
    return saved;
  }

  /// 执行翻牌，返回 {index: 旧值}
  Map<int, int> doFlip(int index) {
    final saved = {index: situation[index]};
    final cell = situation[index];
    final animal = _cellAnimal(cell);
    final isSelf = selfHidden.contains(animal);

    (isSelf ? selfHidden : enemyHidden).remove(animal);
    situation[index] = _encodeCell(
      _cellTerrain(cell),
      isSelf ? _kOccupySelf : _kOccupyEnemy,
      animal,
    );
    (isSelf ? selfPositions : enemyPositions)[animal] = index;
    return saved;
  }

  /// 撤销移动
  void undoMove(int from, int to, Map<int, int> saved) {
    situation[from] = saved[from]!;
    situation[to] = saved[to]!;
    _rebuildPositions();
  }

  /// 撤销翻牌
  void undoFlip(
    int index,
    Map<int, int> saved,
    List<AnimalType> savedSelfH,
    List<AnimalType> savedEnemyH,
  ) {
    situation[index] = saved[index]!;
    selfHidden
      ..clear()
      ..addAll(savedSelfH);
    enemyHidden
      ..clear()
      ..addAll(savedEnemyH);
    _rebuildPositions();
  }

  void _rebuildPositions() {
    selfPositions.clear();
    enemyPositions.clear();
    for (int i = 0; i < situation.length; i++) {
      final c = situation[i];
      if (_cellIsSelf(c)) selfPositions[_cellAnimal(c)] = i;
      if (_cellIsEnemy(c)) enemyPositions[_cellAnimal(c)] = i;
    }
  }

  // --- 走法生成（吃子优先排序） ---

  List<GameAction> generateMoves(bool isSelf) {
    final moves = <GameAction>[];
    final captures = <GameAction>[];
    final positions = isSelf ? selfPositions : enemyPositions;

    // 翻牌
    if ((isSelf ? selfHidden : enemyHidden).isNotEmpty) {
      for (int i = 0; i < situation.length; i++) {
        if (_cellIsHidden(situation[i])) moves.add(FlipAction(i));
      }
    }

    // 移动
    for (final entry in positions.entries) {
      final type = entry.key;
      final i = entry.value;
      final r = i ~/ size;
      final c = i % size;

      for (final (dr, dc) in planeAround) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;

        final ni = nr * size + nc;
        final target = situation[ni];

        if (_cellIsHidden(target)) continue;
        if (isSelf ? _cellIsSelf(target) : _cellIsEnemy(target)) continue;
        if (!_canEnterTerrain(
          type,
          _cellTerrain(situation[i]),
          _cellTerrain(target),
        )) {
          continue;
        }

        final action = MoveAction(i, ni);
        if (!_cellIsEmpty(target)) {
          captures.add(action);
        } else {
          moves.add(action);
        }
      }
    }

    // 吃子优先
    captures.sort((a, b) {
      final aVal =
          _baseScores[_cellAnimal(situation[(a as MoveAction).to])] ?? 0;
      final bVal =
          _baseScores[_cellAnimal(situation[(b as MoveAction).to])] ?? 0;
      return bVal.compareTo(aVal);
    });

    return captures..addAll(moves);
  }

  // --- 威胁判断 ---

  bool isThreatened(int pos, AnimalType piece) {
    final r = pos ~/ size;
    final c = pos % size;
    final terrain = _cellTerrain(situation[pos]);

    if (terrain == GridType.tree && !_kTreeAnimals.contains(piece)) {
      return false;
    }

    for (final (dr, dc) in planeAround) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
      final adj = situation[nr * size + nc];
      if (_cellIsEmpty(adj) || _cellIsHidden(adj) || _cellIsSelf(adj)) continue;

      final adjType = _cellAnimal(adj);
      if (!_canEatType(adjType, piece)) continue;
      if (!_canEnterTerrain(adjType, _cellTerrain(adj), terrain)) continue;

      return true;
    }
    return false;
  }
}

// ============================================================
// 评估函数
// ============================================================

/// 动态分：totalScore - 所有敌人的威胁扣分
Map<AnimalType, double> _calcDynamicScores(_SearchBoard board, bool isSelf) {
  final result = <AnimalType, double>{};
  final positions = isSelf ? board.selfPositions : board.enemyPositions;
  final enemyPos = isSelf ? board.enemyPositions : board.selfPositions;
  final enemyH = isSelf ? board.enemyHidden : board.selfHidden;

  for (final entry in positions.entries) {
    final type = entry.key;
    double penalty = 0;

    for (final eEntry in enemyPos.entries) {
      final eType = eEntry.key;
      if (_canEatType(eType, type)) {
        penalty += _baseScores[eType]! * (_canEatType(type, eType) ? 0.5 : 1.0);
      }
    }

    if (enemyH.isNotEmpty) {
      int canEat = 0, canMutual = 0;
      for (final hType in enemyH) {
        if (_canEatType(hType, type)) {
          if (_canEatType(type, hType)) {
            canMutual++;
          } else {
            canEat++;
          }
        }
      }
      penalty += (canEat + canMutual * 0.5) * _kTotalScore / enemyH.length;
    }

    result[type] = _kTotalScore - penalty;
  }
  return result;
}

/// 局面评估：材料 + 局势 + 机动性
double _evaluate(_SearchBoard board) {
  if (board.selfPositions.isEmpty) return -100000;
  if (board.enemyPositions.isEmpty) return 100000;

  final selfD = _calcDynamicScores(board, true);
  final enemyD = _calcDynamicScores(board, false);
  double score = 0;

  // 材料分
  for (final type in board.selfPositions.keys) {
    score += selfD[type] ?? 0;
  }
  for (final type in board.enemyPositions.keys) {
    score -= enemyD[type] ?? 0;
  }
  for (final type in board.selfHidden) {
    score += _baseScores[type]!.toDouble();
  }
  for (final type in board.enemyHidden) {
    score -= _baseScores[type]!.toDouble();
  }

  // 局势分
  for (int i = 0; i < board.situation.length; i++) {
    final c = board.situation[i];
    if (_cellIsEmpty(c) || _cellIsHidden(c)) continue;
    final isSelf = _cellIsSelf(c);
    final type = _cellAnimal(c);
    final weight = isSelf ? (selfD[type] ?? 0) : (enemyD[type] ?? 0);
    if (board.isThreatened(i, type)) {
      score += isSelf ? -weight * 0.5 : weight * 0.5;
    }
  }

  // 机动性分
  score +=
      (board.generateMoves(true).length - board.generateMoves(false).length) *
      0.1;

  return score;
}

// ============================================================
// Minimax + Alpha-Beta
// ============================================================

GameAction? _searchBestMove(_SearchBoard board) {
  final moves = board.generateMoves(true);
  if (moves.isEmpty) return null;

  double bestScore = double.negativeInfinity;
  GameAction? bestMove;

  for (final action in moves) {
    final Map<int, int> saved;
    final List<AnimalType>? savedSelfH, savedEnemyH;
    if (action is FlipAction) {
      savedSelfH = List<AnimalType>.from(board.selfHidden);
      savedEnemyH = List<AnimalType>.from(board.enemyHidden);
      saved = board.doFlip(action.index);
    } else {
      savedSelfH = null;
      savedEnemyH = null;
      saved = board.doMove((action as MoveAction).from, action.to);
    }

    final score = _minimax(
      board,
      _kSearchDepth - 1,
      double.negativeInfinity,
      double.infinity,
      false,
    );

    if (action is FlipAction) {
      board.undoFlip(action.index, saved, savedSelfH!, savedEnemyH!);
    } else {
      board.undoMove((action as MoveAction).from, action.to, saved);
    }

    if (score > bestScore) {
      bestScore = score;
      bestMove = action;
    }
  }

  return bestMove;
}

double _minimax(
  _SearchBoard board,
  int depth,
  double alpha,
  double beta,
  bool isMax,
) {
  if (depth == 0) return _evaluate(board);

  final moves = board.generateMoves(isMax);
  if (moves.isEmpty) return _evaluate(board);

  double value = isMax ? double.negativeInfinity : double.infinity;

  for (final action in moves) {
    final List<AnimalType>? savedSelfH, savedEnemyH;
    final Map<int, int> saved;

    if (action is FlipAction) {
      savedSelfH = List<AnimalType>.from(board.selfHidden);
      savedEnemyH = List<AnimalType>.from(board.enemyHidden);
      saved = board.doFlip(action.index);
    } else {
      savedSelfH = null;
      savedEnemyH = null;
      saved = board.doMove((action as MoveAction).from, action.to);
    }

    final childScore = _minimax(board, depth - 1, alpha, beta, !isMax);

    if (action is FlipAction) {
      board.undoFlip(action.index, saved, savedSelfH!, savedEnemyH!);
    } else {
      board.undoMove((action as MoveAction).from, action.to, saved);
    }

    if (isMax) {
      value = max(value, childScore);
      alpha = max(alpha, value);
    } else {
      value = min(value, childScore);
      beta = min(beta, value);
    }
    if (beta <= alpha) break;
  }

  return value;
}

/// 单步移动评分（吃子 + 逃避威胁 + 威胁敌方 + 机动性）
double _scoreMove(
  _SearchBoard board,
  MoveAction move,
  Map<AnimalType, double> selfDynamic,
) {
  final mType = _cellAnimal(board.situation[move.from]);
  final target = board.situation[move.to];
  double score = 0;

  // 吃子收益
  if (!_cellIsEmpty(target) && _cellIsEnemy(target)) {
    final dType = _cellAnimal(target);
    if (_canEatType(mType, dType)) {
      score += (selfDynamic[dType] ?? _kTotalScore.toDouble()) * 10;
    }
  }

  // 逃避威胁
  final wasThreatened = board.isThreatened(move.from, mType);
  final saved = board.doMove(move.from, move.to);
  final nowThreatened = board.isThreatened(move.to, mType);
  final selfWeight = selfDynamic[mType] ?? _kTotalScore.toDouble();

  if (wasThreatened && !nowThreatened) {
    score += selfWeight * 5;
  }

  // 威胁敌方
  final r = move.to ~/ board.size;
  final c = move.to % board.size;
  for (final (dr, dc) in planeAround) {
    final nr = r + dr;
    final nc = c + dc;
    if (nr < 0 || nr >= board.size || nc < 0 || nc >= board.size) continue;
    final adj = board.situation[nr * board.size + nc];
    if (_cellIsEmpty(adj) || _cellIsHidden(adj) || _cellIsSelf(adj)) continue;
    final adjType = _cellAnimal(adj);
    if (_canEatType(mType, adjType)) {
      score += (selfDynamic[adjType] ?? _kTotalScore.toDouble()) * 2;
    }
  }

  board.undoMove(move.from, move.to, saved);

  // 机动性分
  final mobBefore = _countReachable(board, move.from, mType);
  final mobAfter = _countReachable(board, move.to, mType);
  score += (mobAfter - mobBefore) * selfWeight * 0.3;

  return score;
}

/// 翻牌评估：对每个暗棋位置，假设翻出各种可能的动物，按概率加权算分
FlipAction _evaluateFlip(_SearchBoard board, List<int> hiddenPositions) {
  double bestScore = double.negativeInfinity;
  int bestPos = hiddenPositions.first;
  final totalHidden = hiddenPositions.length;
  final selfCount = board.selfHidden.length;
  final enemyCount = board.enemyHidden.length;

  for (final pos in hiddenPositions) {
    double totalScore = 0;
    int count = 0;

    // 假设翻出己方暗棋
    if (selfCount > 0) {
      final prob = selfCount / totalHidden;
      for (final type in board.selfHidden) {
        board.situation[pos] = _encodeCell(
          _cellTerrain(board.situation[pos]),
          _kOccupySelf,
          type,
        );
        board.selfPositions[type] = pos;
        totalScore += _evalFlipScore(board, true) * prob;
        board.selfPositions.remove(type);
        count++;
      }
      board.situation[pos] = _encodeCell(
        _cellTerrain(board.situation[pos]),
        _kOccupyHidden,
        null,
      );
    }

    // 假设翻出敌方暗棋
    if (enemyCount > 0) {
      final prob = enemyCount / totalHidden;
      for (final type in board.enemyHidden) {
        board.situation[pos] = _encodeCell(
          _cellTerrain(board.situation[pos]),
          _kOccupyEnemy,
          type,
        );
        board.enemyPositions[type] = pos;
        totalScore += _evalFlipScore(board, false) * prob;
        board.enemyPositions.remove(type);
        count++;
      }
      board.situation[pos] = _encodeCell(
        _cellTerrain(board.situation[pos]),
        _kOccupyHidden,
        null,
      );
    }

    final avgScore = count > 0 ? totalScore / count : 0.0;
    if (avgScore > bestScore) {
      bestScore = avgScore;
      bestPos = pos;
    }
  }

  return FlipAction(bestPos);
}

/// 评估翻出棋子后的价值：己方最佳走法：己方如果是敌人，考虑对方最差响应
double _evalFlipScore(_SearchBoard board, bool isSelfPiece) {
  final moves = board.generateMoves(true);
  double bestScore = double.negativeInfinity;
  final limit = moves.length > _kFlipEvalMoves ? _kFlipEvalMoves : moves.length;

  for (int i = 0; i < limit; i++) {
    final action = moves[i];
    final Map<int, int> saved;
    if (action is FlipAction) {
      saved = board.doFlip(action.index);
    } else {
      saved = board.doMove((action as MoveAction).from, action.to);
    }
    bestScore = max(bestScore, _evaluate(board));
    if (action is FlipAction) {
      board.undoFlip(action.index, saved, board.selfHidden, board.enemyHidden);
    } else {
      board.undoMove((action as MoveAction).from, action.to, saved);
    }
  }
  if (limit == 0) bestScore = 0;

  // 敌方棋子还要考虑对方最差响应
  if (!isSelfPiece) {
    final pMoves = board.generateMoves(false);
    double worstScore = double.infinity;
    final pLimit = pMoves.length > _kFlipEvalMoves
        ? _kFlipEvalMoves
        : pMoves.length;
    for (int i = 0; i < pLimit; i++) {
      final action = pMoves[i];
      final Map<int, int> saved;
      if (action is FlipAction) {
        saved = board.doFlip(action.index);
      } else {
        saved = board.doMove((action as MoveAction).from, action.to);
      }
      worstScore = min(worstScore, _evaluate(board));
      if (action is FlipAction) {
        board.undoFlip(
          action.index,
          saved,
          board.selfHidden,
          board.enemyHidden,
        );
      } else {
        board.undoMove((action as MoveAction).from, action.to, saved);
      }
    }
    if (pLimit == 0) worstScore = 0;
    return (bestScore + worstScore) / 2;
  }

  return bestScore;
}

/// 2 步 BFS 可达格子数
int _countReachable(_SearchBoard board, int pos, AnimalType type) {
  final visited = <int>{pos};
  var frontier = <int>[pos];

  for (int step = 0; step < 2; step++) {
    final next = <int>[];
    for (final p in frontier) {
      final r = p ~/ board.size;
      final c = p % board.size;
      for (final (dr, dc) in planeAround) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= board.size || nc < 0 || nc >= board.size) continue;
        final ni = nr * board.size + nc;
        if (visited.contains(ni)) continue;
        final cell = board.situation[ni];
        if (_cellIsHidden(cell) || _cellIsSelf(cell)) continue;
        if (!_canEnterTerrain(
          type,
          _cellTerrain(board.situation[p]),
          _cellTerrain(cell),
        )) {
          continue;
        }
        visited.add(ni);
        next.add(ni);
      }
    }
    frontier = next;
  }

  return visited.length - 1;
}

// ============================================================
// 日志
// ============================================================

const _kAbbr = ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'];

void _log(String msg) => debugPrint('[AI-Test] $msg');

String _posStr(int index, int size) => '(${index ~/ size},${index % size})';

String _actionStr(GameAction action, int size) {
  if (action is FlipAction) return 'Flip${_posStr(action.index, size)}';
  if (action is MoveAction) {
    return 'Move${_posStr(action.from, size)}->${_posStr(action.to, size)}';
  }
  return action.toString();
}

/// 紧凑棋盘打印：地形+棋子，己方大写 / 敌方小写 / 暗棋 ? / 空 .
/// 例：TC=树上己方猫 Rc=河上敌方猫 L?=地上暗棋 R.=河上空
void _logBoard(
  String label,
  List<Grid> board,
  int size,
  TurnGamerType aiFaction,
) {
  const terrainChar = ['L', 'R', 'O', 'B', 'T'];
  final sb = StringBuffer('  ');
  for (int c = 0; c < size; c++) {
    sb.write(c.toString().padLeft(3));
  }
  sb.writeln();

  for (int r = 0; r < size; r++) {
    sb.write('${r.toString().padLeft(2)}  ');
    for (int c = 0; c < size; c++) {
      final grid = board[r * size + c];
      final t = terrainChar[grid.type.index];
      if (!grid.hasAnimal) {
        sb.write('$t.');
      } else if (grid.animal!.isHidden) {
        sb.write('$t?');
      } else {
        final a = _kAbbr[grid.animal!.type.index];
        sb.write(
          grid.animal!.owner == aiFaction ? '$t$a' : '$t${a.toLowerCase()}',
        );
      }
      sb.write(' ');
    }
    sb.writeln();
  }
  _log('$label:\n$sb');
}

// ============================================================
// AiController — AI 控制器
// ============================================================

class AiController {
  static final _random = Random();

  final List<Grid> board;
  final int boardSize;
  final TurnGamerType faction;
  final Zobrist _zobrist = Zobrist.instance;
  late final BoardSnapshot aiSnapshot;
  late final BoardSnapshot playerSnapshot;

  AiController({
    required this.board,
    required this.boardSize,
    required this.faction,
  }) {
    aiSnapshot = BoardSnapshot.fromBoard(board, boardSize, faction);
    playerSnapshot = BoardSnapshot.fromBoard(
      board,
      boardSize,
      faction.opponent,
    );
  }

  /// AI 决策入口
  GameAction? getAction() {
    _logBoard('Before', board, boardSize, faction);

    // 1. 特殊情况：无明棋 → 随机翻牌
    if (aiSnapshot.selfVisible.isEmpty && aiSnapshot.enemyVisible.isEmpty) {
      final flip = _getRandomFlipAction(aiSnapshot);
      if (flip != null) {
        _log('No visible pieces, random flip');
        _applyAiAction(flip);
        _log('Decision: ${_actionStr(flip, boardSize)}');
        _logBoard('After', board, boardSize, faction);
        return flip;
      }
    }

    // 2. 查表
    GameAction? cached = _zobrist.lookup(aiSnapshot.boardInfo);
    if (cached != null) {
      _log('Zobrist hit: ${_actionStr(cached, boardSize)}');
      _applyAiAction(cached);
      _logBoard('After', board, boardSize, faction);
      return cached;
    }

    // 3. minimax 搜索
    final searchBoard = _SearchBoard.fromSnapshot(aiSnapshot);
    GameAction? bestMove = _searchBestMove(searchBoard);

    if (bestMove != null) {
      final selfD = _calcDynamicScores(searchBoard, true);
      final moveScore = _scoreMove(searchBoard, bestMove as MoveAction, selfD);
      _log(
        'Best move: ${_actionStr(bestMove, boardSize)} (score: ${moveScore.toStringAsFixed(1)})',
      );

      // 收益小且有暗棋 → 策略翻牌
      if (moveScore < _kFlipThreshold && aiSnapshot.selfHidden.isNotEmpty) {
        final hidden = aiSnapshot.findHiddenPositions();
        if (hidden.isNotEmpty) {
          final flip = _getStrategyFlipAction();
          if (flip != null) {
            _log('Move score low ($moveScore < $_kFlipThreshold), prefer flip');
            _applyAiAction(flip);
            _log('Decision: ${_actionStr(flip, boardSize)}');
            _logBoard('After', board, boardSize, faction);
            return flip;
          }
        }
      }

      _applyAiAction(bestMove);
      _log('Decision: ${_actionStr(bestMove, boardSize)}');
      _logBoard('After', board, boardSize, faction);
      return bestMove;
    }

    // 4. 无法移动 → 策略翻牌
    final flip = _getStrategyFlipAction();
    if (flip != null) {
      _log('No moves available, strategic flip');
      _applyAiAction(flip);
      _log('Decision: ${_actionStr(flip, boardSize)}');
      _logBoard('After', board, boardSize, faction);
      return flip;
    }

    _log('No action available');
    return null;
  }

  FlipAction? _getRandomFlipAction(BoardSnapshot snapshot) {
    final hiddenList = snapshot.findHiddenPositions();
    if (hiddenList.isEmpty) return null;
    return FlipAction(hiddenList[_random.nextInt(hiddenList.length)]);
  }

  FlipAction? _getStrategyFlipAction() {
    final hidden = aiSnapshot.findHiddenPositions();
    if (hidden.isEmpty) return null;
    final searchBoard = _SearchBoard.fromSnapshot(aiSnapshot);
    return _evaluateFlip(searchBoard, hidden);
  }

  /// 玩家行动后更新棋盘、快照并存表
  void applyPlayerAction(GameAction action) {
    _log('Player: ${_actionStr(action, boardSize)}');
    _storeIfAbsent(playerSnapshot, action, true);
    _updateSnapshot(action); // 快照更新必须在 _applyAction 之前，否则 fromGrid.animal 已被置空
    _applyAction(action);
  }

  void _applyAiAction(GameAction action) {
    _storeIfAbsent(aiSnapshot, action, false);
    _updateSnapshot(action); // 快照更新必须在 _applyAction 之前，否则 fromGrid.animal 已被置空
    _applyAction(action);
  }

  /// 应用行动到实际棋盘
  void _applyAction(GameAction action) {
    if (action is FlipAction) {
      final grid = board[action.index];
      if (grid.hasAnimal) {
        grid.animal!.isHidden = false;
      }
    } else if (action is MoveAction) {
      final fromGrid = board[action.from];
      final toGrid = board[action.to];
      final moving = fromGrid.animal;

      if (moving != null) {
        if (toGrid.hasAnimal && toGrid.animal!.owner != moving.owner) {
          final attackerWins = moving.canEat(toGrid.animal!);
          final defenderWins = toGrid.animal!.canEat(moving);
          if (attackerWins && defenderWins) {
            toGrid.animal = null;
          } else if (attackerWins) {
            toGrid.animal = moving;
          }
        } else {
          toGrid.animal = moving;
        }
        fromGrid.animal = null;
      }
    }
  }

  void _updateSnapshot(GameAction action) {
    if (action is FlipAction) {
      final grid = board[action.index];
      if (grid.hasAnimal) {
        final animal = grid.animal!;
        aiSnapshot.applyFlip(action.index, grid.type, animal.type, animal.owner);
        playerSnapshot.applyFlip(action.index, grid.type, animal.type, animal.owner);
      }
    } else if (action is MoveAction) {
      final fromGrid = board[action.from];
      final toGrid = board[action.to];
      final moving = fromGrid.animal;
      if (moving == null) return;
      aiSnapshot.applyMove(
        action.from, action.to, fromGrid.type, toGrid.type,
        moving.type, moving.owner,
        toHasAnimal: toGrid.hasAnimal && toGrid.animal!.owner != moving.owner,
        toType: toGrid.animal?.type,
        toOwner: toGrid.animal?.owner,
      );
      playerSnapshot.applyMove(
        action.from, action.to, fromGrid.type, toGrid.type,
        moving.type, moving.owner,
        toHasAnimal: toGrid.hasAnimal && toGrid.animal!.owner != moving.owner,
        toType: toGrid.animal?.type,
        toOwner: toGrid.animal?.owner,
      );
    }
  }

  /// 有缓存且非强制存储时跳过，否则存 4 条（原版+三个变体）
  void _storeIfAbsent(BoardSnapshot snapshot, GameAction action, bool update) {
    if (_zobrist.contains(snapshot.boardInfo) && !update) return;
    _zobrist.store(action, snapshot.boardInfo);
  }

  void dispose() {}
}
