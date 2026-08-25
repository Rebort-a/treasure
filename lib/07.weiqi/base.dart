import 'package:flutter/material.dart';

import '../00.common/tool/notifiers.dart';

// 围棋棋子状态
enum StoneState { empty, black, white }

class GoGrid {
  final int coordinate;
  StoneState state = StoneState.empty;
  int liberties = 0; // 气的数量

  GoGrid({required this.coordinate});

  bool isEmpty() => state == StoneState.empty;
  bool isBlack() => state == StoneState.black;
  bool isWhite() => state == StoneState.white;
}

class GoGridNotifier extends ValueNotifier<GoGrid> {
  GoGridNotifier(super.value);

  void placeStone(StoneState stone) {
    value.state = stone;
    notifyListeners();
  }

  void clear() {
    value.state = StoneState.empty;
    notifyListeners();
  }

  void updateLiberties(int liberties) {
    value.liberties = liberties;
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 围棋规则纯逻辑 — 操作 List<StoneState>，无 Notifier，供 GoBoard 与 AI 共用
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class GoRules {
  static const _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

  static StoneState opponent(StoneState s) =>
      s == StoneState.black ? StoneState.white : StoneState.black;

  static bool _inBoard(int size, int r, int c) =>
      r >= 0 && r < size && c >= 0 && c < size;

  /// 单格直接气数（上下左右空位数）
  static int calculateLiberties(List<StoneState> cells, int size, int index) {
    final row = index ~/ size, col = index % size;
    int count = 0;
    for (final (dr, dc) in _dirs) {
      final r = row + dr, c = col + dc;
      if (_inBoard(size, r, c) && cells[r * size + c] == StoneState.empty) {
        count++;
      }
    }
    return count;
  }

  /// 棋链（同色连通，迭代实现避免栈溢出）
  static Set<int> findGroup(List<StoneState> cells, int size, int index) {
    final state = cells[index];
    if (state == StoneState.empty) return {};
    final group = <int>{};
    final stack = [index];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      if (i < 0 || i >= cells.length || group.contains(i) || cells[i] != state) {
        continue;
      }
      group.add(i);
      final r = i ~/ size, c = i % size;
      for (final (dr, dc) in _dirs) {
        final nr = r + dr, nc = c + dc;
        if (_inBoard(size, nr, nc)) stack.add(nr * size + nc);
      }
    }
    return group;
  }

  /// 棋链总气数（共享气，去重）
  static int groupLiberties(List<StoneState> cells, int size, Set<int> group) {
    final libs = <int>{};
    for (final i in group) {
      final r = i ~/ size, c = i % size;
      for (final (dr, dc) in _dirs) {
        final nr = r + dr, nc = c + dc;
        final ni = nr * size + nc;
        if (_inBoard(size, nr, nc) && cells[ni] == StoneState.empty) {
          libs.add(ni);
        }
      }
    }
    return libs.length;
  }

  /// 落子后检查可提子的对方无气棋链
  static List<int> checkCapture(List<StoneState> cells, int size, int index) {
    final player = cells[index];
    final opp = opponent(player);
    final captured = <int>{};
    for (final (dr, dc) in _dirs) {
      final r = index ~/ size + dr, c = index % size + dc;
      if (!_inBoard(size, r, c)) continue;
      final ni = r * size + c;
      if (cells[ni] == opp) {
        final g = findGroup(cells, size, ni);
        if (groupLiberties(cells, size, g) == 0) captured.addAll(g);
      }
    }
    return captured.toList();
  }

  /// 尝试落子（含提子 + 自杀禁着检查）。修改 cells，返回是否成功与提子列表
  static ({bool ok, List<int> captured}) tryPlace(
    List<StoneState> cells,
    int size,
    int index,
    StoneState player,
  ) {
    if (index < 0 || index >= cells.length) return (ok: false, captured: []);
    if (cells[index] != StoneState.empty) return (ok: false, captured: []);

    cells[index] = player;
    final captured = checkCapture(cells, size, index);

    // 自杀禁着：未提子且己方棋链无气
    if (captured.isEmpty) {
      final myGroup = findGroup(cells, size, index);
      if (groupLiberties(cells, size, myGroup) == 0) {
        cells[index] = StoneState.empty; // 撤销
        return (ok: false, captured: []);
      }
    }

    for (final c in captured) {
      cells[c] = StoneState.empty;
    }
    return (ok: true, captured: captured);
  }

  /// 劫争判定：单子提单子且互为对方落子/提子位置
  static bool isKo(
    List<int> captured,
    int placeIndex,
    Map<String, dynamic>? lastCapture,
  ) {
    if (captured.length != 1 || lastCapture == null) return false;
    final lastCaptured = lastCapture['captured'] as List;
    if (lastCaptured.length != 1) return false;
    return captured[0] == lastCapture['index'] &&
        (lastCaptured[0] as int) == placeIndex;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 围棋棋盘 — Notifier 包装，规则逻辑委托 GoRules
// ═══════════════════════════════════════════════════════════════════════════════

class GoBoard {
  final int size;
  final ListNotifier<GoGridNotifier> grids = ListNotifier([]);
  List<Map<String, dynamic>> moveHistory = []; // 记录落子历史：位置、颜色、提子
  AlwaysNotifier<StoneState> currentPlayer = AlwaysNotifier(StoneState.black);
  bool gameOver = false;
  StoneState? lastWinner;
  Map<String, dynamic>? lastCapture; // 用于处理劫争

  GoBoard({required this.size}) {
    grids.value = List.generate(size * size, (index) {
      return GoGridNotifier(GoGrid(coordinate: index));
    });
    _initializeLiberties();
  }

  List<StoneState> _cellsSnapshot() =>
      [for (final g in grids.value) g.value.state];

  /// 导出棋盘快照（StoneState 序列），供 AI 只读使用
  List<StoneState> snapshot() => _cellsSnapshot();

  // 初始化气的计算
  void _initializeLiberties() {
    for (int i = 0; i < size * size; i++) {
      updateLiberties(i);
    }
  }

  // 更新指定位置的气（单格直接气）
  void updateLiberties(int index) {
    if (!grids.value[index].value.isEmpty()) {
      grids.value[index].updateLiberties(_calculateLiberties(index));
    }
  }

  // 计算单格气数（上下左右空位数）
  int _calculateLiberties(int index) {
    int row = index ~/ size;
    int col = index % size;
    int count = 0;
    for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      int newRow = row + dr;
      int newCol = col + dc;
      if (_checkInBoard(newRow, newCol)) {
        int newIndex = newRow * size + newCol;
        if (grids.value[newIndex].value.isEmpty()) {
          count++;
        }
      }
    }
    return count;
  }

  // 落子逻辑（委托 GoRules）
  bool placeStone(int index) {
    if (gameOver || !grids.value[index].value.isEmpty()) return false;

    final cells = _cellsSnapshot();
    final result = GoRules.tryPlace(cells, size, index, currentPlayer.value);
    if (!result.ok) return false;
    if (GoRules.isKo(result.captured, index, lastCapture)) return false;

    // 同步到 grids
    grids.value[index].placeStone(currentPlayer.value);
    for (var idx in result.captured) {
      grids.value[idx].clear();
      _updateSurroundingLiberties(idx);
    }
    updateLiberties(index);

    // 记录历史
    final state = {
      'index': index,
      'player': currentPlayer.value,
      'captured': result.captured,
    };
    moveHistory.add(state);
    lastCapture = result.captured.isNotEmpty ? state : null;

    // 切换玩家
    currentPlayer.value = GoRules.opponent(currentPlayer.value);
    return true;
  }

  // 更新周围棋子的气（含棋链）
  void _updateSurroundingLiberties(int index) {
    int row = index ~/ size;
    int col = index % size;

    for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      int newRow = row + dr;
      int newCol = col + dc;
      if (_checkInBoard(newRow, newCol)) {
        int newIndex = newRow * size + newCol;
        updateLiberties(newIndex);
        // 若周围有棋子，更新整个棋链的气
        if (!grids.value[newIndex].value.isEmpty()) {
          final group = GoRules.findGroup(_cellsSnapshot(), size, newIndex);
          for (var idx in group) {
            updateLiberties(idx);
          }
        }
      }
    }
  }

  // 认输
  void resign() {
    lastWinner = currentPlayer.value == StoneState.black
        ? StoneState.white
        : StoneState.black;
    gameOver = true;
  }

  // 悔棋
  void undoMove() {
    if (moveHistory.isEmpty) return;

    final lastMove = moveHistory.removeLast();
    int index = lastMove['index'] as int;
    List<int> captured =
        (lastMove['captured'] as List<dynamic>).cast<int>();

    // 恢复落子位置
    grids.value[index].clear();
    _updateSurroundingLiberties(index);

    // 恢复被提的棋子
    for (var idx in captured) {
      grids.value[idx].placeStone(
        lastMove['player'] == StoneState.black
            ? StoneState.white
            : StoneState.black,
      );
      _updateSurroundingLiberties(idx);
    }

    // 切换回上一个玩家
    currentPlayer.value = lastMove['player'] as StoneState;
    gameOver = false;
    lastCapture = moveHistory.isEmpty ? null : moveHistory.last;
  }

  // 重新开始
  void restart() {
    for (int i = 0; i < size * size; i++) {
      grids.value[i].clear();
    }
    moveHistory.clear();
    currentPlayer.value = StoneState.black;
    gameOver = false;
    lastCapture = null;
    _initializeLiberties();
  }

  bool _checkInBoard(int row, int col) {
    return row >= 0 && row < size && col >= 0 && col < size;
  }
}
