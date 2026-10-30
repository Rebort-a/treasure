import '../00.common/sound/sound_manager.dart';
import 'base.dart';

abstract class FoundationalManager with SoundEmitter {
  final Board board = Board(size: 15);

  bool _disposed = false;
  bool get disposed => _disposed;

  void dispose() {
    if (disposed) return;
    _disposed = true;
    disposeAudioEvents();
    board.dispose();
  }

  void placePiece(int index);

  /// 只对实际新增的落子发声，非法动作和重复消息不会触发。
  void applyBoardMove(int index) {
    final before = board.moveHistory.length;
    board.placePiece(index);
    if (board.moveHistory.length == before) return;
    emitSound(board.gameOver ? resultSound : Sound.move);
  }

  Sound get resultSound => Sound.win;

  void restart() {
    emitSound(Sound.reset);
    board.restart();
  }

  void undo() {
    board.undoMove();
  }
}
