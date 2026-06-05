import 'base.dart';

abstract class GoFoundationalManager {
  final GoBoard board = GoBoard(size: 19);

  void placePiece(int index);

  void restart() {
    board.restart();
  }

  void undo() {
    board.undoMove();
  }

  void resign() {
    board.resign();
  }
}
