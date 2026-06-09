import 'dart:math';

import '../00.common/game/gamer.dart';
import 'base.dart';
import 'foundation_manager.dart';

class AiManager extends FoundationalManager {
  final TurnGamerType aiSide;
  bool _aiThinking = false;

  AiManager({this.aiSide = TurnGamerType.rear});

  @override
  void placePiece(int index) {
    if (board.gameOver || _aiThinking) return;
    if (board.currentGamer.value == aiSide) return;

    board.placePiece(index);
    if (!board.gameOver) {
      _triggerAiMove();
    }
  }

  void _triggerAiMove() {
    if (board.currentGamer.value != aiSide || board.gameOver) return;
    _aiThinking = true;

    // 延迟执行 AI，让 UI 有时间刷新
    Future.delayed(const Duration(milliseconds: 200), () {
      if (board.gameOver) {
        _aiThinking = false;
        return;
      }
      final move = _calculateBestMove();
      if (move != null) {
        board.placePiece(move);
      }
      _aiThinking = false;
    });
  }

  int? _calculateBestMove() {
    final size = board.size;
    final grids = board.grids.value;
    final aiPiece = aiSide == TurnGamerType.front
        ? PieceType.black
        : PieceType.white;
    final humanPiece = aiPiece == PieceType.black
        ? PieceType.white
        : PieceType.black;

    int? bestMove;
    int bestScore = -1;

    for (int i = 0; i < size * size; i++) {
      if (!grids[i].value.isEmpty()) continue;

      final score = _evaluatePosition(i, aiPiece, humanPiece, size);
      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }

    return bestMove;
  }

  int _evaluatePosition(
    int index,
    PieceType aiPiece,
    PieceType humanPiece,
    int size,
  ) {
    int score = 0;
    final row = index ~/ size;
    final col = index % size;

    // 四个方向：横、竖、右斜、左斜
    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

    for (final (dr, dc) in directions) {
      score += _evaluateDirection(
        row, col, dr, dc, aiPiece, humanPiece, size,
      );
    }

    // 中心位置加分
    final center = size ~/ 2;
    final distToCenter = (row - center).abs() + (col - center).abs();
    score += max(0, center - distToCenter);

    return score;
  }

  int _evaluateDirection(
    int row, int col, int dr, int dc,
    PieceType aiPiece, PieceType humanPiece, int size,
  ) {
    int aiCount = 0, humanCount = 0;
    int aiOpen = 0, humanOpen = 0;

    // 正方向
    int r = row + dr, c = col + dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = board.grids.value[r * size + c].value.type;
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

    // 检查正方向末端是否开放
    if (r >= 0 && r < size && c >= 0 && c < size) {
      final state = board.grids.value[r * size + c].value.type;
      if (state == PieceType.empty) {
        // 已经在上面的循环中计入 aiOpen/humanOpen
      }
    }

    // 反方向
    r = row - dr;
    c = col - dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = board.grids.value[r * size + c].value.type;
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

    // AI 进攻评分
    score += _scorePattern(aiCount, aiOpen, isAi: true);

    // 防守评分（阻断对手）
    score += _scorePattern(humanCount, humanOpen, isAi: false);

    return score;
  }

  int _scorePattern(int count, int openEnds, {required bool isAi}) {
    if (count == 0 && openEnds == 0) return 0;

    // 五连 → 必胜
    if (count >= 4) return isAi ? 100000 : 90000;

    // 活四（两端都开放的四）→ 几乎必胜
    if (count == 3 && openEnds >= 2) return isAi ? 50000 : 40000;

    // 冲四（一端开放的四）
    if (count == 3 && openEnds == 1) return isAi ? 5000 : 4000;

    // 活三
    if (count == 2 && openEnds >= 2) return isAi ? 3000 : 2500;

    // 眠三
    if (count == 2 && openEnds == 1) return isAi ? 500 : 400;

    // 活二
    if (count == 1 && openEnds >= 2) return isAi ? 200 : 150;

    // 眠二
    if (count == 1 && openEnds == 1) return isAi ? 50 : 30;

    // 活一
    if (openEnds >= 2) return isAi ? 10 : 5;

    return 0;
  }
}
