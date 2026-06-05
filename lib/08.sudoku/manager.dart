import 'package:flutter/material.dart';

import '../00.common/widget/magic_celebration.dart';
import '../00.common/style/theme.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/tool/timer_counter.dart';
import '../l10n/strings.dart';
import 'algorithm.dart';
import 'base.dart';

class Manager {
  late final TimerCounter _timer; // 计时器

  int boardLevel = 3; // 固定为9x9数独（3x3宫格）
  late int boardSize; // 棋盘尺寸（9x9）
  late int _difficulty; // 移除的数字数量（9-64）

  late List<List<int>> _solution; // 存储数独的解

  final ValueNotifier<bool> isGameOver = ValueNotifier(false);
  final ValueNotifier<bool> nightTheme = ValueNotifier(false);
  final ListNotifier<CellNotifier> cells = ListNotifier([]);
  final ValueNotifier<int> selectedCellIndex = ValueNotifier(-1);

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  Manager() {
    _initTimer();
    _initDifficulty();
    _initGame();
  }

  void _initTimer() {
    _timer = TimerCounter(const Duration(seconds: 1), (_) {});
  }

  void _initDifficulty() {
    _difficulty = boardLevel * boardLevel * boardLevel;
  }

  /// 初始化游戏
  void _initGame() {
    _initCells();
    _timer.restart();
    isGameOver.value = false;
  }

  /// 生成数独谜题（保证唯一解）
  void _initCells() {
    cells.clear();

    // 使用SudokuGenerator生成数独
    SudokuGenerator generator = SudokuGenerator(
      level: boardLevel,
      target: _difficulty,
    );
    _solution = generator.getSolution();
    List<List<int>> sudoku = generator.generate();

    // 更新难度为实际生成的难度（可能已降低）
    _difficulty = generator.target;

    // 从boardLevel中获取boardSize
    boardSize = boardLevel * boardLevel;

    // 将生成的数独填充到单元格
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        final value = sudoku[i][j];
        if (value != 0) {
          // 预填的数字设为固定类型
          cells.add(
            CellNotifier(
              SudokuCell(
                row: i,
                col: j,
                type: CellType.fixed,
                fixedDigit: value,
              ),
            ),
          );
        } else {
          // 空白格子设为可编辑
          cells.add(
            CellNotifier(SudokuCell(row: i, col: j, type: CellType.editable)),
          );
        }
      }
    }
  }

  /// 选择单元格
  void selectCell(int index) {
    if (isGameOver.value) return;

    if (selectedCellIndex.value == index) {
      selectedCell.hint = false;
      selectedCellIndex.value = -1;
    } else {
      _clearSelectedCell();
      selectedCellIndex.value = index;
      selectedCell.hint = true;
    }
  }

  void _clearSelectedCell() {
    if (selectedCellIndex.value != -1) {
      selectedCell.hint = false;
      selectedCellIndex.value = -1;
    }
  }

  CellNotifier get selectedCell => cells[selectedCellIndex.value];

  /// 检查游戏是否完成（所有单元格已锁定且正确）
  void checkCompleted() {
    for (var cell in cells) {
      if (cell.type == CellType.editable || !isCellCorrect(cell)) {
        return;
      }
    }

    _handleGameOver();
  }

  /// 检查单元格的值是否正确
  bool isCellCorrect(CellNotifier cell) {
    final solutionValue = _solution[cell.row][cell.col];
    return cell.fixedDigit == solutionValue;
  }

  /// 游戏完成处理
  void _handleGameOver() {
    _timer.stop();
    _clearSelectedCell();

    isGameOver.value = true;
    _showCompletionDialog();
  }

  /// 显示难度设置对话框
  void showSelector() {
    pageNavigator.value = (context) => DialogTemplate.intSliderDialog(
      context: context,
      title: S.setDifficulty,
      sliderData: IntSliderData(
        start: boardSize,
        end: boardSize * (boardSize - 2) + 1,
        value: _difficulty,
        step: 1,
      ),
      onConfirm: _changeDifficulty,
    );
  }

  /// 更改难度系数
  void _changeDifficulty(int value) {
    if (value != _difficulty) {
      _difficulty = value;
      resetGame();
    }
  }

  void changeLevel(int value) {
    if (value != boardLevel) {
      boardLevel = value;
      resetGame();
    }
  }

  void setNightTheme(bool value) {
    if (nightTheme.value != value) {
      nightTheme.value = value;
    }
  }

  /// 重置游戏
  void resetGame() {
    _clearSelectedCell();
    _initGame();
  }

  void leavePage() {
    pageNavigator.value = (context) {
      _showLeaveDialog(context);
    };
  }

  void _showLeaveDialog(BuildContext context) {
    DialogTemplate.confirmDialog(
      context: context,
      title: S.pleaseConfirm,
      content: S.leaveRoomLoseProgress,
      before: () => true,
      onTap: _navigateToBack,
      after: () {},
    );
  }

  void _showCompletionDialog() {
    pageNavigator.value = (context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return _buildCongratulations(context);
        },
      );
    };
  }

  // 完成庆祝对话框
  Widget _buildCongratulations(BuildContext context) {
    return AlertDialog(
      backgroundColor: nightTheme.value
          ? MagicTheme.magicBackground
          : BaseTheme.backgroundColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.congratulations,
            style: nightTheme.value
                ? MagicTheme.titleStyle
                : BaseTheme.titleStyle,
          ),
          const SizedBox(height: 16),
          Text(
            S.difficultyTime('$_difficulty', TimerCounter.formatDuration(_timer.tick)),
            style: nightTheme.value
                ? MagicTheme.bodyStyle
                : BaseTheme.bodyStyle,
          ),
          const SizedBox(height: 16),
          // 魔法庆祝动画
          const MagicCelebrationAnimation(),
          const SizedBox(height: 16),
          ElevatedButton(
            style: nightTheme.value
                ? MagicTheme.crystalButtonStyle(false)
                : null,
            onPressed: () {
              Navigator.pop(context);
              resetGame();
            },
            child: Text(S.startNewGame),
          ),
        ],
      ),
    );
  }

  void _navigateToBack() {
    pageNavigator.value = (context) {
      Navigator.pop(context);
    };
  }
}
