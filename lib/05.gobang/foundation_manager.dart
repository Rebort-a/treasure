import '../00.common/game/game_sound.dart';
import 'base.dart';

abstract class FoundationalManager with GameSoundEmitter {
  final Board board = Board(size: 15);

  void placePiece(int index);

  /// 只对实际新增的落子发声，非法动作和重复消息不会触发。
  void applyBoardMove(int index) {
    final before = board.moveHistory.length;
    board.placePiece(index);
    if (board.moveHistory.length == before) return;
    emitSound(board.gameOver ? resultSound : GameSound.move);
  }

  GameSound get resultSound => GameSound.win;

  void restart() {
    emitSound(GameSound.reset);
    board.restart();
  }

  void undo() {
    board.undoMove();
  }
}
