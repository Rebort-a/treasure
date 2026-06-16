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
  final ValueNotifier<TurnGamerType?> gameWinner = ValueNotifier(null);
  final ListNotifier<GridNotifier> displayMap = ListNotifier([]);
  final List<int> _markedGrid = [];

  int _redAnimalsCount = AnimalType.values.length;
  int _blueAnimalsCount = AnimalType.values.length;
  int _hiddenCount = AnimalType.values.length * 2;

  int get boardSize => _boardSize;

  void initGame() {
    setupBoard();
    _placeAllAnimalRandom();
    resetGameState();
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
    _redAnimalsCount = AnimalType.values.length;
    _blueAnimalsCount = AnimalType.values.length;
  }

  // 行为未造成回合切换，视为无效，返回null，否则返回完整行为
  GameAction? selectGrid(int index) {
    final grid = displayMap.value[index].value;

    // 如果没有翻面，那么翻面
    if (grid.hasAnimal && grid.animal!.isHidden) {
      _revealPiece(index);
      return FlipAction(index);
    }

    // 如果是已选中棋子，那么取消棋子和周边的标记
    if (_isSelected(index)) {
      _clearSelectionAndHighlight();
      return null;
    }

    // 如果是可选的移动目标，那么移动棋子
    if (_isValidMoveTarget(index)) {
      int source = _markedGrid.first;
      _movePiece(source, index);
      return MoveAction(source, index);
    }

    // 如果上面都不是，那么判断是否可以选中棋子
    if (_canSelect(grid)) {
      _setSelection(index);
      return null;
    }

    return null;
  }

  void _revealPiece(int index) {
    displayMap.value[index].revealAnimal();
    _hiddenCount--;
    _endTurn();
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

  void _checkGameEnd() {
    if (_hiddenCount <= 0) {
      if (_redAnimalsCount <= 0) {
        handleGameOver(TurnGamerType.rear);
      } else if (_blueAnimalsCount <= 0) {
        handleGameOver(TurnGamerType.front);
      }
    }
  }

  void _endTurn() {
    _clearSelectionAndHighlight();
    currentGamer.value = currentGamer.value.opponent;
  }

  /// 无合法走法时跳过回合
  void passTurn() {
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

  bool _isSelected(int index) =>
      _markedGrid.isNotEmpty && _markedGrid.first == index;

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

  void handleGameOver(TurnGamerType winner) {
    gameWinner.value = winner;
    _showChessResult(winner);
  }

  void _showChessResult(TurnGamerType winner) {
    pageNavigator.value = (context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(S.gameOver),
            content: Text(
              winner == TurnGamerType.front ? S.redWin() : S.blueWin(),
            ),
            actions: _buildDialogActions(context),
          );
        },
      );
    };
  }

  List<Widget> _buildDialogActions(BuildContext context) {
    return [
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
          initGame();
        },
      ),
      TextButton(
        child: Text(S.cancel),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    ];
  }

  void _navigateToBack() {
    pageNavigator.value = (context) {
      Navigator.pop(context);
    };
  }
}
