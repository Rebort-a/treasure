import 'dart:math';

/// 数独生成器类
class SudokuGenerator {
  late List<List<int>> _sudoku;
  late List<List<int>> _solution;
  late final int _size;
  final int level;
  int target;

  SudokuGenerator({required this.level, required this.target}) {
    _size = level * level;
    _sudoku = List.generate(_size, (i) => List.filled(_size, 0));
    _solution = List.generate(_size, (i) => List.filled(_size, 0));
  }

  /// 生成数独谜题
  List<List<int>> generate() {
    // 首先生成一个完整的数独解
    _generateSolution();

    // 复制完整解到数独
    _sudoku = _copySolution();

    // 根据难度移除数独中的数字，确保唯一解
    _removeNumbers();

    // 返回移除后的数独
    return _sudoku;
  }

  /// 获取完整解
  List<List<int>> getSolution() {
    return _solution;
  }

  /// 复制解决方案
  List<List<int>> _copySolution() {
    return _solution.map((row) => List<int>.from(row)).toList();
  }

  /// 生成完整解决方案
  void _generateSolution() {
    _fillDiagonalBoxes();
    _fillRemaining(0, level);
  }

  /// 填充对角线上的宫格
  void _fillDiagonalBoxes() {
    for (int i = 0; i < _size; i += level) {
      _fillBox(i, i);
    }
  }

  /// 填充指定位置的宫格
  void _fillBox(int row, int col) {
    final random = Random();
    int num;

    for (int i = 0; i < level; i++) {
      for (int j = 0; j < level; j++) {
        do {
          num = random.nextInt(_size) + 1;
        } while (!_isNumberUsedInBox(row, col, num));

        _solution[row + i][col + j] = num;
      }
    }
  }

  /// 填充剩余单元格
  bool _fillRemaining(int i, int j) {
    if (j >= _size && i < _size - 1) {
      i += 1;
      j = 0;
    }
    if (i >= _size && j >= _size) {
      return true;
    }
    if (i < level) {
      if (j < level) {
        j = level;
      }
    } else if (i < _size - level) {
      if (j == (i ~/ level) * level) {
        j += level;
      }
    } else {
      if (j == _size - level) {
        i += 1;
        j = 0;
        if (i >= _size) {
          return true;
        }
      }
    }

    for (int num = 1; num <= _size; num++) {
      if (_isValid(i, j, num)) {
        _solution[i][j] = num;
        if (_fillRemaining(i, j + 1)) {
          return true;
        }
        _solution[i][j] = 0;
      }
    }
    return false;
  }

  /// 检查数字在指定位置是否有效
  bool _isValid(int row, int col, int num) {
    return _isRowValid(row, num) &&
        _isColValid(col, num) &&
        _isBoxValid(row, col, num);
  }

  /// 检查数字在行中是否有效
  bool _isRowValid(int row, int num) {
    for (int col = 0; col < _size; col++) {
      if (_solution[row][col] == num) {
        return false;
      }
    }
    return true;
  }

  /// 检查数字在列中是否有效
  bool _isColValid(int col, int num) {
    for (int row = 0; row < _size; row++) {
      if (_solution[row][col] == num) {
        return false;
      }
    }
    return true;
  }

  /// 检查数字在宫格中是否有效
  bool _isBoxValid(int row, int col, int num) {
    int boxRowStart = row - row % level;
    int boxColStart = col - col % level;

    return _isNumberUsedInBox(boxRowStart, boxColStart, num);
  }

  /// 检查数字是否在宫格中使用过
  bool _isNumberUsedInBox(int boxRow, int boxCol, int num) {
    for (int i = 0; i < level; i++) {
      for (int j = 0; j < level; j++) {
        if (_solution[boxRow + i][boxCol + j] == num) {
          return false;
        }
      }
    }
    return true;
  }

  /// 移除数字以创建谜题
  void _removeNumbers() {
    int removed = 0;
    List<int> allCells = List.generate(_size * _size, (index) => index);
    allCells.shuffle();

    // 默认使用回溯法求解器
    final solver = BacktrackingSolver(level: level);

    for (int cellIndex in allCells) {
      int row = cellIndex ~/ _size;
      int col = cellIndex % _size;

      if (_sudoku[row][col] == 0) continue;

      int tempValue = _sudoku[row][col];
      _sudoku[row][col] = 0;

      // 检查是否仍有唯一解
      if (solver.isUniqueSolution(_sudoku)) {
        removed++;
        if (removed == target) {
          break;
        }
      } else {
        _sudoku[row][col] = tempValue;
      }
    }

    if (removed < target) {
      target = removed;
    }
  }
}

/// 求解算法类型
enum SolvingAlgorithm { backtracking, dlx }

/// 数独求解器接口
abstract class SudokuSolver {
  final int level;
  late final int _size;

  SudokuSolver({required this.level}) {
    _size = level * level;
  }

  /// 计算数独解的数量（有限制）
  int countSolutions(List<List<int>> sudoku, {int limit = 2});

  /// 判断数独是否有唯一解
  bool isUniqueSolution(List<List<int>> sudoku) {
    return countSolutions(sudoku, limit: 2) == 1;
  }

  /// 求解数独
  List<List<int>> solve(List<List<int>> sudoku);
}

/// 回溯法求解器
class BacktrackingSolver extends SudokuSolver {
  BacktrackingSolver({required super.level});

  @override
  int countSolutions(List<List<int>> sudoku, {int limit = 2}) {
    List<List<int>> copy = List.generate(_size, (i) => List.from(sudoku[i]));
    return _backtrackCount(copy, limit);
  }

  @override
  List<List<int>> solve(List<List<int>> sudoku) {
    List<List<int>> copy = List.generate(_size, (i) => List.from(sudoku[i]));
    _backtrackSolve(copy);
    return copy;
  }

  /// 回溯法计算解的数量（带限制）
  int _backtrackCount(List<List<int>> board, int maxSolutions) {
    final pos = _findEmptyCell(board);
    if (pos == null) {
      return 1;
    }

    final row = pos[0];
    final col = pos[1];
    int count = 0;

    for (int num = 1; num <= _size; num++) {
      if (_isValidMove(board, row, col, num)) {
        board[row][col] = num;

        count += _backtrackCount(board, maxSolutions - count);

        board[row][col] = 0;

        if (count >= maxSolutions) {
          return count;
        }
      }
    }

    return count;
  }

  /// 回溯法求解数独
  bool _backtrackSolve(List<List<int>> board) {
    final pos = _findEmptyCell(board);
    if (pos == null) {
      return true;
    }

    final row = pos[0];
    final col = pos[1];

    for (int num = 1; num <= _size; num++) {
      if (_isValidMove(board, row, col, num)) {
        board[row][col] = num;

        if (_backtrackSolve(board)) {
          return true;
        }

        board[row][col] = 0;
      }
    }

    return false;
  }

  /// 检查移动是否有效
  bool _isValidMove(List<List<int>> board, int row, int col, int num) {
    // 检查行
    for (int i = 0; i < _size; i++) {
      if (board[row][i] == num) {
        return false;
      }
    }

    // 检查列
    for (int i = 0; i < _size; i++) {
      if (board[i][col] == num) {
        return false;
      }
    }

    // 检查宫格
    final boxRow = (row ~/ level) * level;
    final boxCol = (col ~/ level) * level;

    for (int i = 0; i < level; i++) {
      for (int j = 0; j < level; j++) {
        if (board[boxRow + i][boxCol + j] == num) {
          return false;
        }
      }
    }

    return true;
  }

  /// 寻找空单元格
  List<int>? _findEmptyCell(List<List<int>> board) {
    int minCandidates = _size + 1;
    List<int>? bestPos;

    for (int i = 0; i < _size; i++) {
      for (int j = 0; j < _size; j++) {
        if (board[i][j] == 0) {
          int candidates = 0;
          for (int num = 1; num <= _size; num++) {
            if (_isValidMove(board, i, j, num)) {
              candidates++;
              if (candidates >= minCandidates) break;
            }
          }

          if (candidates < minCandidates) {
            minCandidates = candidates;
            bestPos = [i, j];

            if (minCandidates == 1) {
              return bestPos;
            }
          }
        }
      }
    }

    return bestPos;
  }
}

/// DLX算法求解器
class DLXSolver extends SudokuSolver {
  DLXSolver({required super.level});

  @override
  int countSolutions(List<List<int>> sudoku, {int limit = 2}) {
    List<List<int>> matrix = _createExactCoverMatrix(sudoku);
    final dlx = DLX(matrix);
    return dlx.countSolutions(limit: limit);
  }

  @override
  List<List<int>> solve(List<List<int>> sudoku) {
    List<List<int>> matrix = _createExactCoverMatrix(sudoku);
    final dlx = DLX(matrix);
    List<int> solution = dlx.findFirstSolution();

    if (solution.isEmpty) return [];

    return _convertSolutionToGrid(solution);
  }

  /// 创建精确覆盖矩阵
  List<List<int>> _createExactCoverMatrix(List<List<int>> sudoku) {
    int constraints = 4 * _size * _size;
    int possibilities = _size * _size * _size;
    List<List<int>> matrix = List.generate(
      possibilities,
      (i) => List.filled(constraints, 0),
    );

    int row, col, num, idx = 0;

    for (row = 0; row < _size; row++) {
      for (col = 0; col < _size; col++) {
        for (num = 1; num <= _size; num++) {
          if (sudoku[row][col] != 0 && sudoku[row][col] != num) {
            idx++;
            continue;
          }

          // 行-列约束
          matrix[idx][row * _size + col] = 1;

          // 行-数约束
          matrix[idx][_size * _size + row * _size + (num - 1)] = 1;

          // 列-数约束
          matrix[idx][2 * _size * _size + col * _size + (num - 1)] = 1;

          // 宫-数约束
          int box = (row ~/ level) * level + (col ~/ level);
          matrix[idx][3 * _size * _size + box * _size + (num - 1)] = 1;

          idx++;
        }
      }
    }

    return matrix;
  }

  /// 将一维解转换为二维数独网格
  List<List<int>> _convertSolutionToGrid(List<int> solution) {
    List<List<int>> result = List.generate(_size, (i) => List.filled(_size, 0));

    for (int val in solution) {
      int num = (val % _size) + 1;
      int pos = val ~/ _size;
      int row = pos ~/ _size;
      int col = pos % _size;
      result[row][col] = num;
    }

    return result;
  }
}

/// DLX算法节点
class DLXNode {
  DLXNode? left, right, up, down;
  DLXNode? column;
  int row = -1;
  int size = 0;

  DLXNode();
}

/// DLX算法实现
class DLX {
  final List<List<int>> matrix;
  late DLXNode root;
  late List<DLXNode> columns;
  int solutionCount = 0;
  int limit = 0;

  DLX(this.matrix) {
    _buildMatrix();
  }

  /// 构建矩阵
  void _buildMatrix() {
    int cols = matrix.isEmpty ? 0 : matrix[0].length;
    columns = List.generate(cols, (_) => DLXNode());

    // 初始化列节点
    for (int i = 0; i < cols; i++) {
      columns[i].left = i > 0 ? columns[i - 1] : columns.last;
      columns[i].right = i < cols - 1 ? columns[i + 1] : columns.first;
      columns[i].up = columns[i];
      columns[i].down = columns[i];
    }

    // 创建根节点
    root = DLXNode();
    root.right = columns.first;
    root.left = columns.last;
    columns.first.left = root;
    columns.last.right = root;

    // 添加行
    for (int i = 0; i < matrix.length; i++) {
      DLXNode? last;
      for (int j = 0; j < cols; j++) {
        if (matrix[i][j] == 1) {
          DLXNode node = DLXNode();
          node.row = i;
          node.column = columns[j];

          // 连接上下
          node.up = columns[j].up;
          node.down = columns[j];
          columns[j].up!.down = node;
          columns[j].up = node;

          // 连接左右
          if (last == null) {
            node.left = node;
            node.right = node;
          } else {
            node.left = last;
            node.right = last.right;
            last.right!.left = node;
            last.right = node;
          }

          last = node;
          columns[j].size++;
        }
      }
    }
  }

  /// 计算解的数量
  int countSolutions({int limit = 0}) {
    this.limit = limit;
    solutionCount = 0;
    _search(0);
    return solutionCount;
  }

  /// 查找第一个解
  List<int> findFirstSolution() {
    List<int> solution = [];
    _searchWithSolution(0, solution);
    return solution;
  }

  /// 搜索解
  void _search(int k) {
    if (root.right == root) {
      solutionCount++;
      return;
    }

    if (limit > 0 && solutionCount >= limit) {
      return;
    }

    DLXNode col = _chooseColumn();
    _cover(col);

    for (DLXNode row = col.down!; row != col; row = row.down!) {
      for (DLXNode node = row.right!; node != row; node = node.right!) {
        _cover(node.column!);
      }

      _search(k + 1);

      if (limit > 0 && solutionCount >= limit) {
        for (DLXNode node = row.left!; node != row; node = node.left!) {
          _uncover(node.column!);
        }
        break;
      }

      for (DLXNode node = row.left!; node != row; node = node.left!) {
        _uncover(node.column!);
      }
    }

    _uncover(col);
  }

  /// 搜索解并保存结果
  bool _searchWithSolution(int k, List<int> solution) {
    if (root.right == root) {
      return true;
    }

    DLXNode col = _chooseColumn();
    _cover(col);

    for (DLXNode row = col.down!; row != col; row = row.down!) {
      solution.add(row.row);

      for (DLXNode node = row.right!; node != row; node = node.right!) {
        _cover(node.column!);
      }

      if (_searchWithSolution(k + 1, solution)) {
        return true;
      }

      solution.removeLast();

      for (DLXNode node = row.left!; node != row; node = node.left!) {
        _uncover(node.column!);
      }
    }

    _uncover(col);
    return false;
  }

  /// 选择列
  DLXNode _chooseColumn() {
    int minSize = 0;
    DLXNode? chosen;

    for (DLXNode col = root.right!; col != root; col = col.right!) {
      if (col.size < minSize || minSize == 0) {
        minSize = col.size;
        chosen = col;
      }
    }

    return chosen!;
  }

  /// 覆盖列
  void _cover(DLXNode col) {
    col.right!.left = col.left;
    col.left!.right = col.right;

    for (DLXNode row = col.down!; row != col; row = row.down!) {
      for (DLXNode node = row.right!; node != row; node = node.right!) {
        node.down!.up = node.up;
        node.up!.down = node.down;
        node.column!.size--;
      }
    }
  }

  /// 取消覆盖列
  void _uncover(DLXNode col) {
    for (DLXNode row = col.up!; row != col; row = row.up!) {
      for (DLXNode node = row.left!; node != row; node = node.left!) {
        node.column!.size++;
        node.down!.up = node;
        node.up!.down = node;
      }
    }

    col.right!.left = col;
    col.left!.right = col;
  }
}
