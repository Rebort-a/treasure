import 'dart:math';

import '../00.common/game/gamer.dart';
import 'base.dart';
import 'foundation_manager.dart';

/// AI 难度
enum AiDifficulty { easy, medium, hard }

/// 走法
sealed class AiMove {
  final int index;
  const AiMove(this.index);
}

class FlipMove extends AiMove {
  const FlipMove(super.index);
}

class StepMove extends AiMove {
  final int from;
  final int to;
  const StepMove(this.from, this.to) : super(from);
}

/// 棋盘快照（用于 AI 模拟）
class BoardSnapshot {
  final List<Animal?> cells;
  final List<GridType> gridTypes;
  final int size;
  final TurnGamerType currentTurn;
  final int redCount;
  final int blueCount;

  BoardSnapshot({
    required this.cells,
    required this.gridTypes,
    required this.size,
    required this.currentTurn,
    required this.redCount,
    required this.blueCount,
  });

  /// 从管理器创建快照
  factory BoardSnapshot.from(FoundationalManager manager, TurnGamerType aiSide) {
    final size = manager.boardSize;
    final cells = <Animal?>[];
    final gridTypes = <GridType>[];
    int red = 0, blue = 0;

    for (int i = 0; i < size * size; i++) {
      final grid = manager.displayMap.value[i].value;
      gridTypes.add(grid.type);
      if (grid.hasAnimal) {
        final animal = grid.animal!;
        // 隐藏棋子对 AI 透明：AI 只知道自己的棋子类型，对方隐藏棋子视为未知
        if (animal.isHidden && animal.owner != aiSide) {
          cells.add(null); // 未知棋子
        } else {
          cells.add(Animal(
            type: animal.type,
            owner: animal.owner,
            isHidden: animal.isHidden,
          ));
          if (animal.owner == TurnGamerType.front) red++;
          if (animal.owner == TurnGamerType.rear) blue++;
        }
      } else {
        cells.add(null);
      }
    }

    return BoardSnapshot(
      cells: cells,
      gridTypes: gridTypes,
      size: size,
      currentTurn: manager.currentGamer.value,
      redCount: red,
      blueCount: blue,
    );
  }

  /// 执行走法，返回新快照
  BoardSnapshot applyMove(AiMove move, TurnGamerType aiSide) {
    final newCells = List<Animal?>.from(cells);
    int newRed = redCount, newBlue = blueCount;
    TurnGamerType nextTurn = currentTurn.opponent;

    switch (move) {
      case FlipMove(:final index):
        final old = newCells[index];
        if (old != null) {
          newCells[index] = Animal(
            type: old.type,
            owner: old.owner,
            isHidden: false,
          );
        }
      case StepMove(:final from, :final to):
        final attacker = newCells[from];
        final defender = newCells[to];
        newCells[from] = null;

        if (attacker != null && defender != null) {
          final attackerWins = attacker.canEat(defender);
          final defenderWins = defender.canEat(attacker);

          if (attackerWins && defenderWins) {
            newCells[to] = null;
            if (attacker.owner == TurnGamerType.front) newRed--;
            if (attacker.owner == TurnGamerType.rear) newBlue--;
            if (defender.owner == TurnGamerType.front) newRed--;
            if (defender.owner == TurnGamerType.rear) newBlue--;
          } else if (attackerWins) {
            newCells[to] = Animal(
              type: attacker.type,
              owner: attacker.owner,
              isHidden: false,
            );
            if (defender.owner == TurnGamerType.front) newRed--;
            if (defender.owner == TurnGamerType.rear) newBlue--;
          } else if (defenderWins) {
            newCells[to] = Animal(
              type: defender.type,
              owner: defender.owner,
              isHidden: false,
            );
            if (attacker.owner == TurnGamerType.front) newRed--;
            if (attacker.owner == TurnGamerType.rear) newBlue--;
          }
          // 同类互吃已在 canEat 中处理（返回 true）
        } else if (attacker != null) {
          newCells[to] = Animal(
            type: attacker.type,
            owner: attacker.owner,
            isHidden: false,
          );
        }
    }

    return BoardSnapshot(
      cells: newCells,
      gridTypes: gridTypes,
      size: size,
      currentTurn: nextTurn,
      redCount: newRed,
      blueCount: newBlue,
    );
  }

  /// 获取某方所有已翻开棋子的位置
  List<int> getRevealedIndices(TurnGamerType player) {
    final result = <int>[];
    for (int i = 0; i < cells.length; i++) {
      final a = cells[i];
      if (a != null && !a.isHidden && a.owner == player) {
        result.add(i);
      }
    }
    return result;
  }

  /// 获取所有隐藏棋子位置
  List<int> get hiddenIndices {
    final result = <int>[];
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] != null && cells[i]!.isHidden) {
        result.add(i);
      }
    }
    return result;
  }

  /// 生成某方所有合法走法
  List<AiMove> generateMoves(TurnGamerType player) {
    final moves = <AiMove>[];

    // 翻棋走法
    for (final i in hiddenIndices) {
      moves.add(FlipMove(i));
    }

    // 移动走法
    final revealed = getRevealedIndices(player);
    for (final from in revealed) {
      final animal = cells[from]!;
      final fromRow = from ~/ size;
      final fromCol = from % size;

      for (final (int dr, int dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final int nr = fromRow + dr;
        final int nc = fromCol + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final int to = nr * size + nc;
        final target = cells[to];

        // 不能走向己方棋子
        if (target != null && target.owner == player) continue;
        // 不能走向隐藏棋子
        if (target != null && target.isHidden) continue;
        // 检查地形
        if (!animal.canMoveTo(gridTypes[from], gridTypes[to])) continue;

        moves.add(StepMove(from, to));
      }
    }

    return moves;
  }

  bool get isGameOver => redCount <= 0 || blueCount <= 0;
}

/// 棋子价值表
const Map<AnimalType, int> pieceValues = {
  AnimalType.elephant: 10,
  AnimalType.tiger: 9,
  AnimalType.lion: 9,
  AnimalType.leopard: 8,
  AnimalType.wolf: 6,
  AnimalType.dog: 5,
  AnimalType.cat: 4,
  AnimalType.mouse: 3,
};

/// 斗兽棋 AI 管理器
class AiManager extends FoundationalManager {
  AiDifficulty difficulty;
  final TurnGamerType aiSide;
  bool _aiThinking = false;

  AiManager({this.aiSide = TurnGamerType.rear, this.difficulty = AiDifficulty.hard}) {
    initGame();
  }

  @override
  void selectGrid(int index) {
    if (_aiThinking) return;
    if (currentGamer.value == aiSide) return;

    super.selectGrid(index);

    if (currentGamer.value == aiSide && !_aiThinking) {
      _triggerAiMove();
    }
  }

  /// 外部调用：如果当前轮到 AI，立即开始走棋
  void startIfMyTurn() {
    if (currentGamer.value == aiSide && !_aiThinking) {
      _triggerAiMove();
    }
  }

  void _triggerAiMove() {
    _aiThinking = true;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (currentGamer.value != aiSide || _isGameOver) {
        _aiThinking = false;
        return;
      }

      final move = _calculateBestMove();
      if (move != null) {
        _executeMove(move);
      }
      _aiThinking = false;

      if (currentGamer.value == aiSide && !_isGameOver) {
        _triggerAiMove();
      }
    });
  }

  bool get _isGameOver {
    return displayMap.value
        .where((g) => g.value.hasAnimal && g.value.animal!.owner == TurnGamerType.front)
        .isEmpty ||
        displayMap.value
        .where((g) => g.value.hasAnimal && g.value.animal!.owner == TurnGamerType.rear)
        .isEmpty;
  }

  void _executeMove(AiMove move) {
    switch (move) {
      case FlipMove(:final index):
        super.selectGrid(index);
      case StepMove(:final from, :final to):
        super.selectGrid(from);
        super.selectGrid(to);
    }
  }

  AiMove? _calculateBestMove() {
    final snapshot = BoardSnapshot.from(this, aiSide);
    final moves = snapshot.generateMoves(aiSide);
    if (moves.isEmpty) return null;

    return switch (difficulty) {
      AiDifficulty.easy => _easyMove(snapshot, moves),
      AiDifficulty.medium => _mediumMove(snapshot, moves),
      AiDifficulty.hard => _hardMove(snapshot, moves),
    };
  }

  // ==================== 简单：随机 + 吃子优先 ====================

  AiMove _easyMove(BoardSnapshot snap, List<AiMove> moves) {
    final rand = Random();

    // 优先吃子
    final captures = <AiMove>[];
    for (final move in moves) {
      if (move is StepMove) {
        final target = snap.cells[move.to];
        if (target != null && target.owner != aiSide) {
          final attacker = snap.cells[move.from]!;
          if (attacker.canEat(target)) {
            captures.add(move);
          }
        }
      }
    }
    if (captures.isNotEmpty) return captures[rand.nextInt(captures.length)];

    // 随机走
    return moves[rand.nextInt(moves.length)];
  }

  // ==================== 中等：1-Ply 评估 ====================

  AiMove _mediumMove(BoardSnapshot snap, List<AiMove> moves) {
    AiMove? bestMove;
    double bestScore = -double.infinity;

    for (final move in moves) {
      final after = snap.applyMove(move, aiSide);
      final score = _evaluate(after, aiSide);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove ?? moves.first;
  }

  // ==================== 困难：2-Ply Minimax ====================

  AiMove _hardMove(BoardSnapshot snap, List<AiMove> moves) {
    AiMove? bestMove;
    double bestScore = -double.infinity;

    for (final aiMove in moves) {
      final afterAi = snap.applyMove(aiMove, aiSide);

      // 如果游戏结束，直接评估
      if (afterAi.isGameOver) {
        final score = _evaluate(afterAi, aiSide);
        if (score > bestScore) {
          bestScore = score;
          bestMove = aiMove;
        }
        continue;
      }

      // 模拟对手最优回应
      final opponentMoves = afterAi.generateMoves(aiSide.opponent);
      double worstResponse = double.infinity;

      for (final opMove in opponentMoves) {
        final afterOp = afterAi.applyMove(opMove, aiSide);
        final score = _evaluate(afterOp, aiSide);
        if (score < worstResponse) {
          worstResponse = score;
        }
      }

      // 如果对手没有走法（已输），给高分
      if (opponentMoves.isEmpty) worstResponse = 10000;

      // 综合分 = AI 走后评估 + 对手最优回应后评估 × 0.6
      final combined = _evaluate(afterAi, aiSide) + worstResponse * 0.6;
      if (combined > bestScore) {
        bestScore = combined;
        bestMove = aiMove;
      }
    }

    return bestMove ?? moves.first;
  }

  // ==================== 评估函数 ====================

  double _evaluate(BoardSnapshot snap, TurnGamerType aiSide) {
    if (snap.isGameOver) {
      final aiCount = aiSide == TurnGamerType.front ? snap.redCount : snap.blueCount;
      return aiCount > 0 ? 10000 : -10000;
    }

    double score = 0;
    final opSide = aiSide.opponent;

    // 1. 材料分（40%）
    double materialScore = 0;
    for (final animal in snap.cells) {
      if (animal == null) continue;
      final value = pieceValues[animal.type]!.toDouble();
      if (animal.owner == aiSide) {
        materialScore += value;
      } else {
        materialScore -= value;
      }
    }
    score += materialScore * 0.4;

    // 2. 机动性分（20%）
    final aiMoves = snap.generateMoves(aiSide);
    final opMoves = snap.generateMoves(opSide);
    score += (aiMoves.length - opMoves.length) * 0.5 * 0.2;

    // 3. 威胁分（25%）
    score += _threatScore(snap, aiSide) * 0.25;

    // 4. 地形控制分（15%）
    score += _terrainScore(snap, aiSide) * 0.15;

    // 5. 翻棋信息分
    final hidden = snap.hiddenIndices.length;
    if (hidden > 0) {
      // 场上隐藏棋子越多，翻棋价值越高
      score += 5.0 * hidden / snap.cells.length;
    }

    return score;
  }

  /// 威胁评估：检查每个棋子是否被威胁或威胁他人
  double _threatScore(BoardSnapshot snap, TurnGamerType aiSide) {
    double score = 0;
    final opSide = aiSide.opponent;

    final aiPieces = snap.getRevealedIndices(aiSide);
    final opPieces = snap.getRevealedIndices(opSide);

    // 己方棋子被威胁 → 扣分
    for (final aiIdx in aiPieces) {
      final aiAnimal = snap.cells[aiIdx]!;
      final aiRow = aiIdx ~/ snap.size;
      final aiCol = aiIdx % snap.size;

      for (final opIdx in opPieces) {
        final opAnimal = snap.cells[opIdx]!;
        final opRow = opIdx ~/ snap.size;
        final opCol = opIdx % snap.size;
        final dist = (aiRow - opRow).abs() + (aiCol - opCol).abs();

        if (dist <= 2 && opAnimal.canEat(aiAnimal)) {
          // 距离越近威胁越大
          final threat = pieceValues[aiAnimal.type]! / dist;
          score -= threat;
        }
      }
    }

    // 己方棋子威胁敌方 → 加分
    for (final aiIdx in aiPieces) {
      final aiAnimal = snap.cells[aiIdx]!;
      final aiRow = aiIdx ~/ snap.size;
      final aiCol = aiIdx % snap.size;

      for (final opIdx in opPieces) {
        final opAnimal = snap.cells[opIdx]!;
        final opRow = opIdx ~/ snap.size;
        final opCol = opIdx % snap.size;
        final dist = (aiRow - opRow).abs() + (aiCol - opCol).abs();

        if (dist <= 2 && aiAnimal.canEat(opAnimal)) {
          final threat = pieceValues[opAnimal.type]! / dist;
          score += threat;
        }
      }
    }

    return score;
  }

  /// 地形控制评估
  double _terrainScore(BoardSnapshot snap, TurnGamerType aiSide) {
    double score = 0;

    for (int i = 0; i < snap.cells.length; i++) {
      final animal = snap.cells[i];
      if (animal == null || animal.isHidden) continue;

      final gridType = snap.gridTypes[i];
      final isAi = animal.owner == aiSide;
      final sign = isAi ? 1.0 : -1.0;

      // 在河流/树上的棋子有灵活性加分
      if (gridType == GridType.river && animal.canMoveTo(GridType.land, GridType.river)) {
        score += sign * 1.5;
      }
      if (gridType == GridType.tree && animal.canMoveTo(GridType.land, GridType.tree)) {
        score += sign * 1.0;
      }
      // 在桥上的棋子
      if (gridType == GridType.bridge) {
        score += sign * 0.5;
      }
    }

    return score;
  }

  @override
  void leavePage() {
    final redCount = displayMap.value
        .where((g) => g.value.hasAnimal && g.value.animal!.owner == TurnGamerType.front)
        .length;
    showChessResult(redCount > 0);
  }
}
