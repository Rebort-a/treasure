import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import '../00.common/model/notifiers.dart';

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
  bool _disposed = false;

  /// 棋盘拥有自己创建的格子与状态，列表容器不负责级联释放。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final grid in grids.value) {
      grid.dispose();
    }
    grids.dispose();
    currentGamer.dispose();
    gameOverNotifier.dispose();
  }

  static const maxPiecesPerPlayer = 12;
  final Map<PieceType, List<int>> _pieceOrder = {
    PieceType.black: [],
    PieceType.white: [],
  };
  final List<int?> _expiredHistory = [];

  /// 当前仍在棋盘上的棋子，按各自落子先后排序。
  List<int> pieceOrder(PieceType type) => List.of(_pieceOrder[type]!);

  final int size;
  final ListNotifier<GridNotifier> grids = ListNotifier([]);
  List<Grid> moveHistory = [];
  AlwaysNotifier<TurnGamerType> currentGamer = AlwaysNotifier(
    TurnGamerType.front,
  );
  final gameOverNotifier = ValueNotifier(false);
  bool get gameOver => gameOverNotifier.value;
  set gameOver(bool value) => gameOverNotifier.value = value;
  TurnGamerType? lastWinner;

  Board({required this.size}) {
    grids.value = List.generate(size * size, (index) {
      return GridNotifier(Grid(coordinate: index));
    });
  }

  PieceType obtainPiece(TurnGamerType player) {
    return player == TurnGamerType.front ? PieceType.black : PieceType.white;
  }

  /// 导出位编码快照：0=空 1=黑 2=白（PieceType.index），供 AI 只读使用
  List<int> snapshot() => [for (final g in grids.value) g.value.type.index];

  void placePiece(int index) {
    if (index < 0 || index >= grids.value.length) return;
    GridNotifier grid = grids.value[index];

    if (!gameOver && grid.value.isEmpty()) {
      final type = obtainPiece(currentGamer.value);
      final order = _pieceOrder[type]!;
      grid.placePiece(type);
      order.add(index);
      // 先移除最早一子，再按最终棋盘判断胜负。
      final expired = order.length > maxPiecesPerPlayer
          ? order.removeAt(0)
          : null;
      if (expired != null) grids.value[expired].clear();
      _expiredHistory.add(expired);
      // 使用独立快照，避免同一格被清空、重用后污染历史。
      moveHistory.add(Grid(coordinate: index)..type = type);
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
        lastWinner = currentGamer.value;
        break;
      }
    }

    changeGamer(currentGamer.value.opponent);
  }

  void restart() {
    _clear();
    moveHistory.clear();
    _expiredHistory.clear();
    for (final order in _pieceOrder.values) {
      order.clear();
    }
    lastWinner = null;
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
    final order = _pieceOrder[lastMove.type]!;
    order.removeLast();
    final expired = _expiredHistory.removeLast();
    if (expired != null) {
      order.insert(0, expired);
      grids.value[expired].placePiece(lastMove.type);
    }
    lastWinner = null;
    gameOver = false;
    changeGamer(currentGamer.value.opponent);
  }

  void changeGamer(TurnGamerType gamer) {
    currentGamer.value = gamer;
  }

  bool checkInMap(int x, int y) {
    return (x >= 0) && (x < size) && (y >= 0) && (y < size);
  }
}
