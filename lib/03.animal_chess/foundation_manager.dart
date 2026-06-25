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
  final ListNotifier<CellNotifier> displayMap = ListNotifier([]);
  final List<int> _markedCell = [];

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
      return CellNotifier(Cell(coordinate: index, type: _getCellType(index)));
    });
  }

  CellType _getCellType(int index) {
    final row = index ~/ _boardSize;
    final col = index % _boardSize;

    if (col == boardLevel) {
      if (row == boardLevel) return CellType.bridge;
      if (row == 0 || row == _boardSize - 1) return CellType.tree;
      return CellType.road;
    }

    return row == boardLevel ? CellType.river : CellType.land;
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
        .where((entry) => entry.value.value.type == CellType.land)
        .map((entry) => entry.key)
        .toList();
  }

  void resetGameState() {
    _markedCell.clear();
    currentGamer.value = TurnGamerType.front;
    _redAnimalsCount = AnimalType.values.length;
    _blueAnimalsCount = AnimalType.values.length;
  }

  void onCellClick(int index) {}

  GameAction? autoProcess(int index) {
    final action = _selectCell(index);
    if (action != null) {
      executeAction(action);
      endTurn();
      return action;
    }
    return null;
  }

  // 行为未造成回合切换，视为无效，返回null，否则返回完整行为
  GameAction? _selectCell(int index) {
    final cell = displayMap.value[index].value;

    // 如果没有翻面，那么翻面
    if (cell.hasAnimal && cell.animal!.isHidden) {
      _clearSelectionAndHighlight();
      return FlipAction(index);
    }

    // 如果是已选中棋子，那么取消棋子和周边的标记
    if (_isSelected(index)) {
      _clearSelectionAndHighlight();
      return null;
    }

    // 如果是可选的移动目标，那么移动棋子
    if (_isValidMoveTarget(index)) {
      return MoveAction(_markedCell.first, index);
    }

    // 如果上面都不是，那么判断是否可以选中棋子
    if (_canSelect(cell)) {
      _clearSelectionAndHighlight();
      _setSelection(index);
      return null;
    }

    return null;
  }

  void executeAction(GameAction action) {
    _clearSelectionAndHighlight();
    if (action is FlipAction) {
      _revealPiece(action.index);
    } else if (action is MoveAction) {
      _movePiece(action.from, action.to);
    }
  }

  void _revealPiece(int index) {
    displayMap.value[index].revealAnimal();
    _hiddenCount--;
  }

  bool _isValidMoveTarget(int index) {
    return _markedCell.length > 1 && _markedCell.skip(1).contains(index);
  }

  void _movePiece(int from, int to) {
    final fromCell = displayMap.value[from].value;
    if (!fromCell.hasAnimal) return;

    final movingAnimal = fromCell.animal!;

    if (displayMap.value[to].value.hasAnimal) {
      _resolveCombat(movingAnimal, displayMap.value[to].value.animal!, to);
    } else {
      displayMap.value[to].placeAnimal(movingAnimal);
    }

    displayMap.value[from].clearAnimal();
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

  bool _canSelect(Cell cell) {
    return cell.hasAnimal && cell.animal!.owner == currentGamer.value;
  }

  void _setSelection(int index) {
    _markedCell.add(index);
    displayMap.value[index].toggleState(CellState.selected);
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
          displayMap.value[newIndex].toggleState(CellState.highlight);
          _markedCell.add(newIndex);
        }
      }
    }
  }

  bool _isValidMove(int fromIndex, int toIndex) {
    final fromCell = displayMap.value[fromIndex].value;
    final toCell = displayMap.value[toIndex].value;

    if (!fromCell.hasAnimal) return false;
    if (toCell.animal?.isHidden == true) return false;
    if (toCell.hasAnimal && toCell.animal!.owner == fromCell.animal!.owner) {
      return false;
    }

    return fromCell.animal!.canMoveTo(fromCell.type, toCell.type);
  }

  void _checkGameEnd() {
    if (_hiddenCount <= 0) {
      if (_redAnimalsCount <= 0) {
        _handleGameOver(TurnGamerType.rear);
      } else if (_blueAnimalsCount <= 0) {
        _handleGameOver(TurnGamerType.front);
      }
    }
  }

  void endTurn() {
    currentGamer.value = currentGamer.value.opponent;
  }

  void _clearSelectionAndHighlight() {
    if (_markedCell.isEmpty) return;

    for (final index in _markedCell) {
      displayMap.value[index].toggleState(CellState.normal);
    }

    _markedCell.clear();
  }

  bool _isSelected(int index) =>
      _markedCell.isNotEmpty && _markedCell.first == index;

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

  void handleSurrender() {
    _handleGameOver(currentGamer.value.opponent);
  }

  void _handleGameOver(TurnGamerType winner) {
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
