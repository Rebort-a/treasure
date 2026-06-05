import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';

class GoFoundationWidget extends StatelessWidget {
  final GoFoundationalManager manager;

  const GoFoundationWidget({super.key, required this.manager});

  @override
  Widget build(BuildContext context) => Center(child: _buildBoard());

  Widget _buildBoard() => AspectRatio(
    aspectRatio: 1.0,
    child: Center(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE6B87D),
          border: Border.all(color: const Color(0xFF8B4513), width: 2),
        ),
        child: ValueListenableBuilder(
          valueListenable: manager.board.grids,
          builder: (context, grids, _) {
            if (grids.isEmpty) {
              return Text(S.boardDataEmpty);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                // 棋盘配置参数
                final int size = manager.board.size;
                final double boardSize = constraints.biggest.shortestSide;
                final double cellSize = boardSize / size;
                final double offset = cellSize / 2;
                final double stoneRadius = cellSize * 0.45;

                // 构建棋盘元素
                return Stack(
                  children: [
                    ..._buildGridLines(size, cellSize, offset),
                    ..._buildStarPoints(size, cellSize, offset),
                    ..._buildAllStones(
                      grids,
                      size,
                      cellSize,
                      offset,
                      stoneRadius,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    ),
  );

  // 绘制棋盘网格线
  List<Widget> _buildGridLines(int size, double cellSize, double offset) {
    List<Widget> gridLines = [];

    // 横线
    for (int i = 0; i < size; i++) {
      gridLines.add(
        Positioned(
          left: offset,
          right: offset,
          top: offset + i * cellSize,
          height: 1,
          child: Container(color: const Color(0xFF8B4513)),
        ),
      );
    }

    // 竖线
    for (int i = 0; i < size; i++) {
      gridLines.add(
        Positioned(
          left: offset + i * cellSize,
          top: offset,
          bottom: offset,
          width: 1,
          child: Container(color: const Color(0xFF8B4513)),
        ),
      );
    }

    return gridLines;
  }

  // 绘制星位
  List<Widget> _buildStarPoints(int size, double cellSize, double offset) {
    // 19×19棋盘的9个星位位置
    const List<List<int>> starPoints = [
      [3, 3],
      [3, 9],
      [3, 15],
      [9, 3],
      [9, 9],
      [9, 15],
      [15, 3],
      [15, 9],
      [15, 15],
    ];

    return starPoints.map((point) {
      final int x = point[0];
      final int y = point[1];
      return Positioned(
        left: offset + x * cellSize - 3,
        top: offset + y * cellSize - 3,
        width: 6,
        height: 6,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF8B4513),
            shape: BoxShape.circle,
          ),
        ),
      );
    }).toList();
  }

  // 绘制所有棋子
  List<Widget> _buildAllStones(
    List<GoGridNotifier> grids,
    int size,
    double cellSize,
    double offset,
    double stoneRadius,
  ) {
    return grids.asMap().entries.map((entry) {
      final int index = entry.key;
      final GoGridNotifier notifier = entry.value;
      return _buildStone(
        notifier: notifier,
        index: index,
        size: size,
        cellSize: cellSize,
        offset: offset,
        stoneRadius: stoneRadius,
        onTap: () => manager.placePiece(index),
      );
    }).toList();
  }

  // 绘制单个棋子
  Widget _buildStone({
    required GoGridNotifier notifier,
    required int index,
    required int size,
    required double cellSize,
    required double offset,
    required double stoneRadius,
    required VoidCallback onTap,
  }) {
    // 计算该棋子在棋盘上的坐标
    final int x = index % size;
    final int y = index ~/ size;
    final double left = offset + x * cellSize - stoneRadius;
    final double top = offset + y * cellSize - stoneRadius;

    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, grid, __) {
        if (!grid.isEmpty()) {
          // 有棋子时绘制棋子
          return Positioned(
            left: left,
            top: top,
            width: stoneRadius * 2,
            height: stoneRadius * 2,
            child: Container(
              decoration: BoxDecoration(
                color: grid.isBlack() ? Colors.black : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    spreadRadius: 1,
                    offset: const Offset(1, 1),
                  ),
                ],
                border: grid.isWhite()
                    ? Border.all(color: Colors.grey[300]!, width: 1)
                    : null,
              ),
            ),
          );
        } else {
          // 无棋子时显示点击区域，点击调用manager.placePiece(index)
          return Positioned(
            left: left,
            top: top,
            width: stoneRadius * 2,
            height: stoneRadius * 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(stoneRadius),
                onTap: onTap,
                // 可选：添加悬停效果（桌面平台）
                hoverColor: Colors.black12,
              ),
            ),
          );
        }
      },
    );
  }
}
