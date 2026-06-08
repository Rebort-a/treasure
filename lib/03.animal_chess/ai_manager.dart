import 'dart:math';

import '../00.common/game/gamer.dart';
import 'base.dart';
import 'foundation_manager.dart';

class AiManager extends FoundationalManager {
  final TurnGamerType aiSide;
  bool _aiThinking = false;

  AiManager({this.aiSide = TurnGamerType.rear}) {
    initGame();
  }

  @override
  void selectGrid(int index) {
    if (_aiThinking) return;
    if (currentGamer.value == aiSide) return;

    super.selectGrid(index);

    // 人类操作后，如果轮到 AI，触发 AI
    if (currentGamer.value == aiSide && !_aiThinking) {
      _triggerAiMove();
    }
  }

  void _triggerAiMove() {
    _aiThinking = true;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (currentGamer.value != aiSide) {
        _aiThinking = false;
        return;
      }

      final move = _calculateBestMove();
      if (move != null) {
        super.selectGrid(move);
      }
      _aiThinking = false;

      // 如果又轮到 AI（比如翻棋后），继续
      if (currentGamer.value == aiSide) {
        _triggerAiMove();
      }
    });
  }

  int? _calculateBestMove() {
    final grids = displayMap.value;
    final random = Random();

    // 策略 1：翻面未揭示的棋子（优先翻棋，获取信息）
    final hiddenIndices = <int>[];
    for (int i = 0; i < grids.length; i++) {
      final grid = grids[i].value;
      if (grid.hasAnimal && grid.animal!.isHidden && grid.animal!.owner == aiSide) {
        hiddenIndices.add(i);
      }
    }
    if (hiddenIndices.isNotEmpty && random.nextDouble() < 0.4) {
      return hiddenIndices[random.nextInt(hiddenIndices.length)];
    }

    // 策略 2：寻找吃子机会
    int? bestCapture;
    int bestCaptureValue = -1;

    for (int i = 0; i < grids.length; i++) {
      final grid = grids[i].value;
      if (!grid.hasAnimal || grid.animal!.owner != aiSide) continue;
      if (grid.animal!.isHidden) continue;

      final moves = _getPossibleMoves(i);
      for (final target in moves) {
        final targetGrid = grids[target].value;
        if (targetGrid.hasAnimal && targetGrid.animal!.owner != aiSide) {
          final value = _pieceValue(grid.animal!.type) - _pieceValue(targetGrid.animal!.type);
          if (grid.animal!.canEat(targetGrid.animal!) && value > bestCaptureValue) {
            bestCaptureValue = value;
            bestCapture = i; // 选择这个棋子，然后目标在 selectGrid 中处理
          }
        }
      }
    }

    if (bestCapture != null) {
      // 先选中棋子
      super.selectGrid(bestCapture);
      // 然后选择目标
      final moves = _getPossibleMoves(bestCapture);
      for (final target in moves) {
        final targetGrid = grids[target].value;
        if (targetGrid.hasAnimal && targetGrid.animal!.owner != aiSide) {
          if (grids[bestCapture].value.animal?.canEat(targetGrid.animal!) ?? false) {
            return target;
          }
        }
      }
    }

    // 策略 3：安全移动（不被吃的位置）
    final safeMoves = <int>[];
    for (int i = 0; i < grids.length; i++) {
      final grid = grids[i].value;
      if (!grid.hasAnimal || grid.animal!.owner != aiSide) continue;
      if (grid.animal!.isHidden) continue;

      final moves = _getPossibleMoves(i);
      for (final target in moves) {
        if (!grids[target].value.hasAnimal) {
          safeMoves.add(i * 100 + target); // 编码 from*100+to
        }
      }
    }

    if (safeMoves.isNotEmpty) {
      final encoded = safeMoves[random.nextInt(safeMoves.length)];
      final from = encoded ~/ 100;
      final to = encoded % 100;
      super.selectGrid(from);
      return to;
    }

    // 策略 4：随便选一个能动的
    for (int i = 0; i < grids.length; i++) {
      final grid = grids[i].value;
      if (!grid.hasAnimal || grid.animal!.owner != aiSide) continue;
      if (grid.animal!.isHidden) continue;

      final moves = _getPossibleMoves(i);
      if (moves.isNotEmpty) {
        super.selectGrid(i);
        return moves.first;
      }
    }

    // 策略 5：翻任意未揭示棋子
    if (hiddenIndices.isNotEmpty) {
      return hiddenIndices.first;
    }

    return null;
  }

  List<int> _getPossibleMoves(int index) {
    final size = boardLevel * 2 + 1;
    final row = index ~/ size;
    final col = index % size;
    final moves = <int>[];

    for (final (int dr, int dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final int nr = row + dr;
      final int nc = col + dc;
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        final int ni = nr * size + nc;
        final fromGrid = displayMap.value[index].value;
        final toGrid = displayMap.value[ni].value;

        if (toGrid.animal?.isHidden == true) continue;
        if (toGrid.hasAnimal && toGrid.animal!.owner == fromGrid.animal!.owner) continue;
        if (fromGrid.animal!.canMoveTo(fromGrid.type, toGrid.type)) {
          moves.add(ni);
        }
      }
    }

    return moves;
  }

  int _pieceValue(AnimalType type) {
    return switch (type) {
      AnimalType.elephant => 8,
      AnimalType.tiger => 7,
      AnimalType.lion => 7,
      AnimalType.leopard => 6,
      AnimalType.wolf => 5,
      AnimalType.dog => 4,
      AnimalType.cat => 3,
      AnimalType.mouse => 2,
    };
  }

  @override
  void leavePage() {
    final redCount = displayMap.value
        .where((g) => g.value.hasAnimal && g.value.animal!.owner == TurnGamerType.front)
        .length;
    showChessResult(redCount > 0);
  }
}
