import '../00.common/sound/sound_manager.dart';
import 'base.dart';

abstract class GoFoundationalManager with SoundEmitter {
  final GoBoard board = GoBoard(size: 19);

  void placePiece(int index);

  void applyBoardMove(int index) {
    if (!board.placeStone(index)) return;
    final captured = board.moveHistory.last['captured'] as List;
    emitSound(captured.isEmpty ? Sound.move : Sound.capture);
  }

  void restart() {
    emitSound(Sound.reset);
    board.restart();
  }

  void undo() {
    board.undoMove();
  }

  void resign() {
    if (board.gameOver) return;
    board.resign();
    emitSound(Sound.lose);
  }
}
