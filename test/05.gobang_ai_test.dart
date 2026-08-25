import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/05.gobang/intelligence.dart';

/// 五子棋 AI 引擎测试：棋型识别 / 连五检测 / 候选生成 / 必胜必堵短路
/// 编码：0=空 1=己(self) 2=敌(enemy)
void main() {
  const size = 15;
  int idx(int r, int c) => r * size + c;

  SearchBoard boardFrom(List<int> cells) =>
      SearchBoard(List<int>.of(cells), size);
  List<int> emptyBoard() => List<int>.filled(size * size, 0);

  group('SearchBoard.checkWin', () {
    test('横向连五', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 5; c++) {
        cells[idx(7, c)] = 1;
      }
      expect(boardFrom(cells).checkWin(idx(7, 5), 1), isTrue);
    });

    test('纵向连五', () {
      final cells = emptyBoard();
      for (int r = 1; r <= 5; r++) {
        cells[idx(r, 7)] = 1;
      }
      expect(boardFrom(cells).checkWin(idx(5, 7), 1), isTrue);
    });

    test('右斜连五', () {
      final cells = emptyBoard();
      for (int i = 1; i <= 5; i++) {
        cells[idx(i, i)] = 1;
      }
      expect(boardFrom(cells).checkWin(idx(5, 5), 1), isTrue);
    });

    test('左斜连五', () {
      final cells = emptyBoard();
      for (int i = 0; i < 5; i++) {
        cells[idx(i, 8 - i)] = 1;
      }
      expect(boardFrom(cells).checkWin(idx(4, 4), 1), isTrue);
    });

    test('四连不触发连五', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 4; c++) {
        cells[idx(7, c)] = 1;
      }
      expect(boardFrom(cells).checkWin(idx(7, 4), 1), isFalse);
    });
  });

  group('SearchBoard.canWin', () {
    test('落子即成五返回 true', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 4; c++) {
        cells[idx(7, c)] = 1;
      }
      final board = boardFrom(cells);
      expect(board.canWin(idx(7, 0), 1), isTrue); // 左延伸成五
      expect(board.canWin(idx(7, 5), 1), isTrue); // 右延伸成五
    });

    test('无关空位返回 false', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 4; c++) {
        cells[idx(7, c)] = 1;
      }
      expect(boardFrom(cells).canWin(idx(0, 0), 1), isFalse);
    });

    test('不修改棋盘状态', () {
      final cells = emptyBoard();
      cells[idx(7, 7)] = 1;
      final board = boardFrom(cells);
      board.canWin(idx(7, 8), 1);
      expect(board.cells[idx(7, 8)], 0); // 仍为空
    });
  });

  group('棋型识别 (Evaluator)', () {
    test('活四: 落子形成 011110 ≥ liveFour', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 3; c++) {
        cells[idx(7, c)] = 1;
      } // col1-3 self
      // 落 col4 → 0 1 1 1 1 0 活四
      final score = Evaluator.scorePoint(boardFrom(cells), idx(7, 4), 1);
      expect(score, greaterThanOrEqualTo(EvalParams.liveFour));
    });

    test('冲四: 落子形成 011112 ≥ rushFour 且 < liveFour', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 3; c++) {
        cells[idx(7, c)] = 1;
      }
      cells[idx(7, 5)] = 2; // 右端阻挡
      // 落 col4 → 0 1 1 1 1 2 冲四
      final score = Evaluator.scorePoint(boardFrom(cells), idx(7, 4), 1);
      expect(score, greaterThanOrEqualTo(EvalParams.rushFour));
      expect(score, lessThan(EvalParams.liveFour));
    });

    test('跳冲四: 11011 识别为冲四', () {
      final cells = emptyBoard();
      cells[idx(7, 1)] = 1;
      cells[idx(7, 2)] = 1;
      cells[idx(7, 4)] = 1;
      cells[idx(7, 5)] = 1; // 1 1 0 1 1
      // 落 col3 → 1 1 1 1 1 连五（实际是必胜，scorePoint 应含 winScore）
      final score = Evaluator.scorePoint(boardFrom(cells), idx(7, 3), 1);
      expect(score, greaterThanOrEqualTo(EvalParams.winScore));
    });

    test('活三: 落子形成 01110 ≥ liveThree', () {
      final cells = emptyBoard();
      cells[idx(7, 1)] = 1;
      cells[idx(7, 2)] = 1;
      // 落 col3 → 0 1 1 1 0 活三
      final score = Evaluator.scorePoint(boardFrom(cells), idx(7, 3), 1);
      expect(score, greaterThanOrEqualTo(EvalParams.liveThree));
      expect(score, lessThan(EvalParams.liveFour));
    });

    test('跳活三: 010110 识别为活三（非活二）', () {
      final cells = emptyBoard();
      cells[idx(7, 1)] = 1;
      cells[idx(7, 3)] = 1;
      cells[idx(7, 4)] = 1; // 0 1 0 1 1 0
      final score = Evaluator.evaluate(boardFrom(cells), 1);
      expect(score, greaterThanOrEqualTo(EvalParams.liveThree));
      expect(score, lessThan(EvalParams.liveFour));
    });

    test('眠三: 211100 识别为眠三', () {
      final cells = emptyBoard();
      cells[idx(7, 0)] = 2; // 左阻挡
      cells[idx(7, 1)] = 1;
      cells[idx(7, 2)] = 1;
      cells[idx(7, 3)] = 1; // 2 1 1 1 0 0
      final score = Evaluator.evaluate(boardFrom(cells), 1);
      expect(score, greaterThanOrEqualTo(EvalParams.sleepThree));
      expect(score, lessThan(EvalParams.liveThree));
    });

    test('活二: 001100 识别为活二', () {
      final cells = emptyBoard();
      cells[idx(7, 2)] = 1;
      cells[idx(7, 3)] = 1; // 0 0 1 1 0 0
      final score = Evaluator.evaluate(boardFrom(cells), 1);
      expect(score, greaterThanOrEqualTo(EvalParams.liveTwo));
      expect(score, lessThan(EvalParams.liveThree));
    });
  });

  group('候选生成 generateCandidates', () {
    test('空盘无候选', () {
      expect(boardFrom(emptyBoard()).generateCandidates(1), isEmpty);
    });

    test('候选仅在已有棋子周围 radius 内', () {
      final cells = emptyBoard();
      cells[idx(7, 7)] = 1;
      final cands = boardFrom(cells).generateCandidates(1, radius: 2);
      expect(cands, contains(idx(6, 6)));
      expect(cands, contains(idx(8, 8)));
      expect(cands, contains(idx(5, 5)));
      expect(cands, contains(idx(9, 9)));
      // 远离棋子的点不应入选
      expect(cands, isNot(contains(idx(0, 0))));
      expect(cands, isNot(contains(idx(14, 14))));
    });

    test('radius=1 只取紧邻 8 格', () {
      final cells = emptyBoard();
      cells[idx(7, 7)] = 1;
      final cands = boardFrom(cells).generateCandidates(1, radius: 1);
      expect(cands.length, 8);
      for (final c in cands) {
        final r = c ~/ size, col = c % size;
        final dr = (r - 7).abs(), dc = (col - 7).abs();
        // 切比雪夫距离 = 1（4 正交 + 4 对角 = 8 邻居）
        expect(dr <= 1 && dc <= 1 && (dr + dc) > 0, isTrue);
      }
    });

    test('topK 限制候选数量', () {
      final cells = emptyBoard();
      for (int i = 0; i < size; i++) {
        cells[idx(i, 0)] = (i % 2 == 0) ? 1 : 2;
      }
      final cands =
          boardFrom(cells).generateCandidates(1, radius: 2, topK: 5);
      expect(cands.length, lessThanOrEqualTo(5));
    });

    test('去重：同一空位不重复', () {
      final cells = emptyBoard();
      cells[idx(7, 7)] = 1;
      cells[idx(7, 8)] = 2; // (7,8) 周围与 (7,7) 重叠
      final cands = boardFrom(cells).generateCandidates(1, radius: 2);
      expect(cands.toSet().length, cands.length);
    });
  });

  group('SearchEngine 必胜必堵短路', () {
    test('AI 一步成五 → 必胜短路返回该点', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 4; c++) {
        cells[idx(7, c)] = 1;
      } // self 四连
      final move =
          SearchEngine.search(boardFrom(cells), 1, AiDifficulty.normal, 1500);
      expect(move, isNotNull);
      expect(boardFrom(cells).canWin(move!, 1), isTrue);
    });

    test('对方一步成五 → AI 必堵该点', () {
      final cells = emptyBoard();
      for (int c = 1; c <= 4; c++) {
        cells[idx(7, c)] = 2;
      } // enemy 四连（两端开放）
      final move =
          SearchEngine.search(boardFrom(cells), 1, AiDifficulty.normal, 1500);
      expect(move, isNotNull);
      expect([idx(7, 0), idx(7, 5)], contains(move));
    });

    test('对方冲四（一端封）→ AI 堵开放端', () {
      final cells = emptyBoard();
      cells[idx(7, 0)] = 1; // 左端已被 self 封
      for (int c = 1; c <= 4; c++) {
        cells[idx(7, c)] = 2;
      } // enemy 四连右端开放
      final move =
          SearchEngine.search(boardFrom(cells), 1, AiDifficulty.normal, 1500);
      // enemy 只能在 col5 成五，AI 必须堵 col5
      expect(move, idx(7, 5));
    });

    test('正常开局返回合法空位', () {
      final cells = emptyBoard();
      cells[idx(7, 7)] = 1;
      cells[idx(7, 8)] = 2;
      final move =
          SearchEngine.search(boardFrom(cells), 1, AiDifficulty.easy, 600);
      expect(move, isNotNull);
      expect(cells[move!], 0); // 必须是空位
    });

    test('空盘 AI 返回天元（不卡回合）', () {
      final board = SearchBoard(List<int>.filled(15 * 15, 0), 15);
      final move =
          SearchEngine.search(board, 1, AiDifficulty.normal, 1500);
      expect(move, (15 ~/ 2) * 15 + 15 ~/ 2); // 天元 (7,7)
    });
  });

  group('AiController', () {
    test('thinking 初始为 false', () {
      final ai = AiController(
        size: size,
        faction: TurnGamerType.front,
        difficulty: AiDifficulty.easy,
      );
      expect(ai.thinking.value, isFalse);
      ai.dispose();
    });

    test('视角转换 + 必胜：执黑 AI 在黑四连局面落子成五', () async {
      // 原始快照：0空 1黑 2白；AI 执黑(front)
      final raw = emptyBoard();
      for (int c = 1; c <= 4; c++) {
        raw[idx(7, c)] = 1;
      } // 黑四连
      final ai = AiController(
        size: size,
        faction: TurnGamerType.front,
        difficulty: AiDifficulty.normal,
      );
      final move = await ai.getAction(raw);
      expect(move, isNotNull);
      // front 执黑：raw 中 1=黑=self，可直接当 self 视角校验
      final verify = SearchBoard(List<int>.of(raw), size);
      expect(verify.canWin(move!, 1), isTrue);
      ai.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
