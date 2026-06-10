import 'dart:math';
import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import 'base.dart';

enum AiDifficulty { easy, medium, hard }

/// Zobrist 哈希
class Zobrist {
  static final Random _rand = Random();
  static late Map<TurnGamerType, Map<int, int>> playerPiece;
  static late Map<int, int> flipHash;
  static late int turnHash;
  static int _lastBoardSize = 0;

  static void init(int boardSize) {
    if (_lastBoardSize == boardSize) return;
    _lastBoardSize = boardSize;

    playerPiece = {TurnGamerType.front: {}, TurnGamerType.rear: {}};
    flipHash = {};

    for (int i = 0; i < boardSize * boardSize; i++) {
      flipHash[i] = _rand64();
      playerPiece[TurnGamerType.front]![i] = _rand64();
      playerPiece[TurnGamerType.rear]![i] = _rand64();
    }
    turnHash = _rand64();
  }

  static int _rand64() =>
      (_rand.nextInt(1 << 30) << 30) | _rand.nextInt(1 << 30);
}

/// 置换表节点
class TTEntry {
  final double score;
  final int depth;
  final int flag; // 0=EXACT, 1=LOWERBOUND, 2=UPPERBOUND
  TTEntry(this.score, this.depth, this.flag);
}

const int ttExact = 0;
const int ttLowerBound = 1;
const int ttUpperBound = 2;

class TranspositionTable {
  final Map<int, TTEntry> _table = {};
  void put(int key, double score, int depth, int flag) {
    final existing = _table[key];
    if (existing == null || existing.depth <= depth) {
      _table[key] = TTEntry(score, depth, flag);
    }
  }

  TTEntry? get(int key) => _table[key];
  void clear() => _table.clear();
}

// ==================== 核心状态转换函数 ====================
/// 应用移动操作，返回新的格子列表、红方剩余数量、蓝方剩余数量
(List<Grid>, int, int) _applyMoveToGrids(
  List<Grid> grids,
  MoveAction action,
  int redCount,
  int blueCount,
) {
  final newGrids = grids.map((g) => g.clone()).toList();
  int newRed = redCount;
  int newBlue = blueCount;

  final fromGrid = newGrids[action.from];
  final toGrid = newGrids[action.to];
  final attacker = fromGrid.animal!;

  newGrids[action.from] = fromGrid..animal = null;

  if (toGrid.hasAnimal) {
    final defender = toGrid.animal!;
    final aWin = attacker.canEat(defender);
    final dWin = defender.canEat(attacker);

    if (aWin && dWin) {
      // 同归于尽
      newGrids[action.to] = toGrid..animal = null;
      if (attacker.owner == TurnGamerType.front) {
        newRed--;
      } else {
        newBlue--;
      }
      if (defender.owner == TurnGamerType.front) {
        newRed--;
      } else {
        newBlue--;
      }
    } else if (aWin) {
      // 攻击方吃掉防守方
      newGrids[action.to] = toGrid..animal = attacker;
      if (defender.owner == TurnGamerType.front) {
        newRed--;
      } else {
        newBlue--;
      }
    } else if (dWin) {
      // 攻击方被反杀
      if (attacker.owner == TurnGamerType.front) {
        newRed--;
      } else {
        newBlue--;
      }
    } else {
      throw StateError('Invalid move: cannot eat $attacker -> $defender');
    }
  } else {
    newGrids[action.to] = toGrid..animal = attacker;
  }

  return (newGrids, newRed, newBlue);
}

/// 应用翻开操作，返回新的格子列表、红方剩余数量、蓝方剩余数量
(List<Grid>, int, int) _applyFlipToGrids(
  List<Grid> grids,
  FlipAction action,
  int redCount,
  int blueCount,
) {
  final newGrids = grids.map((g) => g.clone()).toList();
  int newRed = redCount;
  int newBlue = blueCount;

  final oldGrid = newGrids[action.index];
  final animal = oldGrid.animal!;
  final revealedAnimal = animal..isHidden = false;
  newGrids[action.index] = oldGrid..animal = revealedAnimal;

  if (animal.owner == TurnGamerType.front) {
    newRed++;
  } else {
    newBlue++;
  }
  return (newGrids, newRed, newBlue);
}

// ==================== 棋盘快照 ====================
class BoardSnapshot {
  final List<Grid> gridList;
  final int size;
  final TurnGamerType currentTurn;
  final int _redCount; // 缓存，避免每次遍历
  final int _blueCount;
  final List<int> _hiddenPositions; // 缓存
  late final int hash;

  int get redCount => _redCount;
  int get blueCount => _blueCount;
  List<int> get hiddenPositions => _hiddenPositions;

  BoardSnapshot._({
    required this.gridList,
    required this.size,
    required this.currentTurn,
    required int redCount,
    required int blueCount,
    required List<int> hiddenPositions,
  }) : _redCount = redCount,
       _blueCount = blueCount,
       _hiddenPositions = hiddenPositions {
    hash = _computeHash();
  }

  factory BoardSnapshot.fromBoard({
    required List<Grid> board,
    required int size,
    required TurnGamerType currentTurn,
  }) {
    final List<Grid> newGrids = [];
    final hiddenPos = <int>[];
    int red = 0, blue = 0;
    for (int i = 0; i < board.length; i++) {
      final g = board[i];
      newGrids.add(g.clone());
      if (g.hasAnimal) {
        final a = g.animal!;
        if (a.isHidden) {
          hiddenPos.add(i);
        } else {
          if (a.owner == TurnGamerType.front) red++;
          if (a.owner == TurnGamerType.rear) blue++;
        }
      }
    }
    return BoardSnapshot._(
      gridList: newGrids,
      size: size,
      currentTurn: currentTurn,
      redCount: red,
      blueCount: blue,
      hiddenPositions: hiddenPos,
    );
  }

  int _computeHash() {
    int h = 0;
    for (int i = 0; i < gridList.length; i++) {
      final grid = gridList[i];
      if (!grid.hasAnimal) continue;
      final animal = grid.animal!;
      if (animal.isHidden) continue;
      h ^= Zobrist.playerPiece[animal.owner]![i] ?? 0;
    }
    for (final i in _hiddenPositions) {
      h ^= Zobrist.flipHash[i] ?? 0;
    }
    if (currentTurn == TurnGamerType.rear) {
      h ^= Zobrist.turnHash;
    }
    return h;
  }

  BoardSnapshot applyAction(GameAction action) {
    final (newGrids, newRed, newBlue) = switch (action) {
      FlipAction _ => _applyFlipToGrids(
        gridList,
        action,
        _redCount,
        _blueCount,
      ),
      MoveAction _ => _applyMoveToGrids(
        gridList,
        action,
        _redCount,
        _blueCount,
      ),
    };

    // 增量更新隐藏位置：翻棋减少一个，移动不变
    final List<int> newHidden;
    if (action is FlipAction) {
      newHidden = List.from(_hiddenPositions)..remove(action.index);
    } else {
      newHidden = _hiddenPositions; // 移动不改变暗子，直接复用
    }

    return BoardSnapshot._(
      gridList: newGrids,
      size: size,
      currentTurn: currentTurn.opponent,
      redCount: newRed,
      blueCount: newBlue,
      hiddenPositions: newHidden,
    );
  }

  List<int> getRevealedIndices(TurnGamerType player) {
    final res = <int>[];
    for (int i = 0; i < gridList.length; i++) {
      final g = gridList[i];
      if (g.hasAnimal && !g.animal!.isHidden && g.animal!.owner == player) {
        res.add(i);
      }
    }
    return res;
  }

  List<GameAction> generateMoves(TurnGamerType player) {
    final moves = <GameAction>[];
    for (final i in _hiddenPositions) {
      moves.add(FlipAction(i));
    }
    final own = getRevealedIndices(player);
    for (final from in own) {
      final animal = gridList[from].animal!;
      final r = from ~/ size;
      final c = from % size;
      for (final (dr, dc) in planeAround) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final to = nr * size + nc;
        final toGrid = gridList[to];
        if (toGrid.hasAnimal &&
            !toGrid.animal!.isHidden &&
            toGrid.animal!.owner == player) {
          continue;
        }
        if (toGrid.hasAnimal && !toGrid.animal!.isHidden) {
          if (!animal.canEat(toGrid.animal!)) continue;
        }
        if (toGrid.hasAnimal && toGrid.animal!.isHidden) continue;
        if (!animal.canMoveTo(gridList[from].type, toGrid.type)) continue;
        moves.add(MoveAction(from, to));
      }
    }
    return moves;
  }

  /// 快速统计可走步数（不分配 [GameAction] 对象），供评估函数使用
  int mobilityCount(TurnGamerType player) {
    int count = _hiddenPositions.length;
    final own = getRevealedIndices(player);
    for (final from in own) {
      final animal = gridList[from].animal!;
      final r = from ~/ size;
      final c = from % size;
      for (final (dr, dc) in planeAround) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final to = nr * size + nc;
        final toGrid = gridList[to];
        if (toGrid.hasAnimal &&
            !toGrid.animal!.isHidden &&
            toGrid.animal!.owner == player) {
          continue;
        }
        if (toGrid.hasAnimal && !toGrid.animal!.isHidden) {
          if (!animal.canEat(toGrid.animal!)) continue;
        }
        if (toGrid.hasAnimal && toGrid.animal!.isHidden) continue;
        if (!animal.canMoveTo(gridList[from].type, toGrid.type)) continue;
        count++;
      }
    }
    return count;
  }

  bool get isGameOver => _redCount <= 0 || _blueCount <= 0;
}

/// 配置
const Map<AnimalType, int> pieceValues = {
  AnimalType.elephant: 10,
  AnimalType.tiger: 10,
  AnimalType.lion: 9,
  AnimalType.leopard: 7,
  AnimalType.wolf: 5,
  AnimalType.dog: 5,
  AnimalType.cat: 4,
  AnimalType.mouse: 5,
};

/// AI 引擎
class AiEngine {
  final AiDifficulty difficulty;
  final Random _random = Random();
  final TranspositionTable _tt = TranspositionTable();
  final List<int> _historyHashes = [];

  static const int _quiescenceDepthLimit = 4;

  AiEngine({this.difficulty = AiDifficulty.hard});

  void recordHash(int hash) {
    _historyHashes.add(hash);
    if (_historyHashes.length > 10) _historyHashes.removeAt(0);
  }

  void clear() {
    _tt.clear();
    _historyHashes.clear();
  }

  GameAction? getBestMove(BoardSnapshot snap) {
    final moves = snap.generateMoves(snap.currentTurn)..shuffle(_random);
    if (moves.isEmpty) return null;
    _tt.clear();

    switch (difficulty) {
      case AiDifficulty.easy:
        return _easyMove(snap, moves);
      case AiDifficulty.medium:
        return _mediumMove(snap, moves);
      case AiDifficulty.hard:
        return _iterativeDeepening(snap, moves);
    }
  }

  GameAction _easyMove(BoardSnapshot snap, List<GameAction> moves) {
    final captures = <GameAction>[];
    for (final m in moves) {
      if (m is MoveAction) {
        final t = snap.gridList[m.to];
        if (t.hasAnimal &&
            t.animal!.owner != snap.currentTurn &&
            !t.animal!.isHidden) {
          captures.add(m);
        }
      }
    }
    if (captures.isNotEmpty) return captures[_random.nextInt(captures.length)];
    return moves[_random.nextInt(moves.length)];
  }

  GameAction _mediumMove(BoardSnapshot snap, List<GameAction> moves) {
    GameAction? best;
    double maxScore = -double.infinity;
    for (final m in moves) {
      final score = _evaluate(snap.applyAction(m), snap.currentTurn);
      if (score > maxScore) {
        maxScore = score;
        best = m;
      }
    }
    return best ?? moves.first;
  }

  GameAction _iterativeDeepening(BoardSnapshot snap, List<GameAction> moves) {
    _orderMoves(snap, moves);
    GameAction? bestMove;
    // 从深度 1 到 4 迭代加深
    for (int depth = 1; depth <= 4; depth++) {
      double best = -double.infinity;
      GameAction? currentBest;
      // 如果有上轮的最佳走法，将其移到列表首位优先搜索
      if (bestMove != null && moves.remove(bestMove)) {
        moves.insert(0, bestMove);
      }
      for (final m in moves) {
        final score = _alphaBeta(
          snap.applyAction(m),
          depth - 1,
          -double.infinity,
          double.infinity,
          false,
          snap.currentTurn,
        );
        if (score > best) {
          best = score;
          currentBest = m;
        }
      }
      bestMove = currentBest;
    }
    return bestMove ?? moves.first;
  }

  void _orderMoves(BoardSnapshot snap, List<GameAction> moves) {
    moves.sort((a, b) {
      int priority(GameAction m) {
        if (m case MoveAction(:final to)) {
          final target = snap.gridList[to];
          if (target.hasAnimal && !target.animal!.isHidden) return 2;
          return 1;
        }
        return 0; // FlipAction
      }

      return priority(b).compareTo(priority(a));
    });
  }

  double _alphaBeta(
    BoardSnapshot snap,
    int depth,
    double alpha,
    double beta,
    bool isMax,
    TurnGamerType faction,
  ) {
    final tt = _tt.get(snap.hash);
    if (tt != null && tt.depth >= depth) {
      if (tt.flag == ttExact) return tt.score;
      if (tt.flag == ttLowerBound) alpha = alpha > tt.score ? alpha : tt.score;
      if (tt.flag == ttUpperBound) beta = beta < tt.score ? beta : tt.score;
      if (alpha >= beta) return tt.score;
    }

    if (depth == 0 || snap.isGameOver) {
      return _quiescenceSearch(
        snap,
        alpha,
        beta,
        isMax,
        faction,
        _quiescenceDepthLimit,
      );
    }

    final player = isMax ? faction : faction.opponent;
    final moves = snap.generateMoves(player);
    _orderMoves(snap, moves);

    if (isMax) {
      double maxSc = -double.infinity;
      for (final m in moves) {
        final sc = _alphaBeta(
          snap.applyAction(m),
          depth - 1,
          alpha,
          beta,
          false,
          faction,
        );
        maxSc = sc > maxSc ? sc : maxSc;
        alpha = alpha > maxSc ? alpha : maxSc;
        if (alpha >= beta) break;
      }
      _tt.put(snap.hash, maxSc, depth, alpha >= beta ? ttLowerBound : ttExact);
      return maxSc;
    } else {
      double minSc = double.infinity;
      for (final m in moves) {
        final sc = _alphaBeta(
          snap.applyAction(m),
          depth - 1,
          alpha,
          beta,
          true,
          faction,
        );
        minSc = sc < minSc ? sc : minSc;
        beta = beta < minSc ? beta : minSc;
        if (alpha >= beta) break;
      }
      _tt.put(snap.hash, minSc, depth, alpha >= beta ? ttUpperBound : ttExact);
      return minSc;
    }
  }

  // 静止搜索：只扩展吃子走法
  double _quiescenceSearch(
    BoardSnapshot snap,
    double alpha,
    double beta,
    bool isMax,
    TurnGamerType faction,
    int qDepth,
  ) {
    double standPat = _evaluate(snap, faction);
    if (snap.isGameOver || qDepth == 0) return standPat;

    if (isMax) {
      if (standPat >= beta) return beta;
      if (standPat > alpha) alpha = standPat;

      final captures = _generateCaptures(snap, faction);
      for (final m in captures) {
        final sc = _quiescenceSearch(
          snap.applyAction(m),
          alpha,
          beta,
          false,
          faction,
          qDepth - 1,
        );
        if (sc > alpha) alpha = sc;
        if (alpha >= beta) return beta;
      }
      return alpha;
    } else {
      if (standPat <= alpha) return alpha;
      if (standPat < beta) beta = standPat;

      final captures = _generateCaptures(snap, faction.opponent);
      for (final m in captures) {
        final sc = _quiescenceSearch(
          snap.applyAction(m),
          alpha,
          beta,
          true,
          faction,
          qDepth - 1,
        );
        if (sc < beta) beta = sc;
        if (alpha >= beta) return alpha;
      }
      return beta;
    }
  }

  // 生成吃子走法（供静止搜索使用）
  List<GameAction> _generateCaptures(BoardSnapshot snap, TurnGamerType player) {
    final moves = <GameAction>[];
    final own = snap.getRevealedIndices(player);
    for (final from in own) {
      final animal = snap.gridList[from].animal!;
      final r = from ~/ snap.size;
      final c = from % snap.size;
      for (final (dr, dc) in planeAround) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= snap.size || nc < 0 || nc >= snap.size) continue;
        final to = nr * snap.size + nc;
        final toGrid = snap.gridList[to];
        if (toGrid.hasAnimal &&
            !toGrid.animal!.isHidden &&
            toGrid.animal!.owner != player &&
            animal.canEat(toGrid.animal!)) {
          moves.add(MoveAction(from, to));
        }
      }
    }
    return moves;
  }

  double _evaluate(BoardSnapshot snap, TurnGamerType faction) {
    if (snap.isGameOver) {
      final mine = faction == TurnGamerType.front
          ? snap.redCount
          : snap.blueCount;
      return mine > 0 ? 99999 : -99999;
    }

    double score = 0;
    final op = faction.opponent;

    // 明子统计
    Map<AnimalType, int> revealedCount = {
      for (var t in AnimalType.values) t: 0,
    };
    for (final g in snap.gridList) {
      if (g.hasAnimal && !g.animal!.isHidden) {
        revealedCount[g.animal!.type] = revealedCount[g.animal!.type]! + 1;
      }
    }

    // 暗子期望价值
    double unrevealedTotalValue = 0;
    int unrevealedTypes = 0;
    for (var t in AnimalType.values) {
      int remaining = 2 - revealedCount[t]!;
      if (remaining > 0) {
        unrevealedTotalValue += pieceValues[t]! * remaining;
        unrevealedTypes += remaining;
      }
    }
    double avgHiddenValue = unrevealedTypes > 0
        ? unrevealedTotalValue / unrevealedTypes
        : 0;
    const double hiddenWeight = 0.7;

    // 棋子价值
    for (final g in snap.gridList) {
      if (!g.hasAnimal) continue;
      final a = g.animal!;
      if (a.isHidden) {
        score += a.owner == faction
            ? avgHiddenValue * hiddenWeight
            : -avgHiddenValue * hiddenWeight;
      } else {
        final v = pieceValues[a.type]!.toDouble();
        score += a.owner == faction ? v : -v;
      }
    }

    // 机动性（使用轻量计数，避免分配 GameAction 对象）
    score += (snap.mobilityCount(faction) - snap.mobilityCount(op)) * 0.5;

    // 地形优势
    for (int i = 0; i < snap.gridList.length; i++) {
      final g = snap.gridList[i];
      if (!g.hasAnimal || g.animal!.isHidden) continue;
      final a = g.animal!;
      if (a.owner != faction) continue;
      double terrainBonus = 0;
      if (g.type == GridType.tree) {
        if (a.type == AnimalType.leopard) {
          terrainBonus = 3;
        } else if (a.type == AnimalType.cat) {
          terrainBonus = 2;
        } else if (a.type == AnimalType.mouse) {
          terrainBonus = 1;
        }
        if (terrainBonus > 0 && !_isThreatenedOnTerrain(snap, i, faction)) {
          terrainBonus += 3;
        }
      } else if (g.type == GridType.river) {
        if (a.type == AnimalType.mouse) {
          terrainBonus = 2;
        } else if (a.type == AnimalType.elephant || a.type == AnimalType.dog) {
          terrainBonus = 1;
        }
        if (terrainBonus > 0 && !_isThreatenedOnTerrain(snap, i, faction)) {
          terrainBonus += 2;
        }
      }
      score += terrainBonus;
    }

    // 重复局面惩罚
    int repeatCount = _historyHashes.where((h) => h == snap.hash).length;
    if (repeatCount >= 3) score -= 20;

    return score;
  }

  bool _isThreatenedOnTerrain(
    BoardSnapshot snap,
    int idx,
    TurnGamerType faction,
  ) {
    final myAnimal = snap.gridList[idx].animal!;
    final myGridType = snap.gridList[idx].type;
    final op = faction.opponent;

    for (int i = 0; i < snap.gridList.length; i++) {
      final g = snap.gridList[i];
      if (!g.hasAnimal || g.animal!.isHidden) continue;
      if (g.animal!.owner != op) continue;

      final fromR = i ~/ snap.size;
      final fromC = i % snap.size;
      final toR = idx ~/ snap.size;
      final toC = idx % snap.size;
      if ((fromR - toR).abs() + (fromC - toC).abs() != 1) continue;

      if (!g.animal!.canMoveTo(g.type, myGridType)) continue;
      if (g.animal!.canEat(myAnimal)) return true;
    }
    return false;
  }
}

/// AI 控制器
class AiController {
  late final AiEngine _engine;
  final List<Grid> board;
  final int boardSize;
  final TurnGamerType faction;
  final AiDifficulty difficulty;
  BoardSnapshot? _snap;

  AiController({
    required this.board,
    required this.boardSize,
    required this.faction,
    this.difficulty = AiDifficulty.hard,
  }) {
    Zobrist.init(boardSize);
    _engine = AiEngine(difficulty: difficulty);
    _updateSnapshot();
  }

  void updateState(GameAction action) {
    _applyAction(action);
    _updateSnapshot();
  }

  void _applyAction(GameAction action) {
    // 复用核心逻辑，直接修改当前 board
    final currentRed = _snap?.redCount ?? 0;
    final currentBlue = _snap?.blueCount ?? 0;

    switch (action) {
      case FlipAction _:
        final (newBoard, _, _) = _applyFlipToGrids(
          board,
          action,
          currentRed,
          currentBlue,
        );
        board.clear();
        board.addAll(newBoard);
        break;
      case MoveAction _:
        final (newBoard, _, _) = _applyMoveToGrids(
          board,
          action,
          currentRed,
          currentBlue,
        );
        board.clear();
        board.addAll(newBoard);
        break;
    }
  }

  void _updateSnapshot() {
    _snap = BoardSnapshot.fromBoard(
      board: board,
      size: boardSize,
      currentTurn: faction,
    );
    _engine.recordHash(_snap!.hash);
  }

  GameAction? getAction() {
    if (_snap == null) return null;
    return _engine.getBestMove(_snap!);
  }

  void dispose() => _engine.clear();
}
