import 'dart:math';
import 'package:flutter/foundation.dart';
import '../00.common/game/gamer.dart';
import 'base.dart';

// ============================================================
// Constants
// ============================================================

const int _kHidden = 999;
const int _kSearchDepth = 4;

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

/// 动物缩写：E=象 T=虎 L=狮 P=豹 W=狼 D=狗 C=猫 M=鼠
const List<String> _kAbbr = ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'];

const List<(int, int)> _kDirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

// ============================================================
// Helpers
// ============================================================

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
    GridType.river => [
      AnimalType.elephant,
      AnimalType.dog,
      AnimalType.mouse,
    ].contains(type),
    GridType.bridge =>
      from == GridType.river
          ? type == AnimalType.mouse
          : type != AnimalType.elephant,
    GridType.tree => [
      AnimalType.leopard,
      AnimalType.cat,
      AnimalType.mouse,
    ].contains(type),
    _ => true,
  };
}

int _cellAnimalType(int cell) => cell.abs() - 1;

bool _isAiCell(int cell) => cell > 0 && cell != _kHidden;

bool _isPlayerCell(int cell) => cell < 0;

// ============================================================
// MoveRecord — 用于 minimax 撤销
// ============================================================

class _MoveRecord {
  final int from, to;
  final int movingPiece, targetPiece;
  const _MoveRecord(this.from, this.to, this.movingPiece, this.targetPiece);
}

// ============================================================
// SearchBoard — 可变棋盘，用于搜索
// ============================================================

class _SearchBoard {
  final int size;
  final List<GridType> gridTypes;
  final List<int> cells;
  final TurnGamerType aiFaction;
  final List<AnimalType> aiHidden;
  final List<AnimalType> playerHidden;

  _SearchBoard._(
    this.size,
    this.gridTypes,
    this.cells,
    this.aiFaction,
    this.aiHidden,
    this.playerHidden,
  );

  factory _SearchBoard.fromGrid(
    List<Grid> board,
    int size,
    TurnGamerType aiFaction,
  ) {
    final cells = List<int>.filled(size * size, 0);
    final gridTypes = List<GridType>.filled(size * size, GridType.land);
    final aiVisible = <AnimalType>{};
    final playerVisible = <AnimalType>{};

    for (int i = 0; i < board.length; i++) {
      final grid = board[i];
      gridTypes[i] = grid.type;

      if (!grid.hasAnimal) {
        cells[i] = 0;
      } else if (grid.animal!.isHidden) {
        cells[i] = _kHidden;
      } else if (grid.animal!.owner == aiFaction) {
        cells[i] = grid.animal!.type.index + 1;
        aiVisible.add(grid.animal!.type);
      } else {
        cells[i] = -(grid.animal!.type.index + 1);
        playerVisible.add(grid.animal!.type);
      }
    }

    final allTypes = AnimalType.values.toSet();
    final aiHidden = (allTypes.difference(aiVisible)).toList()
      ..sort((a, b) => b.index.compareTo(a.index));
    final playerHidden = (allTypes.difference(playerVisible)).toList()
      ..sort((a, b) => b.index.compareTo(a.index));

    return _SearchBoard._(
      size,
      gridTypes,
      cells,
      aiFaction,
      aiHidden,
      playerHidden,
    );
  }

  /// 执行移动，返回撤销记录
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
      // 否则守方胜，cells[to] 不变
    }

    return _MoveRecord(from, to, moving, target);
  }

  /// 撤销移动
  void undoMove(_MoveRecord record) {
    cells[record.from] = record.movingPiece;
    cells[record.to] = record.targetPiece;
  }

  /// 获取指定阵营所有可见棋子位置
  List<int> getVisiblePositions(bool isAi) {
    final positions = <int>[];
    for (int i = 0; i < cells.length; i++) {
      final c = cells[i];
      if (isAi && c > 0 && c != _kHidden) positions.add(i);
      if (!isAi && c < 0) positions.add(i);
    }
    return positions;
  }
}

// ============================================================
// ZobristTable — 哈希缓存单例（含四重对称）
// ============================================================

class _ZobristTable {
  static final instance = _ZobristTable._();

  static const _maxCells = 169; // 13x13
  static const _numCodes = 18; // 0=空, 1-8=AI, 9-16=玩家, 17=暗棋
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

  int _cellToCode(int cell) {
    if (cell == 0) return 0;
    if (cell == _kHidden) return 17;
    if (cell > 0) return cell; // 1-8
    return -cell + 8; // -1→9, -2→10, ..., -8→16
  }

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

  // --- 对称变换 ---

  static int _id(int i, int n) => i;
  static int _hm(int i, int n) => (i ~/ n) * n + (n - 1 - i % n);
  static int _vm(int i, int n) => (n - 1 - i ~/ n) * n + (i % n);
  static int _r180(int i, int n) => (n - 1 - i ~/ n) * n + (n - 1 - i % n);

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
// Evaluation — 评估函数
// ============================================================

double _evaluate(_SearchBoard board) {
  // 终局检测
  bool hasAi = false, hasPlayer = false;
  for (final c in board.cells) {
    if (_isAiCell(c)) hasAi = true;
    if (_isPlayerCell(c)) hasPlayer = true;
    if (hasAi && hasPlayer) break;
  }
  if (!hasAi) return -100000;
  if (!hasPlayer) return 100000;

  return _evalMaterial(board) + _evalSituation(board) + _evalMobility(board);
}

/// 材料分 —— 动态分值（只扣分 + 14转正）
/// 每个可见棋子: score = (14 - penalty) * coeff
///   penalty = Σ(能吃你的敌方棋子基础分), 同归于尽扣一半
/// 暗棋: 位置未知，使用基础分
double _evalMaterial(_SearchBoard board) {
  const kScoreBase = 14; // 所有基础分之和: 3+1+2+2+1+2+1+2
  const kCoeff = 1.0;

  // 收集各方可见/隐藏棋子类型
  final aiVisible = <int, AnimalType>{};
  final playerVisible = <int, AnimalType>{};
  for (int i = 0; i < board.cells.length; i++) {
    final c = board.cells[i];
    if (_isAiCell(c)) {
      aiVisible[i] = AnimalType.values[_cellAnimalType(c)];
    } else if (_isPlayerCell(c)) {
      playerVisible[i] = AnimalType.values[_cellAnimalType(c)];
    }
  }

  // 收集各方所有存活棋子类型（用于威胁评估）
  final aiSurviving = <AnimalType>{};
  final playerSurviving = <AnimalType>{};
  for (final c in board.cells) {
    if (_isAiCell(c)) aiSurviving.add(AnimalType.values[_cellAnimalType(c)]);
    if (_isPlayerCell(c)) {
      playerSurviving.add(AnimalType.values[_cellAnimalType(c)]);
    }
  }
  aiSurviving.addAll(board.aiHidden);
  playerSurviving.addAll(board.playerHidden);

  // --- AI 方动态分 ---
  double aiScore = 0;
  for (final type in aiVisible.values) {
    int penalty = 0;
    for (final enemy in playerSurviving) {
      final eats = _canEatType(enemy, type);
      final mutual = _canEatType(type, enemy);
      if (eats && mutual) {
        penalty += (_baseScores[enemy]! / 2).round(); // 同归于尽扣一半
      } else if (eats) {
        penalty += _baseScores[enemy]!;
      }
    }
    aiScore += (kScoreBase - penalty) * kCoeff;
  }
  // 暗棋用基础分
  for (final t in board.aiHidden) {
    aiScore += _baseScores[t]!.toDouble();
  }

  // --- 玩家方动态分 ---
  double playerScore = 0;
  for (final type in playerVisible.values) {
    int penalty = 0;
    for (final enemy in aiSurviving) {
      final eats = _canEatType(enemy, type);
      final mutual = _canEatType(type, enemy);
      if (eats && mutual) {
        penalty += (_baseScores[enemy]! / 2).round();
      } else if (eats) {
        penalty += _baseScores[enemy]!;
      }
    }
    playerScore += (kScoreBase - penalty) * kCoeff;
  }
  // 暗棋用基础分
  for (final t in board.playerHidden) {
    playerScore += _baseScores[t]!.toDouble();
  }

  return aiScore - playerScore;
}

/// 局势分 —— 威胁、固守、特殊地形加成
double _evalSituation(_SearchBoard board) {
  double score = 0;
  final n = board.size;

  // 收集存活类型
  final aiSurviving = <AnimalType>{};
  final playerSurviving = <AnimalType>{};
  for (final c in board.cells) {
    if (_isAiCell(c)) aiSurviving.add(AnimalType.values[_cellAnimalType(c)]);
    if (_isPlayerCell(c)) {
      playerSurviving.add(AnimalType.values[_cellAnimalType(c)]);
    }
  }
  aiSurviving.addAll(board.aiHidden);
  playerSurviving.addAll(board.playerHidden);

  for (int i = 0; i < board.cells.length; i++) {
    final c = board.cells[i];
    if (c == 0 || c == _kHidden) continue;

    final isAi = _isAiCell(c);
    final type = AnimalType.values[_cellAnimalType(c)];
    final terrain = board.gridTypes[i];
    final r = i ~/ n;
    final col = i % n;

    int threats = 0;
    int threatens = 0;
    double hiddenThreat = 0; // 暗棋潜在威胁（暗棋一定在陆地，可为任意动物）

    final enemyHidden = isAi ? board.playerHidden : board.aiHidden;

    for (final (dr, dc) in _kDirs) {
      final nr = r + dr;
      final nc = col + dc;
      if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
      final adj = board.cells[nr * n + nc];
      if (adj == 0) continue;

      // 暗棋：陆地上可为任意剩余类型，评估潜在威胁
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

    double pieceScore = (threatens - threats) * 0.5 - hiddenThreat * 0.3;

    // 固守加分
    if (terrain == GridType.tree &&
        [AnimalType.leopard, AnimalType.cat, AnimalType.mouse].contains(type)) {
      pieceScore += 2.0;
      // 豹子上树且对方豹子已死 → 无敌
      if (type == AnimalType.leopard) {
        final enemyTypes = isAi ? playerSurviving : aiSurviving;
        if (!enemyTypes.contains(AnimalType.leopard)) {
          pieceScore += 5.0;
        }
      }
    }

    // 老虎上桥
    if (type == AnimalType.tiger && terrain == GridType.bridge) {
      pieceScore += 2.0;
    }

    score += isAi ? pieceScore : -pieceScore;
  }

  return score;
}

/// 机动性 —— 可选移动数量差
double _evalMobility(_SearchBoard board) {
  final aiMoves = _generateMoves(board, true);
  final playerMoves = _generateMoves(board, false);
  return (aiMoves.length - playerMoves.length) * 0.1;
}

// ============================================================
// Move Generation — 走法生成
// ============================================================

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

    for (final (dr, dc) in _kDirs) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;

      final ni = nr * n + nc;
      final target = board.cells[ni];

      // 暗棋是障碍物
      if (target == _kHidden) continue;
      // 不能走向己方棋子
      if (target != 0 && _isAiCell(target) == isAi) continue;
      // 地形检测
      if (!_canEnterTerrain(type, board.gridTypes[i], board.gridTypes[ni])) {
        continue;
      }

      moves.add(MoveAction(i, ni));
    }
  }

  // 走法排序：吃子优先（吃高价值子在前）
  moves.sort((a, b) {
    final aVal = board.cells[a.to] != 0 && board.cells[a.to] != _kHidden
        ? _baseScores[AnimalType.values[_cellAnimalType(board.cells[a.to])]]!
        : 0;
    final bVal = board.cells[b.to] != 0 && board.cells[b.to] != _kHidden
        ? _baseScores[AnimalType.values[_cellAnimalType(board.cells[b.to])]]!
        : 0;
    return bVal.compareTo(aVal);
  });

  return moves;
}

// ============================================================
// Search Engine — Minimax + Alpha-Beta
// ============================================================

GameAction? _searchBestMove(_SearchBoard board, _ZobristTable zobrist) {
  // 1. 查 Zobrist 缓存
  final cached = zobrist.lookup(
    board.cells,
    board.size,
    board.aiHidden,
    board.playerHidden,
  );
  if (cached != null) {
    _log('Zobrist 缓存命中');
    return cached;
  }

  // 2. 生成所有 AI 走法
  final moves = _generateMoves(board, true);
  _log('可移动走法数: ${moves.length}');

  if (moves.isEmpty) {
    // 无可移动棋子 → 翻牌
    return _evaluateFlip(board);
  }

  // 3. 快速静态评估筛选：找出能改善局势的移动
  final currentEval = _evaluate(board);
  final improvingMoves = <(MoveAction, double)>[];

  for (final move in moves) {
    final undo = board.doMove(move.from, move.to);
    final staticEval = _evaluate(board);
    board.undoMove(undo);

    _log(
      '  Move ${_posStr(move.from, board.size)}→${_posStr(move.to, board.size)} '
      'static=${staticEval.toStringAsFixed(1)}',
    );

    if (staticEval > currentEval) {
      improvingMoves.add((move, staticEval));
    }
  }

  // 4. 没有改善局势的移动 → 翻牌
  if (improvingMoves.isEmpty) {
    _log('无改善移动(当前${currentEval.toStringAsFixed(1)}), 尝试翻牌');
    final flip = _evaluateFlip(board);
    if (flip != null) return flip;
    // 无牌可翻，走 minimax 最佳（必走）
  }

  // 5. 有改善移动 → 用 minimax 深度搜索选最优
  if (improvingMoves.isNotEmpty) {
    // 按静态评估排序，优先搜索收益大的
    improvingMoves.sort((a, b) => b.$2.compareTo(a.$2));

    double bestScore = double.negativeInfinity;
    MoveAction? bestMove;

    for (final (move, _) in improvingMoves) {
      final undo = board.doMove(move.from, move.to);
      final score = _minimax(
        board,
        _kSearchDepth - 1,
        double.negativeInfinity,
        double.infinity,
        false,
      );
      board.undoMove(undo);

      _log(
        '  Minimax ${_posStr(move.from, board.size)}→${_posStr(move.to, board.size)} '
        'score=${score.toStringAsFixed(1)}',
      );

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  // 6. 兜底：无改善移动且无牌可翻，minimax 选最不差的
  double bestScore = double.negativeInfinity;
  MoveAction? bestMove;
  for (final move in moves) {
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

double _minimax(
  _SearchBoard board,
  int depth,
  double alpha,
  double beta,
  bool isMax,
) {
  if (depth == 0) return _evaluate(board);

  final moves = _generateMoves(board, isMax);

  if (moves.isEmpty) {
    return _evaluate(board);
  }

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
// Flip Evaluation — 翻牌决策
// ============================================================

GameAction? _evaluateFlip(_SearchBoard board) {
  if (board.cells.every((c) => c != _kHidden)) return null;

  // 收集所有暗棋位置
  final hiddenPositions = <int>[];
  // 需要原始 board 来判断暗棋归属
  // 由于 SearchBoard 不区分暗棋阵营，这里做简化处理：
  // AI 的暗棋列表和玩家的暗棋列表长度已知
  for (int i = 0; i < board.cells.length; i++) {
    if (board.cells[i] == _kHidden) hiddenPositions.add(i);
  }

  if (hiddenPositions.isEmpty) return null;

  // 无可见棋子 → 随机翻
  if (board.getVisiblePositions(true).isEmpty) {
    return FlipAction(
      hiddenPositions[Random().nextInt(hiddenPositions.length)],
    );
  }

  // 评估每个暗棋位置的翻牌收益
  double bestScore = double.negativeInfinity;
  int bestPos = hiddenPositions.first;

  // 假设每个暗棋位置等概率属于 AI 或玩家
  // 根据剩余暗棋数量估算概率
  final totalHidden = hiddenPositions.length;
  final aiHiddenCount = board.aiHidden.length;
  final playerHiddenCount = board.playerHidden.length;

  for (final pos in hiddenPositions) {
    double totalScore = 0;
    int count = 0;

    // 尝试作为 AI 暗棋
    if (aiHiddenCount > 0) {
      final prob = aiHiddenCount / totalHidden;
      for (final type in board.aiHidden) {
        board.cells[pos] = type.index + 1; // AI 棋子
        final score = _evalFlipPosition(board, pos, true);
        totalScore += score * prob;
        count++;
      }
      board.cells[pos] = _kHidden;
    }

    // 尝试作为玩家暗棋
    if (playerHiddenCount > 0) {
      final prob = playerHiddenCount / totalHidden;
      for (final type in board.playerHidden) {
        board.cells[pos] = -(type.index + 1); // 玩家棋子
        final score = _evalFlipPosition(board, pos, false);
        totalScore += score * prob;
        count++;
      }
      board.cells[pos] = _kHidden;
    }

    if (count > 0) {
      final avgScore = totalScore / count;
      if (avgScore > bestScore) {
        bestScore = avgScore;
        bestPos = pos;
      }
    }
  }

  return FlipAction(bestPos);
}

/// 评估翻出某棋子后的一步最佳走法价值
double _evalFlipPosition(_SearchBoard board, int pos, bool isAiPiece) {
  // 基础评估
  double baseEval = _evaluate(board);

  // 模拟翻牌后走一步
  final moves = _generateMoves(board, true);
  double bestMoveScore = double.negativeInfinity;

  // 限制评估数量以保证性能
  final limited = moves.length > 12 ? moves.sublist(0, 12) : moves;
  for (final move in limited) {
    final undo = board.doMove(move.from, move.to);
    final score = _evaluate(board);
    board.undoMove(undo);
    bestMoveScore = max(bestMoveScore, score);
  }

  if (limited.isEmpty) bestMoveScore = baseEval;

  // 如果翻出的是对方棋子，还需考虑对方是否会利用
  if (!isAiPiece) {
    final playerMoves = _generateMoves(board, false);
    double worstCase = double.infinity;
    final pLimited = playerMoves.length > 8
        ? playerMoves.sublist(0, 8)
        : playerMoves;
    for (final move in pLimited) {
      final undo = board.doMove(move.from, move.to);
      final score = _evaluate(board);
      board.undoMove(undo);
      worstCase = min(worstCase, score);
    }
    if (pLimited.isEmpty) worstCase = baseEval;
    return (bestMoveScore + worstCase) / 2;
  }

  return bestMoveScore;
}

// ============================================================
// Logger — 日志系统
// ============================================================

void _log(String msg) {
  debugPrint('[AI] $msg');
}

String _posStr(int index, int size) {
  final r = index ~/ size;
  final c = index % size;
  return '($r,$c)';
}

/// 打印棋盘文字版
/// AI 大写 / 玩家小写 / 暗棋 ? / 空 *
void _logBoard(
  String label,
  List<Grid> board,
  int size,
  TurnGamerType aiFaction,
) {
  final sb = StringBuffer();
  sb.writeln('┌${'───┬' * (size - 1)}───┐');

  for (int r = 0; r < size; r++) {
    sb.write('│');
    for (int c = 0; c < size; c++) {
      final grid = board[r * size + c];
      String ch;
      if (!grid.hasAnimal) {
        ch = ' * ';
      } else if (grid.animal!.isHidden) {
        ch = ' ? ';
      } else {
        final abbr = _kAbbr[grid.animal!.type.index];
        ch = grid.animal!.owner == aiFaction
            ? ' $abbr '
            : ' ${abbr.toLowerCase()} ';
      }
      sb.write('$ch│');
    }
    sb.writeln();
    if (r < size - 1) {
      sb.writeln('├${'───┼' * (size - 1)}───┤');
    }
  }

  sb.writeln('└${'───┴' * (size - 1)}───┘');
  debugPrint('[AI] $label:\n$sb');
} // ignore: unnecessary_brace_in_string_interps

String _actionStr(GameAction action) {
  if (action is FlipAction) {
    return '翻牌(${action.index})'; // ignore: unnecessary_brace_in_string_interps
  }
  if (action is MoveAction) {
    return '移动(${action.from}→${action.to})'; // ignore: unnecessary_brace_in_string_interps
  }
  return action.toString();
}

// ============================================================
// AiController — 公开 API
// ============================================================

class AiController {
  final int boardSize;
  final TurnGamerType faction;

  /// 缓存的 AI 行动后棋盘快照（用于 Zobrist 学习）
  List<int>? _postAiCells;
  List<AnimalType>? _postAiAiHidden;
  List<AnimalType>? _postAiPlayerHidden;

  AiController({
    required List<Grid> board,
    required this.boardSize,
    required this.faction,
  });

  /// AI 决策入口
  GameAction getAction(List<Grid> board) {
    _logBoard('决策前棋盘', board, boardSize, faction);

    final searchBoard = _SearchBoard.fromGrid(board, boardSize, faction);
    final zobrist = _ZobristTable.instance;

    // 搜索
    final action = _searchBestMove(searchBoard, zobrist);
    if (action == null) {
      _log('无可用行动');
      return FlipAction(_findFirstHidden(board));
    }

    // 存入 Zobrist（四重对称）
    zobrist.store(
      action,
      searchBoard.cells,
      boardSize,
      searchBoard.aiHidden,
      searchBoard.playerHidden,
    );

    // 保存行动后快照（用于 Zobrist 学习）
    _savePostAiState(searchBoard, action);

    _log('最终决策: ${_actionStr(action)}');

    // 构建行动后棋盘用于日志
    final postBoard = _applyActionForLog(board, action);
    _logBoard('决策后棋盘', postBoard, boardSize, faction);

    return action;
  }

  /// 玩家行动后调用，用于 Zobrist 学习
  void updateState(GameAction action) {
    if (_postAiCells == null) return;

    _log('玩家行为: ${_actionStr(action)}');

    // 把玩家行动作为"最优解"存入 Zobrist
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

  void dispose() {
    _postAiCells = null;
    _postAiAiHidden = null;
    _postAiPlayerHidden = null;
  }

  /// 保存 AI 行动后的快照（仅 MoveAction 可完整还原）
  void _savePostAiState(_SearchBoard board, GameAction action) {
    if (action is MoveAction) {
      final postBoard = _SearchBoard._(
        board.size,
        List<GridType>.from(board.gridTypes),
        List<int>.from(board.cells),
        board.aiFaction,
        List<AnimalType>.from(board.aiHidden),
        List<AnimalType>.from(board.playerHidden),
      );
      postBoard.doMove(action.from, action.to);
      _postAiCells = postBoard.cells;
      _postAiAiHidden = postBoard.aiHidden;
      _postAiPlayerHidden = postBoard.playerHidden;
    } else {
      // FlipAction 无法确定翻出的具体棋子，跳过学习
      _postAiCells = null;
    }
  }

  int _findFirstHidden(List<Grid> board) {
    for (int i = 0; i < board.length; i++) {
      if (board[i].hasAnimal && board[i].animal!.isHidden) return i;
    }
    return 0;
  }

  /// 根据行动克隆棋盘并模拟执行，用于日志显示
  List<Grid> _applyActionForLog(List<Grid> board, GameAction action) {
    final post = board.map((g) => g.clone()).toList();
    if (action is FlipAction) {
      final grid = post[action.index];
      if (grid.hasAnimal) {
        grid.animal!.isHidden = false;
      }
    } else if (action is MoveAction) {
      final fromGrid = post[action.from];
      final toGrid = post[action.to];
      final moving = fromGrid.animal;
      if (moving != null) {
        if (toGrid.hasAnimal && toGrid.animal!.owner != moving.owner) {
          // 战斗：同归于尽或吃子
          final attackerWins = _canEatType(moving.type, toGrid.animal!.type);
          final defenderWins = _canEatType(toGrid.animal!.type, moving.type);
          if (attackerWins && defenderWins) {
            toGrid.animal = null;
          } else if (attackerWins) {
            toGrid.animal = moving;
          }
          // 守方胜则 toGrid 不变
        } else {
          toGrid.animal = moving;
        }
        fromGrid.animal = null;
      }
    }
    return post;
  }
}
