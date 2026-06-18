import 'dart:math';
import 'package:flutter/foundation.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import 'base.dart';

// ============================================================
// 常量
// ============================================================

const int _kHidden = 999;
const int _kSearchDepth = 4;

/// 各动物基础分值
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

/// 所有基础分之和
const double _kScoreBase = 14;

/// 动物缩写：E=象 T=虎 L=狮 P=豹 W=狼 D=狗 C=猫 M=鼠
const List<String> _kAbbr = ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'];

// --- 评估权重 ---
// 调整这些值可以改变 AI 棋风：
// - 提高 material: AI 更注重吃子
// - 提高 threat: AI 更注重威胁和防御
// - 提高 mobility: AI 更注重走法灵活性

class _EvalWeights {
  /// 材料权重：棋子价值差的系数
  static const double material = 1.0;

  /// 威胁权重：(威胁数 - 被威胁数) 的系数
  static const double threat = 0.5;

  /// 暗棋威胁权重：附近暗棋潜在威胁的系数
  static const double hiddenThreat = 0.3;

  /// 机动性权重：(己方走法数 - 对方走法数) 的系数
  static const double mobility = 0.1;

  /// 树上加成：己方棋子在树上的额外分数（树上无法被吃）
  static const double treeBonus = 2.0;

  /// 豹子无敌加成：豹子上树且对方无豹子时的额外分数
  static const double leopardDominant = 5.0;

  /// 老虎桥上加成：老虎在桥上的额外分数（可跳河）
  static const double tigerBridge = 2.0;
}

class _FlipLimits {
  static const int aiMoves = 12;
  static const int playerMoves = 8;
}

// --- 地形通行许可 ---

const _kRiverAnimals = {AnimalType.elephant, AnimalType.dog, AnimalType.mouse};
const _kTreeAnimals = {AnimalType.leopard, AnimalType.cat, AnimalType.mouse};
const double _kWinScore = 100000;
const double _kLoseScore = -100000;

// ============================================================
// 工具函数
// ============================================================

/// 判断 attacker 能否吃 defender（含鼠吃象特殊规则）
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

/// 判断动物能否从 from 地形进入 target 地形
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

int _cellAnimalType(int cell) => cell.abs() - 1;
bool _isAiCell(int cell) => cell > 0 && cell != _kHidden;
bool _isPlayerCell(int cell) => cell < 0;

/// 收集双方存活动物类型（可见 + 暗棋）
(Set<AnimalType> ai, Set<AnimalType> player) _collectSurviving(
  _SearchBoard board,
) {
  final ai = <AnimalType>{};
  final player = <AnimalType>{};
  for (final c in board.cells) {
    if (_isAiCell(c)) ai.add(AnimalType.values[_cellAnimalType(c)]);
    if (_isPlayerCell(c)) player.add(AnimalType.values[_cellAnimalType(c)]);
  }
  ai.addAll(board.aiHidden);
  player.addAll(board.playerHidden);
  return (ai, player);
}

// ============================================================
// _MoveRecord — minimax 撤销记录
// ============================================================

class _MoveRecord {
  final int from, to;
  final int movingPiece, targetPiece;
  const _MoveRecord(this.from, this.to, this.movingPiece, this.targetPiece);
}

// ============================================================
// _SearchBoard — 搜索用可变棋盘
// ============================================================

class _SearchBoard {
  final int size;
  final List<GridType> terrain;
  final List<int> cells;
  final TurnGamerType aiFaction;

  /// AI 方明棋位置：按动物类型分组
  final Map<AnimalType, List<int>> aiPositions;

  /// 玩家方明棋位置：按动物类型分组
  final Map<AnimalType, List<int>> playerPositions;

  /// AI 方暗棋类型
  final List<AnimalType> aiHidden;

  /// 玩家方暗棋类型
  final List<AnimalType> playerHidden;

  _SearchBoard._(
    this.size,
    this.terrain,
    this.cells,
    this.aiFaction,
    this.aiPositions,
    this.playerPositions,
    this.aiHidden,
    this.playerHidden,
  );

  /// 从 Grid 列表构建搜索棋盘
  factory _SearchBoard.fromGrid(
    List<Grid> board,
    int size,
    TurnGamerType aiFaction,
  ) {
    final cells = List<int>.filled(size * size, 0);
    final terrain = List<GridType>.filled(size * size, GridType.land);
    final aiPositions = <AnimalType, List<int>>{};
    final playerPositions = <AnimalType, List<int>>{};

    for (int i = 0; i < board.length; i++) {
      final grid = board[i];
      terrain[i] = grid.type;

      if (!grid.hasAnimal) {
        cells[i] = 0;
      } else if (grid.animal!.isHidden) {
        cells[i] = _kHidden;
      } else if (grid.animal!.owner == aiFaction) {
        cells[i] = grid.animal!.type.index + 1;
        (aiPositions[grid.animal!.type] ??= []).add(i);
      } else {
        cells[i] = -(grid.animal!.type.index + 1);
        (playerPositions[grid.animal!.type] ??= []).add(i);
      }
    }

    final allTypes = AnimalType.values.toSet();
    final aiHidden = (allTypes.difference(aiPositions.keys.toSet())).toList()
      ..sort((a, b) => b.index.compareTo(a.index));
    final playerHidden = (allTypes.difference(
      playerPositions.keys.toSet(),
    )).toList()..sort((a, b) => b.index.compareTo(a.index));

    return _SearchBoard._(
      size,
      terrain,
      cells,
      aiFaction,
      aiPositions,
      playerPositions,
      aiHidden,
      playerHidden,
    );
  }

  /// 执行走棋，返回撤销记录
  _MoveRecord doMove(int from, int to) {
    final moving = cells[from];
    final target = cells[to];
    cells[from] = 0;

    if (target == 0) {
      cells[to] = moving;
    } else {
      final mType = AnimalType.values[_cellAnimalType(moving)];
      final tType = AnimalType.values[_cellAnimalType(target)];
      final aWins = _canEatType(mType, tType);
      final dWins = _canEatType(tType, mType);

      if (aWins && dWins) {
        cells[to] = 0; // 同归于尽
      } else if (aWins) {
        cells[to] = moving; // 攻方胜
      }
      // 守方胜则 cells[to] 不变
    }

    return _MoveRecord(from, to, moving, target);
  }

  /// 撤销走棋
  void undoMove(_MoveRecord record) {
    cells[record.from] = record.movingPiece;
    cells[record.to] = record.targetPiece;
  }

  /// 获取指定阵营所有明棋位置
  List<int> getVisiblePositions(bool isAi) {
    final positions = isAi ? aiPositions : playerPositions;
    return positions.values.expand((list) => list).toList();
  }
}

// ============================================================
// _ZobristTable — 哈希缓存单例（含四重对称）
// ============================================================

class _ZobristTable {
  static final instance = _ZobristTable._();

  static const _maxCells = 169;
  static const _numCodes = 18;
  static const _numAnimals = 8;

  late final List<List<int>> _pieceKeys;
  late final List<int> _aiHiddenKeys;
  late final List<int> _playerHiddenKeys;
  late final List<int> _sizeKeys;
  final Map<int, GameAction> _table = {};
  final Random _rng = Random(2024);

  _ZobristTable._() {
    _pieceKeys = List.generate(
      _maxCells,
      (_) => List.generate(_numCodes, (_) => _rand64()),
    );
    _aiHiddenKeys = List.generate(_numAnimals, (_) => _rand64());
    _playerHiddenKeys = List.generate(_numAnimals, (_) => _rand64());
    _sizeKeys = List.generate(20, (_) => _rand64());
  }

  int _rand64() => _rng.nextInt(0x7FFFFFFF) ^ (_rng.nextInt(0x7FFFFFFF) << 31);

  /// 将 cell 值映射到哈希编码
  int _cellToCode(int cell) {
    if (cell == 0) return 0;
    if (cell == _kHidden) return 17;
    if (cell > 0) return cell; // 1-8
    return -cell + 8; // -1→9, -2→10, ..., -8→16
  }

  /// 计算棋盘哈希值
  int computeHash(
    List<int> cells,
    int size,
    List<AnimalType> aiHidden,
    List<AnimalType> playerHidden,
  ) {
    int h = _sizeKeys[size];
    for (int i = 0; i < cells.length; i++) {
      h ^= _pieceKeys[i][_cellToCode(cells[i])];
    }
    for (final t in aiHidden) {
      h ^= _aiHiddenKeys[t.index];
    }
    for (final t in playerHidden) {
      h ^= _playerHiddenKeys[t.index];
    }
    return h;
  }

  /// 查表（含四重对称）
  GameAction? lookup(
    List<int> cells,
    int size,
    List<AnimalType> aiHidden,
    List<AnimalType> playerHidden,
  ) {
    for (final t in _kTransforms) {
      final tc = _transformCells(cells, size, t);
      final h = computeHash(tc, size, aiHidden, playerHidden);
      if (_table.containsKey(h)) {
        return _transformAction(_table[h]!, size, t);
      }
    }
    return null;
  }

  /// 存表（含四重对称）
  void store(
    GameAction action,
    List<int> cells,
    int size,
    List<AnimalType> aiHidden,
    List<AnimalType> playerHidden,
  ) {
    for (final t in _kTransforms) {
      final tc = _transformCells(cells, size, t);
      final h = computeHash(tc, size, aiHidden, playerHidden);
      _table[h] = _transformAction(action, size, t);
    }
  }

  void clear() => _table.clear();

  // --- 四重对称变换 ---

  static int _id(int i, int n) => i;
  static int _hm(int i, int n) => (i ~/ n) * n + (n - 1 - i % n); // 水平镜像
  static int _vm(int i, int n) => (n - 1 - i ~/ n) * n + (i % n); // 垂直镜像
  static int _r180(int i, int n) =>
      (n - 1 - i ~/ n) * n + (n - 1 - i % n); // 180度旋转

  static const _kTransforms = [_id, _hm, _vm, _r180];

  static List<int> _transformCells(
    List<int> cells,
    int n,
    int Function(int, int) t,
  ) {
    final r = List<int>.filled(cells.length, 0);
    for (int i = 0; i < cells.length; i++) {
      r[t(i, n)] = cells[i];
    }
    return r;
  }

  static GameAction _transformAction(
    GameAction action,
    int n,
    int Function(int, int) t,
  ) {
    if (action is FlipAction) return FlipAction(t(action.index, n));
    if (action is MoveAction) {
      return MoveAction(t(action.from, n), t(action.to, n));
    }
    return action;
  }
}

// ============================================================
// 评估函数
// ============================================================

/// 终局检测 + 材料 + 局势 + 机动性
double _evaluate(_SearchBoard board) {
  bool hasAi = false, hasPlayer = false;
  for (final c in board.cells) {
    if (_isAiCell(c)) hasAi = true;
    if (_isPlayerCell(c)) hasPlayer = true;
    if (hasAi && hasPlayer) break;
  }
  if (!hasAi) return _kLoseScore;
  if (!hasPlayer) return _kWinScore;

  final (aiSurv, playerSurv) = _collectSurviving(board);
  return _evalCombined(board, aiSurv, playerSurv) + _evalMobility(board);
}

/// 材料 + 局势综合评估（单次格子扫描）
double _evalCombined(
  _SearchBoard board,
  Set<AnimalType> aiSurviving,
  Set<AnimalType> playerSurviving,
) {
  final n = board.size;

  final aiVisible = <int, AnimalType>{};
  final playerVisible = <int, AnimalType>{};
  for (int i = 0; i < board.cells.length; i++) {
    final c = board.cells[i];
    if (_isAiCell(c)) aiVisible[i] = AnimalType.values[_cellAnimalType(c)];
    if (_isPlayerCell(c)) {
      playerVisible[i] = AnimalType.values[_cellAnimalType(c)];
    }
  }

  final aiMaterial = _calcMaterial(
    aiVisible.values,
    playerSurviving,
    board.aiHidden,
  );
  final playerMaterial = _calcMaterial(
    playerVisible.values,
    aiSurviving,
    board.playerHidden,
  );
  final situation = _evalSituation(board, n, aiSurviving, playerSurviving);

  return (aiMaterial - playerMaterial) + situation;
}

/// 计算一方的材料分
double _calcMaterial(
  Iterable<AnimalType> visiblePieces,
  Set<AnimalType> enemySurviving,
  List<AnimalType> hiddenPieces,
) {
  double material = 0;

  for (final type in visiblePieces) {
    int penalty = 0;
    for (final enemy in enemySurviving) {
      final eats = _canEatType(enemy, type);
      final mutual = _canEatType(type, enemy);
      if (eats && mutual) {
        penalty += (_baseScores[enemy]! / 2).round();
      } else if (eats) {
        penalty += _baseScores[enemy]!;
      }
    }
    material += (_kScoreBase - penalty) * _EvalWeights.material;
  }

  for (final t in hiddenPieces) {
    material += _baseScores[t]!.toDouble();
  }

  return material;
}

/// 评估局势分：威胁/防御 + 地形加成
double _evalSituation(
  _SearchBoard board,
  int n,
  Set<AnimalType> aiSurviving,
  Set<AnimalType> playerSurviving,
) {
  double situation = 0;

  for (int i = 0; i < board.cells.length; i++) {
    final c = board.cells[i];
    if (c == 0 || c == _kHidden) continue;

    final isAi = _isAiCell(c);
    final type = AnimalType.values[_cellAnimalType(c)];
    final terrain = board.terrain[i];
    final r = i ~/ n;
    final col = i % n;

    int threats = 0;
    int threatens = 0;
    double hiddenThreat = 0;
    final enemyHidden = isAi ? board.playerHidden : board.aiHidden;

    for (final (dr, dc) in planeAround) {
      final nr = r + dr;
      final nc = col + dc;
      if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
      final adj = board.cells[nr * n + nc];
      if (adj == 0) continue;

      if (adj == _kHidden) {
        if (enemyHidden.isNotEmpty) {
          int canEatCount = 0;
          for (final hType in enemyHidden) {
            if (_canEatType(hType, type)) canEatCount++;
          }
          hiddenThreat += canEatCount / enemyHidden.length;
        }
        continue;
      }

      final adjIsAi = _isAiCell(adj);
      if (isAi == adjIsAi) continue;

      final adjType = AnimalType.values[_cellAnimalType(adj)];
      if (_canEatType(type, adjType)) threatens++;
      if (_canEatType(adjType, type)) threats++;
    }

    double pieceScore =
        (threatens - threats) * _EvalWeights.threat -
        hiddenThreat * _EvalWeights.hiddenThreat;

    pieceScore += _calcTerrainBonus(
      type,
      terrain,
      isAi,
      isAi ? playerSurviving : aiSurviving,
    );
    situation += isAi ? pieceScore : -pieceScore;
  }

  return situation;
}

/// 计算地形加成
double _calcTerrainBonus(
  AnimalType type,
  GridType terrain,
  bool isAi,
  Set<AnimalType> enemyTypes,
) {
  double bonus = 0;

  if (terrain == GridType.tree && _kTreeAnimals.contains(type)) {
    bonus += _EvalWeights.treeBonus;
    if (type == AnimalType.leopard &&
        !enemyTypes.contains(AnimalType.leopard)) {
      bonus += _EvalWeights.leopardDominant;
    }
  }

  if (type == AnimalType.tiger && terrain == GridType.bridge) {
    bonus += _EvalWeights.tigerBridge;
  }

  return bonus;
}

/// 机动性评估：双方合法走法数量差
double _evalMobility(_SearchBoard board) {
  final aiMoves = _generateMoves(board, true);
  final playerMoves = _generateMoves(board, false);
  return (aiMoves.length - playerMoves.length) * _EvalWeights.mobility;
}

// ============================================================
// 走法生成
// ============================================================

/// 生成指定阵营的所有合法走法，按吃子价值降序排列
List<MoveAction> _generateMoves(_SearchBoard board, bool isAi) {
  final moves = <MoveAction>[];
  final n = board.size;

  for (int i = 0; i < board.cells.length; i++) {
    final cell = board.cells[i];
    if (cell == 0 || cell == _kHidden) continue;
    if (isAi != _isAiCell(cell)) continue;

    final type = AnimalType.values[_cellAnimalType(cell)];
    final r = i ~/ n;
    final c = i % n;

    for (final (dr, dc) in planeAround) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;

      final ni = nr * n + nc;
      final target = board.cells[ni];

      if (target == _kHidden) continue;
      if (target != 0 && _isAiCell(target) == isAi) continue;
      if (!_canEnterTerrain(type, board.terrain[i], board.terrain[ni])) {
        continue;
      }

      moves.add(MoveAction(i, ni));
    }
  }

  moves.sort((a, b) {
    final aVal = _getMoveCaptureValue(board, a);
    final bVal = _getMoveCaptureValue(board, b);
    return bVal.compareTo(aVal);
  });

  return moves;
}

/// 获取走法的吃子价值
int _getMoveCaptureValue(_SearchBoard board, MoveAction move) {
  final target = board.cells[move.to];
  if (target == 0 || target == _kHidden) return 0;
  return _baseScores[AnimalType.values[_cellAnimalType(target)]] ?? 0;
}

// ============================================================
// 搜索引擎 — Minimax + Alpha-Beta
// ============================================================

/// 验证缓存走法在当前棋盘上是否合法
bool _isActionValid(_SearchBoard board, GameAction action) {
  if (action is FlipAction) {
    return action.index >= 0 &&
        action.index < board.cells.length &&
        board.cells[action.index] == _kHidden;
  }
  if (action is MoveAction) {
    final from = board.cells[action.from];
    final to = board.cells[action.to];
    if (from == 0 || from == _kHidden) return false;
    if (!_isAiCell(from)) return false;
    if (to != 0 && to != _kHidden && _isAiCell(to)) return false;
    final type = AnimalType.values[_cellAnimalType(from)];
    return _canEnterTerrain(
      type,
      board.terrain[action.from],
      board.terrain[action.to],
    );
  }
  return false;
}

/// 搜索最佳走法：Zobrist 缓存 → 静态筛选 → minimax 深度搜索
GameAction? _searchBestMove(_SearchBoard board, _ZobristTable zobrist) {
  final cached = zobrist.lookup(
    board.cells,
    board.size,
    board.aiHidden,
    board.playerHidden,
  );
  if (cached != null && _isActionValid(board, cached)) return cached;

  final moves = _generateMoves(board, true);
  if (moves.isEmpty) return _evaluateFlip(board);

  final currentEval = _evaluate(board);
  final improvingMoves = _filterImprovingMoves(board, moves, currentEval);

  if (improvingMoves.isEmpty) {
    final flip = _evaluateFlip(board);
    if (flip != null) return flip;
  }

  final candidates = improvingMoves.isNotEmpty
      ? (improvingMoves..sort((a, b) => b.$2.compareTo(a.$2)))
            .map((e) => e.$1)
            .toList()
      : moves;

  return _minimaxSearch(board, candidates);
}

/// 筛选能改善局势的走法
List<(MoveAction, double)> _filterImprovingMoves(
  _SearchBoard board,
  List<MoveAction> moves,
  double currentEval,
) {
  final improving = <(MoveAction, double)>[];
  for (final move in moves) {
    final undo = board.doMove(move.from, move.to);
    final staticEval = _evaluate(board);
    board.undoMove(undo);
    if (staticEval > currentEval) {
      improving.add((move, staticEval));
    }
  }
  return improving;
}

/// minimax 深度搜索
MoveAction? _minimaxSearch(_SearchBoard board, List<MoveAction> candidates) {
  double bestScore = double.negativeInfinity;
  MoveAction? bestMove;

  for (final move in candidates) {
    final undo = board.doMove(move.from, move.to);
    final score = _minimax(
      board,
      _kSearchDepth - 1,
      double.negativeInfinity,
      double.infinity,
      false,
    );
    board.undoMove(undo);
    if (score > bestScore) {
      bestScore = score;
      bestMove = move;
    }
  }

  return bestMove;
}

/// minimax + alpha-beta 剪枝
double _minimax(
  _SearchBoard board,
  int depth,
  double alpha,
  double beta,
  bool isMax,
) {
  if (depth == 0) return _evaluate(board);

  final moves = _generateMoves(board, isMax);
  if (moves.isEmpty) return _evaluate(board);

  if (isMax) {
    double value = double.negativeInfinity;
    for (final move in moves) {
      final undo = board.doMove(move.from, move.to);
      value = max(value, _minimax(board, depth - 1, alpha, beta, false));
      board.undoMove(undo);
      alpha = max(alpha, value);
      if (beta <= alpha) break;
    }
    return value;
  } else {
    double value = double.infinity;
    for (final move in moves) {
      final undo = board.doMove(move.from, move.to);
      value = min(value, _minimax(board, depth - 1, alpha, beta, true));
      board.undoMove(undo);
      beta = min(beta, value);
      if (beta <= alpha) break;
    }
    return value;
  }
}

// ============================================================
// 翻牌评估
// ============================================================

/// 评估翻牌收益：遍历暗棋位置，按概率加权选最优
GameAction? _evaluateFlip(_SearchBoard board) {
  if (board.cells.every((c) => c != _kHidden)) return null;

  final hiddenPositions = <int>[];
  for (int i = 0; i < board.cells.length; i++) {
    if (board.cells[i] == _kHidden) hiddenPositions.add(i);
  }
  if (hiddenPositions.isEmpty) return null;

  if (board.getVisiblePositions(true).isEmpty) {
    return FlipAction(
      hiddenPositions[Random().nextInt(hiddenPositions.length)],
    );
  }

  return _findBestFlipPosition(board, hiddenPositions);
}

/// 找到最佳翻牌位置
FlipAction _findBestFlipPosition(
  _SearchBoard board,
  List<int> hiddenPositions,
) {
  double bestScore = double.negativeInfinity;
  int bestPos = hiddenPositions.first;
  final totalHidden = hiddenPositions.length;
  final aiHiddenCount = board.aiHidden.length;
  final playerHiddenCount = board.playerHidden.length;

  for (final pos in hiddenPositions) {
    final avgScore = _evalFlipPositionAvg(
      board,
      pos,
      totalHidden,
      aiHiddenCount,
      playerHiddenCount,
    );
    if (avgScore > bestScore) {
      bestScore = avgScore;
      bestPos = pos;
    }
  }

  return FlipAction(bestPos);
}

/// 评估单个翻牌位置的平均收益
double _evalFlipPositionAvg(
  _SearchBoard board,
  int pos,
  int totalHidden,
  int aiHiddenCount,
  int playerHiddenCount,
) {
  double totalScore = 0;
  int count = 0;

  if (aiHiddenCount > 0) {
    final prob = aiHiddenCount / totalHidden;
    for (final type in board.aiHidden) {
      board.cells[pos] = type.index + 1;
      totalScore += _evalFlipPosition(board, pos, true) * prob;
      count++;
    }
    board.cells[pos] = _kHidden;
  }

  if (playerHiddenCount > 0) {
    final prob = playerHiddenCount / totalHidden;
    for (final type in board.playerHidden) {
      board.cells[pos] = -(type.index + 1);
      totalScore += _evalFlipPosition(board, pos, false) * prob;
      count++;
    }
    board.cells[pos] = _kHidden;
  }

  return count > 0 ? totalScore / count : 0;
}

/// 评估翻出棋子后的价值：AI 最佳走法 + 对手最差响应
double _evalFlipPosition(_SearchBoard board, int pos, bool isAiPiece) {
  final aiMoves = _generateMoves(board, true);
  double bestMoveScore = double.negativeInfinity;

  final limited = aiMoves.length > _FlipLimits.aiMoves
      ? aiMoves.sublist(0, _FlipLimits.aiMoves)
      : aiMoves;

  for (final move in limited) {
    final undo = board.doMove(move.from, move.to);
    bestMoveScore = max(bestMoveScore, _evaluate(board));
    board.undoMove(undo);
  }
  if (limited.isEmpty) bestMoveScore = 0;

  if (!isAiPiece) {
    final playerMoves = _generateMoves(board, false);
    double worstCase = double.infinity;
    final pLimited = playerMoves.length > _FlipLimits.playerMoves
        ? playerMoves.sublist(0, _FlipLimits.playerMoves)
        : playerMoves;
    for (final move in pLimited) {
      final undo = board.doMove(move.from, move.to);
      worstCase = min(worstCase, _evaluate(board));
      board.undoMove(undo);
    }
    if (pLimited.isEmpty) worstCase = 0;
    return (bestMoveScore + worstCase) / 2;
  }

  return bestMoveScore;
}

// ============================================================
// 日志
// ============================================================

void _log(String msg) => debugPrint('[AI] $msg');

String _posStr(int index, int size) => '(${index ~/ size},${index % size})';

String _actionStr(GameAction action) {
  if (action is FlipAction) return 'Flip(${action.index})';
  if (action is MoveAction) {
    return 'Move(${_posStr(action.from, 9)}->${_posStr(action.to, 9)})';
  }
  return action.toString();
}

/// 紧凑棋盘打印：AI 大写 / 玩家小写 / 暗棋 ? / 空 *
void _logBoard(
  String label,
  List<Grid> board,
  int size,
  TurnGamerType aiFaction,
) {
  final header = List.generate(size, (i) => i.toString().padLeft(2)).join();
  final sb = StringBuffer('  $header\n');

  for (int r = 0; r < size; r++) {
    sb.write('${r.toString().padLeft(2)} ');
    for (int c = 0; c < size; c++) {
      final grid = board[r * size + c];
      if (!grid.hasAnimal) {
        sb.write(' *');
      } else if (grid.animal!.isHidden) {
        sb.write(' ?');
      } else {
        final abbr = _kAbbr[grid.animal!.type.index];
        sb.write(
          grid.animal!.owner == aiFaction ? ' $abbr' : ' ${abbr.toLowerCase()}',
        );
      }
    }
    sb.writeln();
  }
  debugPrint('[AI] $label:\n$sb');
}

// ============================================================
// AiController — 公开 API
// ============================================================

class AiController {
  final List<Grid> board;
  final int boardSize;
  final TurnGamerType faction;

  /// AI 行动后棋盘快照（用于 Zobrist 学习）
  List<int>? _postAiCells;
  List<AnimalType>? _postAiAiHidden;
  List<AnimalType>? _postAiPlayerHidden;

  AiController({
    required this.board,
    required this.boardSize,
    required this.faction,
  });

  /// AI 决策入口
  GameAction? getAction() {
    _logBoard('Before', board, boardSize, faction);

    final searchBoard = _SearchBoard.fromGrid(board, boardSize, faction);
    final zobrist = _ZobristTable.instance;

    final action = _searchBestMove(searchBoard, zobrist);
    if (action == null) {
      _log('No action available');
      return null;
    }

    zobrist.store(
      action,
      searchBoard.cells,
      boardSize,
      searchBoard.aiHidden,
      searchBoard.playerHidden,
    );

    _applyAction(action);
    _savePostAiState(searchBoard, action);
    _log('Decision: ${_actionStr(action)}');

    _logBoard('After', board, boardSize, faction);

    return action;
  }

  /// 玩家行动后调用，用于更新棋盘和 Zobrist 学习
  void applyPlayerAction(GameAction action) {
    _applyAction(action);
    _log('Player: ${_actionStr(action)}');

    if (_postAiCells != null) {
      _ZobristTable.instance.store(
        action,
        _postAiCells!,
        boardSize,
        _postAiAiHidden!,
        _postAiPlayerHidden!,
      );

      _postAiCells = null;
      _postAiAiHidden = null;
      _postAiPlayerHidden = null;
    }
  }

  void dispose() {
    _postAiCells = null;
    _postAiAiHidden = null;
    _postAiPlayerHidden = null;
  }

  /// 应用行动到内部棋盘
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
          final attackerWins = _canEatType(moving.type, toGrid.animal!.type);
          final defenderWins = _canEatType(toGrid.animal!.type, moving.type);
          if (attackerWins && defenderWins) {
            toGrid.animal = null; // 同归于尽
          } else if (attackerWins) {
            toGrid.animal = moving; // 攻方胜
          }
        } else {
          toGrid.animal = moving;
        }
        fromGrid.animal = null;
      }
    }
  }

  /// 保存 AI 行动后快照（仅 MoveAction 可完整还原）
  void _savePostAiState(_SearchBoard board, GameAction action) {
    if (action is MoveAction) {
      final postBoard = _SearchBoard._(
        board.size,
        List<GridType>.from(board.terrain),
        List<int>.from(board.cells),
        board.aiFaction,
        board.aiPositions.map((k, v) => MapEntry(k, List<int>.from(v))),
        board.playerPositions.map((k, v) => MapEntry(k, List<int>.from(v))),
        List<AnimalType>.from(board.aiHidden),
        List<AnimalType>.from(board.playerHidden),
      );
      postBoard.doMove(action.from, action.to);
      _postAiCells = postBoard.cells;
      _postAiAiHidden = postBoard.aiHidden;
      _postAiPlayerHidden = postBoard.playerHidden;
    } else {
      _postAiCells = null;
    }
  }
}
