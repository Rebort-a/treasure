import '../00.common/game/game_sound.dart';
import 'base.dart';

abstract class GoFoundationalManager with GameSoundEmitter {
  final GoBoard board = GoBoard(size: 19);

  void placePiece(int index);

  void applyBoardMove(int index) {
    if (!board.placeStone(index)) return;
    final captured = board.moveHistory.last['captured'] as List;
    emitSound(captured.isEmpty ? GameSound.move : GameSound.capture);
  }

  void restart() {
    emitSound(GameSound.reset);
    board.restart();
  }

  void undo() {
    board.undoMove();
  }

  void resign() {
    if (board.gameOver) return;
    board.resign();
    emitSound(GameSound.lose);
  }
}
