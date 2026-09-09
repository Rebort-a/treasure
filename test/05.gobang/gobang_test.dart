import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/05.gobang/base.dart';

void main() {
  group('Gobang Board', () {
    late Board board;

    setUp(() {
      board = Board(size: 15);
    });

    // 辅助方法：row,col → index
    int idx(int row, int col) => row * 15 + col;

    group('落子', () {
      test('空位落子成功', () {
        board.placePiece(idx(7, 7));
        expect(board.grids.value[idx(7, 7)].value.type, PieceType.black);
      });

      test('已有棋子位置落子无效', () {
        board.placePiece(idx(7, 7));
        board.placePiece(idx(7, 7)); // 重复落子
        // 第二手应该是白棋，但因为位置已有棋子所以不生效
        expect(board.grids.value[idx(7, 7)].value.type, PieceType.black);
      });

      test('黑棋先手', () {
        expect(board.currentGamer.value, TurnGamerType.front);
      });

      test('落子后切换玩家', () {
        board.placePiece(idx(7, 7));
        expect(board.currentGamer.value, TurnGamerType.rear);
        board.placePiece(idx(0, 0));
        expect(board.currentGamer.value, TurnGamerType.front);
      });

      test('gameOver 后不能落子', () {
        // 先构造五连
        for (int i = 0; i < 5; i++) {
          board.placePiece(idx(7, i));     // 黑
          if (i < 4) board.placePiece(idx(8, i)); // 白
        }
        expect(board.gameOver, isTrue);

        final prevHistory = board.moveHistory.length;
        board.placePiece(idx(0, 0));
        expect(board.moveHistory.length, prevHistory);
      });
    });

    group('胜负判定', () {
      test('横向五连 → 黑胜', () {
        // 黑: (7,0) (7,1) (7,2) (7,3) (7,4)
        // 白: (8,0) (8,1) (8,2) (8,3)
        for (int i = 0; i < 5; i++) {
          board.placePiece(idx(7, i));     // 黑
          if (i < 4) board.placePiece(idx(8, i)); // 白
        }
        expect(board.gameOver, isTrue);
      });

      test('纵向五连 → 黑胜', () {
        for (int i = 0; i < 5; i++) {
          board.placePiece(idx(i, 7));     // 黑
          if (i < 4) board.placePiece(idx(i, 8)); // 白
        }
        expect(board.gameOver, isTrue);
      });

      test('右斜五连（↘）→ 黑胜', () {
        for (int i = 0; i < 5; i++) {
          board.placePiece(idx(i, i));         // 黑: (0,0)(1,1)(2,2)(3,3)(4,4)
          if (i < 4) board.placePiece(idx(i, i + 5)); // 白
        }
        expect(board.gameOver, isTrue);
      });

      test('左斜五连（↙）→ 黑胜', () {
        for (int i = 0; i < 5; i++) {
          board.placePiece(idx(i, 4 - i));     // 黑: (0,4)(1,3)(2,2)(3,1)(4,0)
          if (i < 4) board.placePiece(idx(i, 10 + i)); // 白
        }
        expect(board.gameOver, isTrue);
      });

      test('四子不触发胜利', () {
        for (int i = 0; i < 4; i++) {
          board.placePiece(idx(7, i));     // 黑
          if (i < 3) board.placePiece(idx(8, i)); // 白
        }
        // 第4手白还没下，此时白3手，checkWin还没检查
        board.placePiece(idx(8, 3)); // 白第4手
        expect(board.gameOver, isFalse);
      });

      test('超过五子也触发胜利（六连）', () {
        for (int i = 0; i < 6; i++) {
          board.placePiece(idx(7, i));     // 黑
          if (i < 5) board.placePiece(idx(8, i)); // 白
        }
        expect(board.gameOver, isTrue);
      });
    });

    group('悔棋', () {
      test('undoMove 恢复棋子', () {
        board.placePiece(idx(7, 7));
        expect(board.grids.value[idx(7, 7)].value.type, PieceType.black);

        board.undoMove();
        expect(board.grids.value[idx(7, 7)].value.type, PieceType.empty);
      });

      test('undoMove 恢复玩家', () {
        board.placePiece(idx(7, 7));
        expect(board.currentGamer.value, TurnGamerType.rear);

        board.undoMove();
        expect(board.currentGamer.value, TurnGamerType.front);
      });

      test('undoMove 可连续撤销多手', () {
        board.placePiece(idx(7, 7));
        board.placePiece(idx(8, 8));
        board.undoMove();
        board.undoMove();
        expect(board.grids.value[idx(7, 7)].value.type, PieceType.empty);
        expect(board.grids.value[idx(8, 8)].value.type, PieceType.empty);
        expect(board.currentGamer.value, TurnGamerType.front);
      });

      test('空历史时 undoMove 不崩溃', () {
        expect(() => board.undoMove(), returnsNormally);
      });
    });

    group('重新开始', () {
      test('restart 清空棋盘和状态', () {
        board.placePiece(idx(7, 7));
        board.placePiece(idx(8, 8));
        board.restart();

        for (int i = 0; i < 15 * 15; i++) {
          expect(board.grids.value[i].value.type, PieceType.empty);
        }
        expect(board.currentGamer.value, TurnGamerType.front);
        expect(board.gameOver, isFalse);
        expect(board.moveHistory, isEmpty);
      });
    });

    group('边界条件', () {
      test('角落落子', () {
        expect(() {
          board.placePiece(idx(0, 0));
          board.placePiece(idx(14, 14));
          board.placePiece(idx(0, 14));
          board.placePiece(idx(14, 0));
        }, returnsNormally);
      });

      test('五子在边缘', () {
        // 横向五子在第一行
        for (int i = 0; i < 5; i++) {
          board.placePiece(idx(0, i));     // 黑
          if (i < 4) board.placePiece(idx(1, i)); // 白
        }
        expect(board.gameOver, isTrue);
      });
    });
  });
}
