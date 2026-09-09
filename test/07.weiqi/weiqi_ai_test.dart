import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/07.weiqi/base.dart';
import 'package:treasure/07.weiqi/intelligence.dart';

/// 围棋 AI 引擎测试：GoRules 纯逻辑 / GoSearchBoard do/undo / 候选生成 / 评估 / 搜索
void main() {
  const size = 9;
  int idx(int r, int c) => r * size + c;
  List<StoneState> emptyBoard() =>
      List<StoneState>.filled(size * size, StoneState.empty);

  group('GoRules 纯逻辑', () {
    test('calculateLiberties 中心单子 4 气', () {
      final cells = emptyBoard();
      cells[idx(4, 4)] = StoneState.black;
      expect(GoRules.calculateLiberties(cells, size, idx(4, 4)), 4);
    });

    test('calculateLiberties 角上单子 2 气', () {
      final cells = emptyBoard();
      cells[idx(0, 0)] = StoneState.black;
      expect(GoRules.calculateLiberties(cells, size, idx(0, 0)), 2);
    });

    test('findGroup 多子棋链', () {
      final cells = emptyBoard();
      cells[idx(4, 4)] = StoneState.black;
      cells[idx(4, 5)] = StoneState.black;
      cells[idx(4, 6)] = StoneState.black;
      final g = GoRules.findGroup(cells, size, idx(4, 4));
      expect(g.length, 3);
      expect(g, containsAll([idx(4, 4), idx(4, 5), idx(4, 6)]));
    });

    test('groupLiberties 棋链共享气', () {
      // 两子横连 (4,4)(4,5)，气 = 周围空位去重
      final cells = emptyBoard();
      cells[idx(4, 4)] = StoneState.black;
      cells[idx(4, 5)] = StoneState.black;
      final g = GoRules.findGroup(cells, size, idx(4, 4));
      // (4,4): 上(3,4)下(5,4)左(4,3) ; (4,5): 上(3,5)下(5,5)右(4,6) → 6 气（去重）
      expect(GoRules.groupLiberties(cells, size, g), 6);
    });

    test('tryPlace 落子提子', () {
      // 白(4,4) 三面被黑围，右(4,5)空 → 气=1；黑落(4,5)提白
      final cells = emptyBoard();
      cells[idx(3, 4)] = StoneState.black;
      cells[idx(4, 4)] = StoneState.white;
      cells[idx(5, 4)] = StoneState.black;
      cells[idx(4, 3)] = StoneState.black;
      final result = GoRules.tryPlace(cells, size, idx(4, 5), StoneState.black);
      expect(result.ok, isTrue);
      expect(result.captured, contains(idx(4, 4)));
      expect(cells[idx(4, 4)], StoneState.empty); // 被提
    });

    test('tryPlace 自杀禁着返回 false', () {
      // (4,4) 四邻全黑，白下进去自杀
      final cells = emptyBoard();
      cells[idx(3, 4)] = StoneState.black;
      cells[idx(5, 4)] = StoneState.black;
      cells[idx(4, 3)] = StoneState.black;
      cells[idx(4, 5)] = StoneState.black;
      final result = GoRules.tryPlace(cells, size, idx(4, 4), StoneState.white);
      expect(result.ok, isFalse);
      expect(cells[idx(4, 4)], StoneState.empty); // 未落子
    });

    test('tryPlace 已有棋子位置失败', () {
      final cells = emptyBoard();
      cells[idx(4, 4)] = StoneState.black;
      expect(GoRules.tryPlace(cells, size, idx(4, 4), StoneState.white).ok,
          isFalse);
    });
  });

  group('GoSearchBoard do/undo', () {
    test('withMove 落子后 undo 恢复', () {
      final cells = emptyBoard();
      final board = GoSearchBoard(cells, size);
      board.withMove(idx(4, 4), StoneState.black, () {
        expect(board.cells[idx(4, 4)], StoneState.black);
      });
      expect(board.cells[idx(4, 4)], StoneState.empty);
    });

    test('withMove 提子后 undo 恢复提子', () {
      final cells = emptyBoard();
      cells[idx(3, 4)] = StoneState.black;
      cells[idx(4, 4)] = StoneState.white;
      cells[idx(5, 4)] = StoneState.black;
      cells[idx(4, 3)] = StoneState.black;
      final board = GoSearchBoard(cells, size);
      board.withMove(idx(4, 5), StoneState.black, () {
        expect(board.cells[idx(4, 4)], StoneState.empty); // 白被提
        expect(board.cells[idx(4, 5)], StoneState.black);
      });
      // undo：黑(4,5)撤回，白(4,4)恢复
      expect(board.cells[idx(4, 5)], StoneState.empty);
      expect(board.cells[idx(4, 4)], StoneState.white);
    });
  });

  group('GoSearchBoard.generateCandidates', () {
    test('候选仅在已有棋子周围 radius 内', () {
      final cells = emptyBoard();
      cells[idx(4, 4)] = StoneState.black;
      final cands = GoSearchBoard(cells, size).generateCandidates(
        StoneState.white,
        StoneState.white,
        radius: 2,
      );
      expect(cands, contains(idx(3, 3)));
      expect(cands, contains(idx(6, 6)));
      expect(cands, isNot(contains(idx(0, 0))));
    });

    test('自杀点不入选候选', () {
      // (4,4) 四邻全黑，白下自杀 → 不应出现在候选
      final cells = emptyBoard();
      cells[idx(3, 4)] = StoneState.black;
      cells[idx(5, 4)] = StoneState.black;
      cells[idx(4, 3)] = StoneState.black;
      cells[idx(4, 5)] = StoneState.black;
      final cands = GoSearchBoard(cells, size).generateCandidates(
        StoneState.white,
        StoneState.white,
        radius: 2,
      );
      expect(cands, isNot(contains(idx(4, 4))));
    });

    test('topK 限制数量', () {
      final cells = emptyBoard();
      for (int i = 0; i < size; i++) {
        cells[idx(i, 0)] = (i % 2 == 0) ? StoneState.black : StoneState.white;
      }
      final cands = GoSearchBoard(cells, size).generateCandidates(
        StoneState.black,
        StoneState.black,
        radius: 2,
        topK: 5,
      );
      expect(cands.length, lessThanOrEqualTo(5));
    });
  });

  group('GoEvaluator', () {
    test('提子差：己方棋子多则 evaluate 更高', () {
      final empty = emptyBoard();
      final e1 = GoEvaluator.evaluate(GoSearchBoard(empty, size), StoneState.black);
      final cells = emptyBoard();
      cells[idx(4, 4)] = StoneState.black;
      final e2 = GoEvaluator.evaluate(GoSearchBoard(cells, size), StoneState.black);
      expect(e2, greaterThan(e1));
    });

    test('scorePoint 提子点高分', () {
      // 白(4,4) 被 黑三面围，黑落(4,5) 提子
      final cells = emptyBoard();
      cells[idx(3, 4)] = StoneState.black;
      cells[idx(4, 4)] = StoneState.white;
      cells[idx(5, 4)] = StoneState.black;
      cells[idx(4, 3)] = StoneState.black;
      final board = GoSearchBoard(cells, size);
      final score = GoEvaluator.scorePoint(board, idx(4, 5), StoneState.black);
      expect(score, greaterThan(GoEvalParams.captureWeight));
    });
  });

  group('GoSearchEngine / GoAiController', () {
    test('正常开局返回合法空位', () {
      final cells = emptyBoard();
      cells[idx(4, 4)] = StoneState.black;
      cells[idx(4, 5)] = StoneState.white;
      final move = GoSearchEngine.search(
        GoSearchBoard(cells, size),
        StoneState.black,
        GoAiDifficulty.easy,
        600,
      );
      expect(move, isNotNull);
      expect(cells[move!], StoneState.empty);
    });

    test('空盘 AI 返回天元（不卡回合）', () {
      final cells = emptyBoard();
      final move = GoSearchEngine.search(
        GoSearchBoard(cells, size),
        StoneState.black,
        GoAiDifficulty.normal,
        1500,
      );
      expect(move, (size ~/ 2) * size + size ~/ 2); // 天元 (4,4)
    });

    test('对方被打吃 → AI 应提子', () {
      // 白(4,4) 气=1（被打吃），黑可落(4,5)提子
      final cells = emptyBoard();
      cells[idx(3, 4)] = StoneState.black;
      cells[idx(4, 4)] = StoneState.white;
      cells[idx(5, 4)] = StoneState.black;
      cells[idx(4, 3)] = StoneState.black;
      final board = GoSearchBoard(cells, size);
      final move = GoSearchEngine.search(
        board,
        StoneState.black,
        GoAiDifficulty.normal,
        1500,
      );
      expect(move, isNotNull);
      // 验证：AI 选的着法能提掉白(4,4)
      final verify = GoRules.tryPlace(
        List<StoneState>.of(cells),
        size,
        move!,
        StoneState.black,
      );
      expect(verify.captured, contains(idx(4, 4)));
    });

    test('GoAiController getAction 返回合法着法', () async {
      final raw = emptyBoard();
      raw[idx(4, 4)] = StoneState.black;
      raw[idx(4, 5)] = StoneState.white;
      final ai = GoAiController(
        size: size,
        faction: StoneState.black,
        difficulty: GoAiDifficulty.easy,
      );
      final move = await ai.getAction(raw);
      expect(move, isNotNull);
      expect(raw[move!], StoneState.empty); // 合法空位
      ai.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
