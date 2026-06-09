import 'dart:math';

import 'base.dart';
import 'foundation_manager.dart';

class GoAiManager extends GoFoundationalManager {
  final StoneState aiSide;
  bool _aiThinking = false;

  GoAiManager({this.aiSide = StoneState.white});

  @override
  void placePiece(int index) {
    if (board.gameOver || _aiThinking) return;
    if (board.currentPlayer.value == aiSide) return;

    if (board.placeStone(index)) {
      if (!board.gameOver) {
        _triggerAiMove();
      }
    }
  }

  @override
  void restart() {
    super.restart();
    _aiThinking = false;
  }

  void _triggerAiMove() {
    if (board.currentPlayer.value != aiSide || board.gameOver) return;
    _aiThinking = true;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (board.gameOver) {
        _aiThinking = false;
        return;
      }
      final move = _calculateBestMove();
      if (move != null) {
        board.placeStone(move);
      }
      _aiThinking = false;
    });
  }

  int? _calculateBestMove() {
    final size = board.size;
    final grids = board.grids.value;
    final random = Random();

    int? bestMove;
    int bestScore = -999999;

    // 候选位置：已有棋子周围 2 格内的空位
    final candidates = <int>{};
    for (int i = 0; i < size * size; i++) {
      if (!grids[i].value.isEmpty()) {
        final row = i ~/ size;
        final col = i % size;
        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            final nr = row + dr;
            final nc = col + dc;
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final ni = nr * size + nc;
              if (grids[ni].value.isEmpty()) {
                candidates.add(ni);
              }
            }
          }
        }
      }
    }

    // 如果没有候选（空棋盘），下天元附近
    if (candidates.isEmpty) {
      final center = size ~/ 2;
      return center * size + center;
    }

    for (final i in candidates) {
      int score = _evaluatePosition(i, size);

      // 加一点随机性，避免完全确定性
      score += random.nextInt(5);

      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }

    return bestMove;
  }

  int _evaluatePosition(int index, int size) {
    int score = 0;
    final row = index ~/ size;
    final col = index % size;
    final grids = board.grids.value;
    final aiPiece = aiSide;
    final humanPiece =
        aiSide == StoneState.black ? StoneState.white : StoneState.black;

    // 中心偏好
    final center = size ~/ 2;
    final distToCenter = (row - center).abs() + (col - center).abs();
    score += max(0, (center - distToCenter)) * 2;

    // 四个方向评估
    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

    for (final (dr, dc) in directions) {
      score += _evaluateDirection(
        row, col, dr, dc, aiPiece, humanPiece, size, grids,
      );
    }

    return score;
  }

  int _evaluateDirection(
    int row, int col, int dr, int dc,
    StoneState aiPiece, StoneState humanPiece, int size,
    List<dynamic> grids,
  ) {
    int aiCount = 0, humanCount = 0;
    int aiOpen = 0, humanOpen = 0;

    // 正方向扫描
    int r = row + dr, c = col + dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = grids[r * size + c].value.state;
      if (state == aiPiece) {
        aiCount++;
      } else if (state == humanPiece) {
        humanCount++;
        break;
      } else {
        aiOpen++;
        break;
      }
      r += dr;
      c += dc;
    }

    // 反方向扫描
    r = row - dr;
    c = col - dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = grids[r * size + c].value.state;
      if (state == aiPiece) {
        aiCount++;
      } else if (state == humanPiece) {
        humanCount++;
        break;
      } else {
        aiOpen++;
        break;
      }
      r -= dr;
      c -= dc;
    }

    int score = 0;

    // 进攻评分
    score += _scorePattern(aiCount, aiOpen);

    // 防守评分（更重视防守）
    score += (_scorePattern(humanCount, humanOpen) * 1.2).toInt();

    return score;
  }

  int _scorePattern(int count, int openEnds) {
    if (count == 0) return 0;

    // 四子以上（几乎赢了）
    if (count >= 4 && openEnds > 0) return 100000;

    // 活三
    if (count == 3 && openEnds >= 2) return 10000;

    // 眠三
    if (count == 3 && openEnds == 1) return 1000;

    // 活二
    if (count == 2 && openEnds >= 2) return 500;

    // 眠二
    if (count == 2 && openEnds == 1) return 100;

    // 活一
    if (count == 1 && openEnds >= 2) return 50;

    // 眠一
    if (count == 1 && openEnds == 1) return 10;

    return 0;
  }
}
