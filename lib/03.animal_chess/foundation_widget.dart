import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/tool/notifiers.dart';

import 'base.dart';
import 'extension.dart';

class FoundationalWidget extends StatelessWidget {
  final ListNotifier<GridNotifier> displayMap;
  final Function(int) onGridSelected;

  const FoundationalWidget({
    super.key,
    required this.displayMap,
    required this.onGridSelected,
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
              child: _buildBoardGrid(map, boardSize, scaleFactor),
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

  Widget _buildBoardGrid(
    List<GridNotifier> map,
    int boardSize,
    double scaleFactor,
  ) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: boardSize,
      ),
      itemCount: map.length,
      itemBuilder: (_, index) =>
          _buildGridCell(map[index], boardSize, scaleFactor),
    );
  }

  Widget _buildGridCell(
    GridNotifier notifier,
    int boardSize,
    double scaleFactor,
  ) => ValueListenableBuilder(
    valueListenable: notifier,
    builder: (_, grid, __) => GestureDetector(
      onTap: () => onGridSelected(grid.coordinate),
      child: Container(
        margin: EdgeInsets.all(2 * scaleFactor), // 缩放边距
        decoration: _gridDecoration(grid, scaleFactor),
        child: grid.hasAnimal
            ? _buildAnimal(grid.animal!, boardSize, scaleFactor)
            : null,
      ),
    ),
  );

  BoxDecoration _gridDecoration(Grid grid, double scaleFactor) => BoxDecoration(
    color: _gridColor(grid),
    border: _gridBorder(grid, scaleFactor),
    borderRadius: BorderRadius.circular(4 * scaleFactor), // 缩放圆角
  );

  Color _gridColor(Grid grid) {
    return switch (grid.type) {
      GridType.river => Colors.blue[200]!,
      GridType.tree => Colors.brown[400]!,
      _ => Colors.grey[100]!,
    };
  }

  Border _gridBorder(Grid grid, double scaleFactor) => Border.all(
    color: _borderColor(grid),
    width: _borderWidth(grid, scaleFactor),
  );

  Color _borderColor(Grid grid) {
    if (grid.hasAnimal && grid.animal!.isSelected) return Colors.yellow;
    if (grid.isHighlighted) return Colors.green;
    return Colors.grey;
  }

  double _borderWidth(Grid grid, double scaleFactor) {
    if (grid.isHighlighted) return 4.0 * scaleFactor; // 缩放边框宽度
    if (grid.hasAnimal && grid.animal!.isSelected) {
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
