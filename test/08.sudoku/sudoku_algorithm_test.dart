import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/08.sudoku/algorithm.dart';
import 'package:treasure/08.sudoku/base.dart';

void main() {
  const solution = [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1],
  ];
  const puzzle = [
    [1, 0, 3, 4],
    [3, 4, 0, 2],
    [2, 1, 4, 0],
    [0, 3, 2, 1],
  ];

  group('Sudoku solvers', () {
    for (final solver in [BacktrackingSolver(level: 2), DLXSolver(level: 2)]) {
      test('${solver.runtimeType} 求解并确认唯一解', () {
        expect(solver.countSolutions(puzzle), 1);
        expect(solver.solve(puzzle), solution);
        expect(puzzle[0][1], 0, reason: '求解器不得修改输入棋盘');
      });
    }

    test('回溯求解器拒绝已填满但违反规则的棋盘', () {
      final invalid = solution.map(List<int>.from).toList();
      invalid[0][1] = 1;
      final solver = BacktrackingSolver(level: 2);

      expect(solver.countSolutions(invalid), 0);
      expect(solver.solve(invalid), isEmpty);
    });

    test('生成器产出合法且唯一的 4x4 谜题', () {
      final generator = SudokuGenerator(level: 2, target: 4, random: Random(7));
      final generated = generator.generate();
      final solver = BacktrackingSolver(level: 2);

      expect(generated, hasLength(4));
      expect(
        generated.expand((row) => row).where((v) => v == 0).length,
        generator.target,
      );
      expect(solver.isUniqueSolution(generated), isTrue);
      expect(solver.solve(generated), generator.getSolution());
    });
  });

  group('CellNotifier', () {
    test('候选数字去重排序，单候选可锁定并解锁', () {
      final cell = CellNotifier(
        SudokuCell(row: 1, col: 2, type: CellType.editable),
      );
      cell
        ..addDigit(3)
        ..addDigit(1)
        ..addDigit(3);
      expect(cell.spareDigits, [1, 3]);
      expect(cell.canLock, isFalse);

      cell.removeDigit(3);
      expect(cell.canLock, isTrue);
      cell.lock();
      expect(cell.type, CellType.locked);
      expect(cell.fixedDigit, 1);

      cell.unlock();
      expect(cell.type, CellType.editable);
      expect(cell.fixedDigit, 0);
    });
  });
}
