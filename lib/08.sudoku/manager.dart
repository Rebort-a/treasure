import 'package:flutter/widgets.dart';

import '../00.common/sound/sound_manager.dart';

import '../00.common/model/notifiers.dart';
import '../00.common/tool/timer_counter.dart';
import '../00.common/service/storage_service.dart';
import '../00.common/service/json_store.dart';
import 'algorithm.dart';
import 'base.dart';

class Manager with SoundEmitter {
  late final TimerCounter _timer; // 计时器

  int boardLevel = 3; // 固定为9x9数独（3x3宫格）
  late int boardSize; // 棋盘尺寸（9x9）
  late int _difficulty; // 移除的数字数量（9-64）

  late List<List<int>> _solution; // 存储数独的解

  final ValueNotifier<bool> isGameOver = ValueNotifier(false);
  final ValueNotifier<bool> nightTheme = ValueNotifier(false);
  final ListNotifier<CellNotifier> cells = ListNotifier([]);
  final ValueNotifier<int> selectedCellIndex = ValueNotifier(-1);

  final JsonStore _store;
  bool _disposed = false;
  bool _leaving = false;
  int get difficulty => _difficulty;
  int get minDifficulty => boardSize;
  int get maxDifficulty => boardSize * (boardSize - 2) + 1;
  int get elapsed => _timer.tick;
  int _operation = 0;
  final Set<CellNotifier> _retiredCells = {};

  Manager({JsonStore? store}) : _store = store ?? StorageService.instance {
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
    emitSound(Sound.reset);
    _initCells();
    _timer.restart();
    isGameOver.value = false;
  }

  /// 生成数独谜题（保证唯一解）
  void _initCells() {
    _clearCells();

    // 使用SudokuGenerator生成数独
    SudokuGenerator generator = SudokuGenerator(
      level: boardLevel,
      target: _difficulty,
    );
    List<List<int>> sudoku = generator.generate();
    // 必须先生成棋盘，才能读取本局对应的完整解。
    _solution = generator.getSolution();

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
    if (_disposed || isGameOver.value) return;

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
    if (!isGameOver.value) emitSound(Sound.win);
    _timer.stop();
    _clearSelectedCell();

    isGameOver.value = true;
    _clearProgress(); // 通关后清除存档
    _saveBestTime(); // 保存最佳用时
  }

  /// 保存最佳用时
  Future<void> _saveBestTime() async {
    final operation = _operation;
    final tick = _timer.tick;
    final key = 'diff_$_difficulty';
    try {
      final data = await _store.read('sudoku_best', project: '08.sudoku');
      if (_disposed || operation != _operation) return;
      final saved = data[key];
      final best = saved is int && saved >= 0 ? saved : 0;
      if (best == 0 || tick < best) {
        data[key] = tick;
        await _store.write('sudoku_best', data, project: '08.sudoku');
      }
    } catch (error) {
      debugPrint('[Sudoku] Save best time failed: $error');
    }
  }

  /// 更改难度系数
  void changeDifficulty(int value) {
    if (_disposed || _leaving) return;
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
    if (_disposed || _leaving) return;
    _operation++;
    _clearSelectedCell();
    _initGame();
    _clearProgress();
  }

  // ==================== 格子操作（包装 CellNotifier，自动保存） ====================

  void addDigit(int digit) {
    if (selectedCellIndex.value < 0) return;
    final before = selectedCell.spareDigits.length;
    selectedCell.addDigit(digit);
    if (selectedCell.spareDigits.length > before) emitSound(Sound.tap);
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
    final canLock = selectedCell.canLock;
    selectedCell.lock();
    if (canLock) {
      emitSound(isCellCorrect(selectedCell) ? Sound.success : Sound.error);
    }
    _saveProgress();
    checkCompleted();
  }

  void unlockCell() {
    if (selectedCellIndex.value < 0) return;
    selectedCell.unlock();
    _saveProgress();
  }

  /// 导入结果仅能应用于发起导入的当前局。
  int beginImport() => ++_operation;

  void completeImport(int operation, List<List<int>> puzzle) {
    if (_disposed || _leaving || operation != _operation) return;
    loadImportedPuzzle(puzzle);
  }

  void loadImportedPuzzle(List<List<int>> puzzle) {
    if (_disposed || _leaving) return;
    _operation++;
    _clearSelectedCell();
    boardSize = 9;
    boardLevel = 3;
    _difficulty = 0;

    final solver = BacktrackingSolver(level: boardLevel);
    _solution = solver.solve(puzzle);

    _clearCells();
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
    if (_disposed || _leaving) return;
    _operation++;
    _timer.stop();
    _saveProgress(); // 退出前自动保存
    _leaving = true;
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

    try {
      await _store.write('sudoku', {
        'boardLevel': boardLevel,
        'boardSize': boardSize,
        'difficulty': _difficulty,
        'elapsed': _timer.tick,
        'solution': _solution,
        'cells': cellData,
      }, project: '08.sudoku');
    } catch (error) {
      debugPrint('[Sudoku] Save progress failed: $error');
    }
  }

  /// 完整解码和校验后再提交，失败时不改变当前棋局。
  Future<void> _loadProgress() async {
    final operation = _operation;
    final restored = <CellNotifier>[];
    try {
      final data = await _store.read('sudoku', project: '08.sudoku');
      if (_disposed || operation != _operation || data.isEmpty) return;
      final level = data['boardLevel'] as int? ?? 3;
      final size = data['boardSize'] as int? ?? 9;
      final difficulty = data['difficulty'] as int? ?? 27;
      final elapsed = data['elapsed'] as int? ?? 0;
      if (level != 3 ||
          size != 9 ||
          difficulty < 0 ||
          difficulty > 81 ||
          elapsed < 0) {
        throw const FormatException('Invalid board metadata');
      }
      final rawSolution = data['solution'] as List;
      if (rawSolution.length != size) {
        throw const FormatException('Invalid solution');
      }
      final solution = rawSolution
          .map((row) => List<int>.from(row as List))
          .toList();
      bool validGroup(Iterable<int> group) =>
          group.length == size &&
          group.toSet().length == size &&
          group.every((d) => d >= 1 && d <= size);
      for (var i = 0; i < size; i++) {
        if (!validGroup(solution[i]) ||
            !validGroup(solution.map((row) => row[i]))) {
          throw const FormatException('Invalid solution');
        }
      }
      for (var row = 0; row < size; row += level) {
        for (var col = 0; col < size; col += level) {
          if (!validGroup([
            for (var r = row; r < row + level; r++)
              for (var c = col; c < col + level; c++) solution[r][c],
          ])) {
            throw const FormatException('Invalid solution box');
          }
        }
      }
      final rawCells = data['cells'] as List;
      if (rawCells.length != size * size) {
        throw const FormatException('Invalid cells');
      }
      for (var i = 0; i < rawCells.length; i++) {
        final map = rawCells[i] as Map;
        final row = map['row'] as int;
        final col = map['col'] as int;
        final type = CellType.values[map['type'] as int];
        final digit = map['fixedDigit'] as int? ?? 0;
        final spares = List<int>.from(map['spareDigits'] as List? ?? []);
        if (row != i ~/ size ||
            col != i % size ||
            digit < 0 ||
            digit > size ||
            spares.any((d) => d < 1 || d > size) ||
            spares.toSet().length != spares.length ||
            (type == CellType.editable ? digit != 0 : digit == 0) ||
            (type == CellType.fixed && digit != solution[row][col])) {
          throw const FormatException('Invalid cell');
        }
        final cell = CellNotifier(
          SudokuCell(row: row, col: col, type: type, fixedDigit: digit),
        );
        restored.add(cell);
        for (final d in spares) {
          cell.addDigit(d);
        }
      }
      _clearSelectedCell();
      _clearCells();
      boardLevel = level;
      boardSize = size;
      _difficulty = difficulty;
      _solution = solution;
      cells.addAll(restored);
      restored.clear();
      _timer.stop();
      _timer.setTick(elapsed);
      _timer.start();
      isGameOver.value = false;
    } catch (e) {
      debugPrint('[Sudoku] Load progress failed: $e');
    } finally {
      for (final cell in restored) {
        cell.dispose();
      }
    }
  }

  void _clearCells() {
    _retiredCells.addAll(cells);
    cells.clear();
    // 旧棋盘在下一帧解绑后才能安全释放子状态。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _leaving) return;
      for (final cell in _retiredCells) {
        cell.dispose();
      }
      _retiredCells.clear();
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operation++;
    _timer.dispose();
    disposeAudioEvents();
    for (final cell in {...cells, ..._retiredCells}) {
      cell.dispose();
    }
    _retiredCells.clear();
    cells.dispose();
    isGameOver.dispose();
    nightTheme.dispose();
    selectedCellIndex.dispose();
  }

  /// 清除保存的进度
  Future<void> _clearProgress() async {
    try {
      final store = _store;
      if (store is StorageService) {
        await store.delete('sudoku', project: '08.sudoku');
      } else {
        await store.write('sudoku', {}, project: '08.sudoku');
      }
    } catch (error) {
      debugPrint('[Sudoku] Clear progress failed: $error');
    }
  }
}
