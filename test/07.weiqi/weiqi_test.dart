import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/07.weiqi/base.dart';

void main() {
  group('GoBoard', () {
    late GoBoard board;

    setUp(() {
      board = GoBoard(size: 9); // 用 9x9 小棋盘测试
    });

    // 辅助方法：row,col → index
    int idx(int row, int col) => row * 9 + col;

    group('落子', () {
      test('空位落子成功', () {
        expect(board.placeStone(idx(4, 4)), isTrue);
        expect(board.grids.value[idx(4, 4)].value.state, StoneState.black);
      });

      test('已有棋子位置落子失败', () {
        board.placeStone(idx(4, 4));
        expect(board.placeStone(idx(4, 4)), isFalse);
      });

      test('gameOver 后不能落子', () {
        board.resign();
        expect(board.placeStone(idx(0, 0)), isFalse);
      });

      test('黑棋先手', () {
        expect(board.currentPlayer.value, StoneState.black);
      });

      test('落子后切换玩家', () {
        board.placeStone(idx(4, 4));
        expect(board.currentPlayer.value, StoneState.white);
        board.placeStone(idx(0, 0));
        expect(board.currentPlayer.value, StoneState.black);
      });
    });

    group('气的计算', () {
      test('中心单子有 4 口气', () {
        board.placeStone(idx(4, 4));
        expect(board.grids.value[idx(4, 4)].value.liberties, 4);
      });

      test('边上单子有 3 口气', () {
        board.placeStone(idx(0, 4));
        expect(board.grids.value[idx(0, 4)].value.liberties, 3);
      });

      test('角上单子有 2 口气', () {
        board.placeStone(idx(0, 0));
        expect(board.grids.value[idx(0, 0)].value.liberties, 2);
      });
    });

    group('提子', () {
      test('落子后提掉无气对方棋子', () {
        // 黑包围白，最后一手提子
        //   . B .
        //   B W B
        //   . B .
        board.placeStone(idx(3, 4)); // 黑
        board.placeStone(idx(4, 4)); // 白
        board.placeStone(idx(5, 4)); // 黑
        board.placeStone(idx(0, 0)); // 白（随便下）
        board.placeStone(idx(4, 3)); // 黑
        board.placeStone(idx(0, 1)); // 白
        board.placeStone(idx(4, 5)); // 黑 提掉白(4,4)

        expect(board.grids.value[idx(4, 4)].value.state, StoneState.empty);
      });

      test('多子棋链一次提完', () {
        // 白两子 (3,2) (3,3) 被黑完全包围
        //   . . . . . .
        //   . B B B B .
        //   . B W W B .
        //   . B B B B .
        board.placeStone(idx(2, 1)); // 黑
        board.placeStone(idx(3, 2)); // 白
        board.placeStone(idx(2, 2)); // 黑
        board.placeStone(idx(3, 3)); // 白
        board.placeStone(idx(2, 3)); // 黑
        board.placeStone(idx(0, 0)); // 白
        board.placeStone(idx(2, 4)); // 黑
        board.placeStone(idx(0, 1)); // 白
        board.placeStone(idx(4, 1)); // 黑
        board.placeStone(idx(0, 2)); // 白
        board.placeStone(idx(4, 2)); // 黑
        board.placeStone(idx(0, 3)); // 白
        board.placeStone(idx(4, 3)); // 黑
        board.placeStone(idx(0, 4)); // 白
        board.placeStone(idx(4, 4)); // 黑
        board.placeStone(idx(0, 5)); // 白
        board.placeStone(idx(3, 1)); // 黑
        board.placeStone(idx(1, 0)); // 白
        board.placeStone(idx(3, 4)); // 黑 提掉白(3,2)和(3,3)

        expect(board.grids.value[idx(3, 2)].value.state, StoneState.empty);
        expect(board.grids.value[idx(3, 3)].value.state, StoneState.empty);
      });
    });

    group('禁着点', () {
      test('自杀禁着（落子后自身无气且未提子）', () {
        // 黑包围一个空点，白不能下进去
        //   . B .
        //   B . B
        //   . B .
        board.placeStone(idx(3, 4)); // 黑
        board.placeStone(idx(0, 0)); // 白
        board.placeStone(idx(5, 4)); // 黑
        board.placeStone(idx(0, 1)); // 白
        board.placeStone(idx(4, 3)); // 黑
        board.placeStone(idx(0, 2)); // 白
        board.placeStone(idx(4, 5)); // 黑

        // 白下在 (4,4) 是自杀
        expect(board.placeStone(idx(4, 4)), isFalse);
      });
    });

    group('劫争', () {
      test('不能立即提回（劫争规则）', () {
        // 捕获前（Q=(2,2), P=(2,3)）：
        //   . B W . .
        //   B Q P W .
        //   . B W . .
        // 黑下 P 后仅提掉 Q，P 也仅剩 Q 一口气，形成标准单劫。
        expect(board.placeStone(idx(1, 2)), isTrue); // B
        expect(board.placeStone(idx(2, 2)), isTrue); // W: Q
        expect(board.placeStone(idx(3, 2)), isTrue); // B
        expect(board.placeStone(idx(1, 3)), isTrue); // W
        expect(board.placeStone(idx(2, 1)), isTrue); // B
        expect(board.placeStone(idx(3, 3)), isTrue); // W
        expect(board.placeStone(idx(8, 8)), isTrue); // B filler
        expect(board.placeStone(idx(2, 4)), isTrue); // W

        expect(board.placeStone(idx(2, 3)), isTrue); // B: P，提 Q
        expect(board.grids.value[idx(2, 2)].value.state, StoneState.empty);

        // 白若立即落回 Q 会只提掉 P，并恢复上一局面，应被劫争规则拒绝。
        expect(board.placeStone(idx(2, 2)), isFalse);
        expect(board.grids.value[idx(2, 2)].value.state, StoneState.empty);
        expect(board.grids.value[idx(2, 3)].value.state, StoneState.black);
      });
    });

    group('悔棋', () {
      test('undoMove 恢复落子位置', () {
        board.placeStone(idx(4, 4));
        expect(board.grids.value[idx(4, 4)].value.state, StoneState.black);

        board.undoMove();
        expect(board.grids.value[idx(4, 4)].value.state, StoneState.empty);
      });

      test('undoMove 恢复被提棋子', () {
        // 构造提子局面
        board.placeStone(idx(3, 4)); // 黑
        board.placeStone(idx(4, 4)); // 白
        board.placeStone(idx(5, 4)); // 黑
        board.placeStone(idx(0, 0)); // 白
        board.placeStone(idx(4, 3)); // 黑
        board.placeStone(idx(0, 1)); // 白
        board.placeStone(idx(4, 5)); // 黑 提掉白(4,4)

        expect(board.grids.value[idx(4, 4)].value.state, StoneState.empty);

        board.undoMove(); // 撤销提子
        expect(board.grids.value[idx(4, 4)].value.state, StoneState.white);
      });

      test('空历史时 undoMove 不崩溃', () {
        expect(() => board.undoMove(), returnsNormally);
      });
    });

    group('重新开始', () {
      test('restart 清空棋盘', () {
        board.placeStone(idx(4, 4));
        board.placeStone(idx(0, 0));
        board.restart();

        for (int i = 0; i < 81; i++) {
          expect(board.grids.value[i].value.state, StoneState.empty);
        }
        expect(board.currentPlayer.value, StoneState.black);
        expect(board.gameOver, isFalse);
        expect(board.moveHistory, isEmpty);
      });
    });

    group('边界条件', () {
      test('棋盘边缘落子', () {
        expect(board.placeStone(idx(0, 0)), isTrue);
        expect(board.placeStone(idx(8, 8)), isTrue);
        expect(board.placeStone(idx(0, 8)), isTrue);
        expect(board.placeStone(idx(8, 0)), isTrue);
      });
    });
  });
}
