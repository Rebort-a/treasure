import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'extension.dart';

abstract class FoundationalManager {
  int boardLevel = 2;
  int get _boardSize => boardLevel * 2 + 1;

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  final ValueNotifier<TurnGamerType> currentGamer = ValueNotifier(
    TurnGamerType.front,
  );
  final ListNotifier<GridNotifier> displayMap = ListNotifier([]);
  final List<int> _markedGrid = [];

  int _redAnimalsCount = AnimalType.values.length;
  int _blueAnimalsCount = AnimalType.values.length;

  /// 上一局赢家（用于重开时决定先手）
  TurnGamerType? lastWinner;

  int get boardSize => _boardSize;

  /// 获取指定位置的可移动目标列表
  List<int> getPossibleMoves(int index) {
    final row = index ~/ _boardSize;
    final col = index % _boardSize;
    final moves = <int>[];

    for (final (int dr, int dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final int nr = row + dr;
      final int nc = col + dc;
      if (nr >= 0 && nr < _boardSize && nc >= 0 && nc < _boardSize) {
        final int ni = nr * _boardSize + nc;
        if (_isValidMove(index, ni)) {
          moves.add(ni);
        }
      }
    }

    return moves;
  }

  /// 获取所有隐藏棋子位置
  List<int> get hiddenIndices {
    final result = <int>[];
    for (int i = 0; i < displayMap.value.length; i++) {
      final grid = displayMap.value[i].value;
      if (grid.hasAnimal && grid.animal!.isHidden) {
        result.add(i);
      }
    }
    return result;
  }

  /// 获取指定玩家的已翻开棋子位置
  List<int> getRevealedIndices(TurnGamerType player) {
    final result = <int>[];
    for (int i = 0; i < displayMap.value.length; i++) {
      final grid = displayMap.value[i].value;
      if (grid.hasAnimal && !grid.animal!.isHidden && grid.animal!.owner == player) {
        result.add(i);
      }
    }
    return result;
  }

  /// 获取棋盘上所有存活的动物（用于 AI 评估）
  Iterable<Animal> get allAnimals sync* {
    for (final grid in displayMap.value) {
      if (grid.value.hasAnimal) {
        yield grid.value.animal!;
      }
    }
  }

  /// 获取网格类型
  GridType getGridType(int index) => displayMap.value[index].value.type;

  void showBoardSizeSelector() {
    pageNavigator.value = (context) {
      DialogTemplate.intSliderDialog(
        context: context,
        title: S.setBoardSize,
        sliderData: IntSliderData(start: 2, end: 6, value: boardLevel, step: 1),
        onConfirm: (int value) {
          _updateBoardLevel(value);
        },
      );
    };
  }

  void _updateBoardLevel(int level) {
    boardLevel = level;
    initGame();
  }

  void initGame() {
    setupBoard();
    _placeAllAnimalRandom();
    resetGameState();
  }

  /// 仅重置棋盘结构（清空所有棋子），不放置新棋子
  void resetBoard() {
    setupBoard();
    _markedGrid.clear();
  }

  void setupBoard() {
    displayMap.value = List.generate(_boardSize * _boardSize, (index) {
      return GridNotifier(Grid(coordinate: index, type: _getGridType(index)));
    });
  }

  GridType _getGridType(int index) {
    final row = index ~/ _boardSize;
    final col = index % _boardSize;

    if (col == boardLevel) {
      if (row == boardLevel) return GridType.bridge;
      if (row == 0 || row == _boardSize - 1) return GridType.tree;
      return GridType.road;
    }

    return row == boardLevel ? GridType.river : GridType.land;
  }

  void _placeAllAnimalRandom() {
    final landPositions = _getLandPositions()..shuffle();
    const pieces = AnimalType.values;

    void placePlayerPieces(TurnGamerType player) {
      for (int i = 0; i < pieces.length; i++) {
        final index = landPositions.removeLast();
        placeAnimalByIndex(index, Animal(type: pieces[i], owner: player));
      }
    }

    placePlayerPieces(TurnGamerType.front);
    placePlayerPieces(TurnGamerType.rear);
  }

  void placeAnimalByIndex(int index, Animal animal) {
    displayMap.value[index].placeAnimal(animal);
  }

  List<int> _getLandPositions() {
    return displayMap.value
        .asMap()
        .entries
        .where((entry) => entry.value.value.type == GridType.land)
        .map((entry) => entry.key)
        .toList();
  }

  void resetGameState() {
    _markedGrid.clear();
    currentGamer.value = TurnGamerType.front;
    // 重置动物数量
    _redAnimalsCount = AnimalType.values.length;
    _blueAnimalsCount = AnimalType.values.length;
  }

  void selectGrid(int index) {
    final grid = displayMap.value[index].value;

    // 如果没有翻面，那么翻面
    if (grid.hasAnimal && grid.animal!.isHidden) {
      _revealPiece(index);
      return;
    }

    // 如果是选中棋子，那么取消棋子和周边的标记
    if (_isSelected(index)) {
      _clearSelectionAndHighlight();
      return;
    }

    // 如果是可选的移动目标，那么移动棋子
    if (_isValidMoveTarget(index)) {
      _movePiece(_markedGrid.first, index);
      return;
    }

    // 如果上面都不是，那么判断是否可以选中棋子
    if (_canSelect(grid)) {
      _setSelection(index);
    }
  }

  void _revealPiece(int index) {
    displayMap.value[index].revealAnimal();
    _endTurn();
  }

  void _clearSelectionAndHighlight() {
    if (_markedGrid.isEmpty) return;

    displayMap.value[_markedGrid.first].toggleSelection(false);

    for (final index in _markedGrid.skip(1)) {
      displayMap.value[index].toggleHighlight(false);
    }

    _markedGrid.clear();
  }

  bool _isValidMoveTarget(int index) {
    return _markedGrid.length > 1 && _markedGrid.skip(1).contains(index);
  }

  void _movePiece(int from, int to) {
    final fromGrid = displayMap.value[from].value;
    if (!fromGrid.hasAnimal) return;

    final movingAnimal = fromGrid.animal!;

    if (displayMap.value[to].value.hasAnimal) {
      _resolveCombat(movingAnimal, displayMap.value[to].value.animal!, to);
    } else {
      displayMap.value[to].placeAnimal(movingAnimal);
      _markedGrid.first = to;
    }

    displayMap.value[from].clearAnimal();
    _endTurn();
  }

  void _resolveCombat(Animal attacker, Animal defender, int targetPos) {
    final attackerWins = attacker.canEat(defender);
    final defenderWins = defender.canEat(attacker);

    if (attackerWins && defenderWins) {
      displayMap.value[targetPos].clearAnimal();
      _redAnimalsCount--;
      _blueAnimalsCount--;
    } else if (attackerWins) {
      displayMap.value[targetPos].placeAnimal(attacker);
      _markedGrid.first = targetPos;

      if (defender.owner == TurnGamerType.front) {
        _redAnimalsCount--;
      } else {
        _blueAnimalsCount--;
      }
    } else if (defenderWins) {
      if (attacker.owner == TurnGamerType.front) {
        _redAnimalsCount--;
      } else {
        _blueAnimalsCount--;
      }
    }

    _checkGameEnd();
  }

  bool _canSelect(Grid grid) {
    return grid.hasAnimal && grid.animal!.owner == currentGamer.value;
  }

  void _setSelection(int index) {
    _clearSelectionAndHighlight();
    _markedGrid.add(index);
    displayMap.value[index].toggleSelection(true);
    _calculatePossibleMoves(index);
  }

  void _calculatePossibleMoves(int index) {
    final row = index ~/ _boardSize;
    final col = index % _boardSize;

    for (final (dr, dc) in planeAround) {
      final newRow = row + dr;
      final newCol = col + dc;
      final newIndex = newRow * _boardSize + newCol;

      if (newRow >= 0 &&
          newRow < _boardSize &&
          newCol >= 0 &&
          newCol < _boardSize) {
        if (_isValidMove(index, newIndex)) {
          displayMap.value[newIndex].toggleHighlight(true);
          _markedGrid.add(newIndex);
        }
      }
    }
  }

  bool _isValidMove(int fromIndex, int toIndex) {
    final fromGrid = displayMap.value[fromIndex].value;
    final toGrid = displayMap.value[toIndex].value;

    if (!fromGrid.hasAnimal) return false;
    if (toGrid.animal?.isHidden == true) return false;
    if (toGrid.hasAnimal && toGrid.animal!.owner == fromGrid.animal!.owner) {
      return false;
    }

    return fromGrid.animal!.canMoveTo(fromGrid.type, toGrid.type);
  }

  void _endTurn() {
    _clearSelectionAndHighlight();
    currentGamer.value = currentGamer.value.opponent;
  }

  void _checkGameEnd() {
    if (_redAnimalsCount <= 0) {
      lastWinner = TurnGamerType.rear;
      showChessResult(false);
    } else if (_blueAnimalsCount <= 0) {
      lastWinner = TurnGamerType.front;
      showChessResult(true);
    }
  }

  bool _isSelected(int index) =>
      _markedGrid.isNotEmpty && _markedGrid.first == index;

  /// 外部可设置的重开回调（由 local_page 注入）
  void Function()? onRestart;

  void showChessResult(bool isRedWin) {
    pageNavigator.value = (context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(S.gameOver),
            content: Text(isRedWin ? S.redWin() : S.blueWin()),
            actions: [
              TextButton(
                child: Text(S.exit),
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToBack();
                },
              ),
              TextButton(
                child: Text(S.restart),
                onPressed: () {
                  Navigator.pop(context);
                  onRestart?.call();
                },
              ),
              TextButton(
                child: Text(S.cancel),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    };
  }

  void leavePage() {
    _navigateToBack();
  }

  void _navigateToBack() {
    pageNavigator.value = (context) {
      Navigator.pop(context);
    };
  }
}
