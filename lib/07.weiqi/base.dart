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

class GoBoard {
  final int size;
  final ListNotifier<GoGridNotifier> grids = ListNotifier([]);
  List<Map<String, dynamic>> moveHistory = []; // 记录落子历史：位置、颜色、提子
  AlwaysNotifier<StoneState> currentPlayer = AlwaysNotifier(StoneState.black);
  bool gameOver = false;
  Map<String, dynamic>? lastCapture; // 用于处理劫争

  GoBoard({required this.size}) {
    grids.value = List.generate(size * size, (index) {
      return GoGridNotifier(GoGrid(coordinate: index));
    });
    _initializeLiberties();
  }

  // 初始化气的计算
  void _initializeLiberties() {
    for (int i = 0; i < size * size; i++) {
      updateLiberties(i);
    }
  }

  // 更新指定位置的气
  void updateLiberties(int index) {
    if (!grids.value[index].value.isEmpty()) {
      grids.value[index].updateLiberties(_calculateLiberties(index));
    }
  }

  // 计算气的数量
  int _calculateLiberties(int index) {
    int row = index ~/ size;
    int col = index % size;
    int count = 0;

    // 检查上下左右四个方向
    for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
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

  // 落子逻辑
  bool placeStone(int index) {
    if (gameOver || !grids.value[index].value.isEmpty()) return false;

    // 保存当前状态用于悔棋
    final currentState = {
      'index': index,
      'player': currentPlayer.value,
      'captured': [],
    };

    // 尝试落子
    grids.value[index].placeStone(currentPlayer.value);
    updateLiberties(index);

    // 检查提子
    List<int> captured = _checkCapture(index);
    if (captured.isNotEmpty) {
      currentState['captured'] = captured;
      for (var idx in captured) {
        grids.value[idx].clear();
        _updateSurroundingLiberties(idx);
      }
    }

    // 检查禁着点（落子后无气且未提子）
    if (grids.value[index].value.liberties == 0 && captured.isEmpty) {
      // 撤销落子
      grids.value[index].clear();
      return false;
    }

    // 检查劫争（不能立即提回）
    if (_isKo(captured)) {
      grids.value[index].clear();
      return false;
    }

    // 记录历史
    moveHistory.add(currentState);
    lastCapture = captured.isNotEmpty ? currentState : null;

    // 切换玩家
    currentPlayer.value = currentPlayer.value == StoneState.black
        ? StoneState.white
        : StoneState.black;

    return true;
  }

  // 检查是否提子
  List<int> _checkCapture(int index) {
    int row = index ~/ size;
    int col = index % size;
    StoneState current = grids.value[index].value.state;
    StoneState opponent = current == StoneState.black
        ? StoneState.white
        : StoneState.black;
    List<int> captured = [];

    // 检查四个方向的对方棋子
    for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      int newRow = row + dr;
      int newCol = col + dc;
      if (_checkInBoard(newRow, newCol)) {
        int newIndex = newRow * size + newCol;
        if (grids.value[newIndex].value.state == opponent) {
          // 检查对方棋链是否无气
          Set<int> group = _findGroup(newIndex);
          if (_groupHasNoLiberties(group)) {
            captured.addAll(group);
          }
        }
      }
    }

    return captured;
  }

  // 查找一整个棋链
  Set<int> _findGroup(int index) {
    Set<int> group = {};
    _findGroupRecursive(index, grids.value[index].value.state, group);
    return group;
  }

  void _findGroupRecursive(int index, StoneState state, Set<int> group) {
    if (!_checkInBoardIndex(index) ||
        group.contains(index) ||
        grids.value[index].value.state != state) {
      return;
    }

    group.add(index);
    int row = index ~/ size;
    int col = index % size;

    // 递归检查四个方向
    for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      int newIndex = (row + dr) * size + (col + dc);
      _findGroupRecursive(newIndex, state, group);
    }
  }

  // 检查棋链是否无气
  bool _groupHasNoLiberties(Set<int> group) {
    for (var index in group) {
      if (_calculateLiberties(index) > 0) {
        return false;
      }
    }
    return true;
  }

  // 更新周围棋子的气
  void _updateSurroundingLiberties(int index) {
    int row = index ~/ size;
    int col = index % size;

    for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      int newRow = row + dr;
      int newCol = col + dc;
      if (_checkInBoard(newRow, newCol)) {
        int newIndex = newRow * size + newCol;
        updateLiberties(newIndex);
        // 如果周围有棋子，需要更新整个棋链的气
        if (!grids.value[newIndex].value.isEmpty()) {
          Set<int> group = _findGroup(newIndex);
          for (var idx in group) {
            updateLiberties(idx);
          }
        }
      }
    }
  }

  // 检查劫争
  bool _isKo(List<int> captured) {
    // 劫争：只提一个子，且上一手也是提一个子
    if (captured.length == 1 &&
        lastCapture != null &&
        (lastCapture!['captured'] as List).length == 1) {
      int currentCaptured = captured[0];
      int lastCaptured = (lastCapture!['captured'] as List)[0];
      // 检查是否是同一位置的反复提子
      return currentCaptured == lastCapture!['index'] &&
          lastCaptured == moveHistory.last['index'];
    }
    return false;
  }

  // 认输
  void resign() {
    gameOver = true;
    currentPlayer.value = currentPlayer.value == StoneState.black
        ? StoneState.black
        : StoneState.white;
  }

  // 悔棋
  void undoMove() {
    if (moveHistory.isEmpty) return;

    final lastMove = moveHistory.removeLast();
    int index = lastMove['index'] as int;
    // 显式将dynamic列表转换为int列表
    List<int> captured = (lastMove['captured'] as List<dynamic>).cast<int>();

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

  bool _checkInBoardIndex(int index) {
    return index >= 0 && index < size * size;
  }
}
