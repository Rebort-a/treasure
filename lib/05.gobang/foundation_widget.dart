import 'dart:math';

import 'package:flutter/material.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';

class FoundationalWidget extends StatelessWidget {
  final FoundationalManager manager;
  final void Function(int index)? onGridSelected;

  const FoundationalWidget({super.key, required this.manager, this.onGridSelected});

  @override
  Widget build(BuildContext context) => Center(child: _buildChessBoard());

  Widget _buildChessBoard() => AspectRatio(
    aspectRatio: 1.0,
    child: Center(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFDCB35C),
          border: Border.all(color: const Color(0xFFDCB35C), width: 8),
        ),
        child: ValueListenableBuilder(
          valueListenable: manager.board.grids,
          builder: (context, grids, _) {
            if (grids.isEmpty) {
              return Text(S.mapDataEmpty);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final double boardSize = _calculateBoardSize(
                  constraints,
                  manager.board.size,
                );
                final double cellSize = boardSize / manager.board.size;

                return SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: manager.board.size,
                      childAspectRatio: 1,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                    ),
                    itemCount: grids.length,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 0.5),
                        ),
                        width: cellSize,
                        height: cellSize,
                        child: _buildPiece(grids[index], index, cellSize),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );

  double _calculateBoardSize(BoxConstraints constraints, int cellCount) {
    final double maxSize = min(constraints.maxWidth, constraints.maxHeight);
    return (maxSize ~/ cellCount) * cellCount.toDouble();
  }

  Widget _buildPiece(GridNotifier notifier, int index, double cellSize) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, grid, __) {
        if (!grid.isEmpty()) {
          return Center(
            child: Container(
              width: cellSize * 0.8,
              height: cellSize * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: grid.type == PieceType.black
                    ? Colors.black
                    : Colors.white,
                border: grid.type == PieceType.white
                    ? Border.all(color: Colors.black, width: 1.5)
                    : null,
              ),
            ),
          );
        } else {
          return GestureDetector(
            onTap: () => onGridSelected != null ? onGridSelected!(index) : manager.placePiece(index),
            child: Container(color: Colors.transparent),
          );
        }
      },
    );
  }
}
