import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/08.sudoku/algorithm.dart';
import 'package:treasure/08.sudoku/base.dart';
import 'package:treasure/08.sudoku/manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('通关时读取并保留数独项目目录中已有的最佳用时', () async {
    final storage = StorageService.instance;
    storage.resetForTesting();
    final directory = await Directory.systemTemp.createTemp('sudoku_best_');
    storage.overrideBaseDir = directory;
    Manager? manager;
    try {
      await storage.init();
      await storage.write('sudoku_best', {'diff_0': 777}, project: '08.sudoku');
      manager = Manager();
      final size = manager.boardSize;
      final cells = manager.cells;
      final puzzle = List.generate(
        size,
        (row) => List.generate(size, (col) {
          final cell = cells[row * size + col];
          return cell.type == CellType.fixed ? cell.fixedDigit : 0;
        }),
      );
      final solution = BacktrackingSolver(level: manager.boardLevel)
          .solve(puzzle);
      for (final cell in cells) {
        if (cell.type == CellType.fixed) continue;
        cell.addDigit(solution[cell.row][cell.col]);
        cell.lock();
      }
      manager.checkCompleted();
      expect(manager.isGameOver.value, isTrue);

      Map<String, dynamic> saved = {};
      for (var attempt = 0; attempt < 100; attempt++) {
        saved = await storage.read('sudoku_best', project: '08.sudoku');
        if (saved.length > 1) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(saved['diff_0'], 777);
      expect(saved.length, 2);
    } finally {
      manager?.leavePage();
      // 等待通关时触发的异步存储操作结束，再删除 Windows 临时目录。
      await Future<void>.delayed(const Duration(milliseconds: 50));
      storage.resetForTesting();
      final tempRoot = Directory.systemTemp.absolute.path;
      final target = directory.absolute.path;
      if (!target.startsWith('$tempRoot${Platform.pathSeparator}') ||
          !directory.uri.pathSegments.any(
            (part) => part.startsWith('sudoku_best_'),
          )) {
        throw StateError('Unexpected temporary directory: $target');
      }
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
