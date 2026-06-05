import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import '../00.common/tool/notifiers.dart';

// 围棋棋子状态
enum PieceType { empty, black, white }

class Grid {
  final int coordinate;
  PieceType type = PieceType.empty;

  Grid({required this.coordinate});

  bool isEmpty() => type == PieceType.empty;
}

class GridNotifier extends ValueNotifier<Grid> {
  GridNotifier(super.value);

  void placePiece(PieceType type) {
    value.type = type;
    notifyListeners();
  }

  void clear() {
    if (!value.isEmpty()) {
      value.type = PieceType.empty;
      notifyListeners();
    }
  }
}

class Board {
  final int size;
  final ListNotifier<GridNotifier> grids = ListNotifier([]);
  List<Grid> moveHistory = [];
  AlwaysNotifier<TurnGamerType> currentGamer = AlwaysNotifier(
    TurnGamerType.front,
  );
  bool gameOver = false;

  Board({required this.size}) {
    grids.value = List.generate(size * size, (index) {
      return GridNotifier(Grid(coordinate: index));
    });
  }

  PieceType obtainPiece(TurnGamerType player) {
    return currentGamer.value == TurnGamerType.front
        ? PieceType.black
        : PieceType.white;
  }

  void placePiece(int index) {
    GridNotifier grid = grids.value[index];

    if (!gameOver && grid.value.isEmpty()) {
      grid.placePiece(obtainPiece(currentGamer.value));
      moveHistory.add(grid.value);
      _checkWin(index);
    }
  }

  void _checkWin(int index) {
    int row = index ~/ size;
    int col = index % size;

    for (final (dr, dc) in planeConnection) {
      int count = 1; // 当前位置已经有1个棋子
      for (int dir = -1; dir <= 1; dir += 2) {
        for (int i = 1; i < 5; i++) {
          final newRow = row + dr * i * dir;
          final newCol = col + dc * i * dir;

          if (checkInMap(newRow, newCol) &&
              (grids.value[newRow * size + newCol].value.type ==
                  obtainPiece(currentGamer.value))) {
            count++;
          } else {
            break;
          }
        }
      }
      if (count >= 5) {
        gameOver = true;
        break;
      }
    }

    changeGamer(currentGamer.value.opponent);
  }

  void restart() {
    _clear();
    moveHistory.clear();
    changeGamer(TurnGamerType.front);
    gameOver = false;
  }

  void _clear() {
    for (int i = 0; i < size * size; i++) {
      grids.value[i].clear();
    }
  }

  void undoMove() {
    if (moveHistory.isEmpty) return;

    final lastMove = moveHistory.removeLast();
    grids.value[lastMove.coordinate].clear();
    gameOver = false;
    changeGamer(currentGamer.value.opponent);
  }

  void changeGamer(TurnGamerType gamer) {
    currentGamer.value = gamer;
  }

  bool checkInMap(x, y) {
    return (x >= 0) && (x < size) && (y >= 0) && (y < size);
  }
}
