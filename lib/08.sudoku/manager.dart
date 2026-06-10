import 'package:flutter/material.dart';

import '../00.common/widget/effect/magic_celebration.dart';
import '../00.common/style/theme.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/tool/storage_service.dart';
import '../00.common/l10n/strings.dart';
import 'algorithm.dart';
import 'base.dart';
import 'import_page.dart';

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
    _loadProgress();
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
    _clearProgress(); // 通关后清除存档
    _saveBestTime(); // 保存最佳用时
    _showCompletionDialog();
  }

  /// 保存最佳用时
  Future<void> _saveBestTime() async {
    final data = await StorageService.instance.read('sudoku_best');
    final key = 'diff_$_difficulty';
    final best = data[key] as int? ?? 0;
    if (best == 0 || _timer.tick < best) {
      data[key] = _timer.tick;
      await StorageService.instance.write('sudoku_best', data);
    }
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
    _clearProgress();
  }

  // ==================== 格子操作（包装 CellNotifier，自动保存） ====================

  void addDigit(int digit) {
    if (selectedCellIndex.value < 0) return;
    selectedCell.addDigit(digit);
    _saveProgress();
  }

  void removeDigit(int digit) {
    if (selectedCellIndex.value < 0) return;
    selectedCell.removeDigit(digit);
    _saveProgress();
  }

  void clearDigits() {
    if (selectedCellIndex.value < 0) return;
    selectedCell.clearDigits();
    _saveProgress();
  }

  void lockCell() {
    if (selectedCellIndex.value < 0) return;
    selectedCell.lock();
    _saveProgress();
    checkCompleted();
  }

  void unlockCell() {
    if (selectedCellIndex.value < 0) return;
    selectedCell.unlock();
    _saveProgress();
  }

  void openImport() {
    pageNavigator.value = (context) async {
      final result = await Navigator.push<List<List<int>>>(
        context,
        MaterialPageRoute(builder: (_) => const SudokuImportPage()),
      );
      if (result != null && context.mounted) {
        loadImportedPuzzle(result);
      }
    };
  }

  void loadImportedPuzzle(List<List<int>> puzzle) {
    _clearSelectedCell();
    boardSize = 9;
    boardLevel = 3;
    _difficulty = 0;

    final solver = BacktrackingSolver(level: boardLevel);
    _solution = solver.solve(puzzle);

    cells.clear();
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        final value = puzzle[i][j];
        if (value != 0) {
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
          cells.add(
            CellNotifier(SudokuCell(row: i, col: j, type: CellType.editable)),
          );
        }
      }
    }

    _timer.restart();
    isGameOver.value = false;
    _clearProgress();
  }

  void leavePage() {
    _saveProgress(); // 退出前自动保存
    _navigateToBack();
  }

  void _showCompletionDialog() {
    pageNavigator.value = (context) {
      showDialog<void>(
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
            S.difficultyTime(
              '$_difficulty',
              TimerCounter.formatDuration(_timer.tick),
            ),
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

  // ==================== 持久化 ====================

  /// 保存进度到文件
  Future<void> _saveProgress() async {
    if (isGameOver.value) return; // 游戏结束不保存

    final cellData = <Map<String, dynamic>>[];
    for (var cell in cells) {
      cellData.add({
        'row': cell.row,
        'col': cell.col,
        'type': cell.type.index,
        'fixedDigit': cell.fixedDigit,
        'spareDigits': cell.spareDigits.toList(),
      });
    }

    await StorageService.instance.write('sudoku', {
      'boardLevel': boardLevel,
      'boardSize': boardSize,
      'difficulty': _difficulty,
      'elapsed': _timer.tick,
      'solution': _solution,
      'cells': cellData,
    });
  }

  /// 从文件加载进度
  Future<void> _loadProgress() async {
    final data = await StorageService.instance.read('sudoku');
    if (data.isEmpty) return;

    try {
      boardLevel = data['boardLevel'] as int? ?? 3;
      boardSize = data['boardSize'] as int? ?? 9;
      _difficulty = data['difficulty'] as int? ?? 27;
      final elapsed = data['elapsed'] as int? ?? 0;

      // 恢复解
      final solutionList = data['solution'] as List<dynamic>?;
      if (solutionList == null || solutionList.length != boardSize) return;
      _solution = List.generate(
        boardSize,
        (i) => List<int>.from(solutionList[i] as List<dynamic>),
      );

      // 恢复格子
      final cellData = data['cells'] as List<dynamic>?;
      if (cellData == null || cellData.length != boardSize * boardSize) return;

      cells.clear();
      for (var cellJson in cellData) {
        final map = cellJson as Map<String, dynamic>;
        final type = CellType.values[map['type'] as int];
        final fixedDigit = map['fixedDigit'] as int? ?? 0;
        final spareDigits = List<int>.from(
          map['spareDigits'] as List<dynamic>? ?? [],
        );

        final cell = CellNotifier(
          SudokuCell(
            row: map['row'] as int,
            col: map['col'] as int,
            type: type,
            fixedDigit: fixedDigit,
          ),
        );
        for (var d in spareDigits) {
          cell.addDigit(d);
        }
        cells.add(cell);
      }

      // 恢复计时器（从已保存的秒数继续）
      _timer.stop();
      _timer.setTick(elapsed);
      _timer.start();

      isGameOver.value = false;
    } catch (e) {
      debugPrint('[Sudoku] Load progress failed: $e');
      // 加载失败，保持当前新游戏状态
    }
  }

  /// 清除保存的进度
  Future<void> _clearProgress() async {
    await StorageService.instance.delete('sudoku');
  }
}
