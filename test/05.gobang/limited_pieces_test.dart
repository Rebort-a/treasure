import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/05.gobang/base.dart';
import 'package:treasure/05.gobang/intelligence.dart';

void main() {
  // 分散落子，避免准备局面时意外形成五连。
  final black = [for (int i = 0; i < 12; i++) (i ~/ 4 * 2) * 15 + i % 4 * 2];
  final white = [for (final index in black) index + 120];

  Board prepare() {
    final board = Board(size: 15);
    for (int i = 0; i < 12; i++) {
      board.placePiece(black[i]);
      board.placePiece(white[i]);
    }
    expect(board.gameOver, isFalse);
    return board;
  }

  test('双方分别保留十二子，非法落子不触发移除', () {
    final board = prepare();
    final before = board.snapshot();
    board.placePiece(black.first);
    board.placePiece(-1);
    expect(board.snapshot(), before);
    board.placePiece(100);
    expect(board.grids.value[black.first].value.isEmpty(), isTrue);
    expect(board.pieceOrder(PieceType.black), [...black.skip(1), 100]);
    expect(board.pieceOrder(PieceType.white), white);
    board.placePiece(101);
    expect(board.grids.value[white.first].value.isEmpty(), isTrue);
    expect(board.pieceOrder(PieceType.white), [...white.skip(1), 101]);
  });

  test('空出的格子可重用，连续悔棋完整恢复历史和淘汰顺序', () {
    final board = prepare();
    final before = board.snapshot();
    board.placePiece(100);
    board.placePiece(black.first);
    board.placePiece(101);
    for (int i = 0; i < 3; i++) {
      board.undoMove();
    }
    expect(board.snapshot(), before);
    expect(board.pieceOrder(PieceType.black), black);
    expect(board.pieceOrder(PieceType.white), white);
    board.placePiece(102);
    expect(board.grids.value[black.first].value.isEmpty(), isTrue);
    board.restart();
    expect(board.pieceOrder(PieceType.black), isEmpty);
    expect(board.pieceOrder(PieceType.white), isEmpty);
    board.placePiece(black.first);
    expect(board.grids.value[black.first].value.type, PieceType.black);
  });

  test('移除旧子后才判断胜负，AI 模拟和异常回滚遵循相同规则', () {
    final order = [0, 1, 2, 3, 30, 32, 34, 36, 60, 62, 64, 66];
    final board = Board(size: 15);
    for (int i = 0; i < order.length; i++) {
      board.placePiece(order[i]);
      board.placePiece(white[i]);
    }
    final snapshot = board.snapshot();
    final search = SearchBoard(
      List.of(snapshot),
      15,
      pieceOrder: {1: order, 2: white},
    );
    expect(search.canWin(4, 1), isFalse);
    expect(search.cells, snapshot);
    expect(
      () => search.withMove<void>(4, 1, () {
        expect(search.cells[0], 0);
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect(search.cells, snapshot);
    expect(search.canWin(4, 1), isFalse);
    board.placePiece(4);
    expect(board.gameOver, isFalse);
    expect(board.snapshot(), [
      for (int i = 0; i < snapshot.length; i++)
        if (i == 0) 0 else if (i == 4) 1 else snapshot[i],
    ]);
  });
}
