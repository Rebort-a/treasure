import 'dart:async';
import 'dart:io';

import 'package:treasure/00.common/service/json_store.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/08.sudoku/algorithm.dart';
import 'package:treasure/08.sudoku/base.dart';
import 'package:treasure/08.sudoku/manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> progress() {
    final solution = List.generate(
      9,
      (r) => List.generate(9, (c) => (r * 3 + r ~/ 3 + c) % 9 + 1),
    );
    return {
      'solution': solution,
      'cells': [
        for (var r = 0; r < 9; r++)
          for (var c = 0; c < 9; c++)
            <String, dynamic>{
              'row': r,
              'col': c,
              'type': 0,
              'fixedDigit': solution[r][c],
            },
      ],
    };
  }

  test('旧格式缺省字段可加载，损坏存档不部分覆盖新局', () async {
    final store = _DelayedStore();
    final manager = Manager(store: store);
    store.pending.complete(progress());
    await Future<void>.delayed(Duration.zero);
    expect(manager.cells.every((cell) => cell.type == CellType.fixed), isTrue);
    expect(manager.boardSize, 9);
    manager.dispose();

    for (final corrupt in [
      (Map<String, dynamic> data) => data['boardSize'] = 4,
      (Map<String, dynamic> data) => (data['solution'] as List)[8] = [1],
      (Map<String, dynamic> data) => (data['cells'] as List)[80]['row'] = 0,
      (Map<String, dynamic> data) => (data['cells'] as List)[80]['type'] = 99,
      (Map<String, dynamic> data) =>
          (data['cells'] as List)[80]['spareDigits'] = [10],
    ]) {
      final store = _DelayedStore();
      final manager = Manager(store: store);
      final before = manager.cells.toList();
      final data = progress();
      corrupt(data);
      store.pending.complete(data);
      await Future<void>.delayed(Duration.zero);
      expect(manager.cells.toList(), before);
      expect(manager.boardSize, 9);
      manager.dispose();
    }
  });

  for (final action in ['restart', 'import', 'leave', 'dispose']) {
    test('导入结果不能覆盖 $action 后的棋局', () async {
      final store = _DelayedStore();
      final manager = Manager(store: store);
      store.pending.complete({});
      await Future<void>.delayed(Duration.zero);
      final operation = manager.beginImport();
      switch (action) {
        case 'restart':
          manager.resetGame();
        case 'import':
          manager.loadImportedPuzzle(
            List.generate(9, (_) => List.filled(9, 0)),
          );
        case 'leave':
          manager.leavePage();
        case 'dispose':
          manager.dispose();
      }
      final before = manager.cells.toList();
      manager.completeImport(
        operation,
        List.generate(9, (_) => List.filled(9, 0)),
      );
      expect(manager.cells.toList(), before);
      manager.dispose();
    });
    test('迟到读档不能覆盖 $action 后的棋局', () async {
      final store = _DelayedStore();
      final manager = Manager(store: store);
      switch (action) {
        case 'restart':
          manager.resetGame();
        case 'import':
          manager.loadImportedPuzzle(
            List.generate(9, (_) => List.filled(9, 0)),
          );
        case 'leave':
          manager.leavePage();
        case 'dispose':
          manager.dispose();
      }
      final before = manager.cells.toList();
      store.pending.complete(progress());
      await Future<void>.delayed(Duration.zero);
      expect(manager.cells.toList(), before);
      manager.dispose();
    });
  }

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
      manager?.dispose();
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

class _DelayedStore implements JsonStore {
  final pending = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) => pending.future;

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {}
}
