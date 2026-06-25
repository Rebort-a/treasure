import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/tool/notifiers.dart';

import 'base.dart';
import 'extension.dart';

class FoundationalWidget extends StatelessWidget {
  final ListNotifier<CellNotifier> displayMap;
  final Function(int) onCellClick;

  const FoundationalWidget({
    super.key,
    required this.displayMap,
    required this.onCellClick,
  });

  @override
  Widget build(BuildContext context) => Center(child: _buildChessBoard());

  Widget _buildChessBoard() => AspectRatio(
    aspectRatio: 1,
    child: Container(
      decoration: _boardDecoration(),
      child: ValueListenableBuilder(
        valueListenable: displayMap,
        builder: (_, map, __) => LayoutBuilder(
          builder: (context, constraints) {
            int boardSize = sqrt(map.length).floor();
            double size = _calculateBoardSize(constraints, boardSize);
            double scaleFactor = (5 / boardSize);
            return SizedBox(
              width: size,
              height: size,
              child: _buildBoardCell(map, boardSize, scaleFactor),
            );
          },
        ),
      ),
    ),
  );

  BoxDecoration _boardDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Colors.brown, width: 8),
  );

  double _calculateBoardSize(BoxConstraints constraints, int boardSize) {
    final double maxSize = constraints.maxWidth;
    return (maxSize ~/ boardSize) * boardSize.toDouble();
  }

  Widget _buildBoardCell(
    List<CellNotifier> map,
    int boardSize,
    double scaleFactor,
  ) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: boardSize,
      ),
      itemCount: map.length,
      itemBuilder: (_, index) => _buildCell(map[index], boardSize, scaleFactor),
    );
  }

  Widget _buildCell(CellNotifier notifier, int boardSize, double scaleFactor) =>
      ValueListenableBuilder(
        valueListenable: notifier,
        builder: (_, cell, __) => GestureDetector(
          onTap: () => onCellClick(cell.coordinate),
          child: Container(
            margin: EdgeInsets.all(2 * scaleFactor), // 缩放边距
            decoration: _cellDecoration(cell, scaleFactor),
            child: cell.hasAnimal
                ? _buildAnimal(cell.animal!, boardSize, scaleFactor)
                : null,
          ),
        ),
      );

  BoxDecoration _cellDecoration(Cell cell, double scaleFactor) => BoxDecoration(
    color: _cellColor(cell),
    border: _cellBorder(cell, scaleFactor),
    borderRadius: BorderRadius.circular(4 * scaleFactor), // 缩放圆角
  );

  Color _cellColor(Cell cell) {
    return switch (cell.type) {
      CellType.river => Colors.blue[200]!,
      CellType.tree => Colors.brown[400]!,
      _ => Colors.grey[100]!,
    };
  }

  Border _cellBorder(Cell cell, double scaleFactor) => Border.all(
    color: _borderColor(cell),
    width: _borderWidth(cell, scaleFactor),
  );

  Color _borderColor(Cell cell) {
    if (cell.isSelected) return Colors.yellow;
    if (cell.isHightlight) return Colors.green;
    return Colors.grey;
  }

  double _borderWidth(Cell cell, double scaleFactor) {
    if (cell.isHightlight) return 4.0 * scaleFactor; // 缩放边框宽度
    if (cell.isSelected) {
      return 3.0 * scaleFactor; // 缩放边框宽度
    }
    return 1.0 * scaleFactor; // 缩放边框宽度
  }

  Widget _buildAnimal(Animal animal, int boardSize, double scaleFactor) {
    double fontSize = 32 * scaleFactor;

    return Container(
      margin: EdgeInsets.all(8 * scaleFactor), // 缩放边距
      decoration: BoxDecoration(
        color: _animalColor(animal),
        borderRadius: BorderRadius.circular(5 * scaleFactor), // 缩放圆角
      ),
      child: Center(
        child: Text(
          _animalContent(animal),
          style: TextStyle(fontSize: fontSize),
        ),
      ),
    );
  }

  Color _animalColor(Animal animal) {
    return animal.isHidden
        ? Colors.blueGrey
        : (animal.owner == TurnGamerType.front ? Colors.red : Colors.blue);
  }

  String _animalContent(Animal animal) {
    return animal.isHidden ? "" : animalEmojis[animal.type.index];
  }
}
