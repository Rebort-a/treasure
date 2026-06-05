import 'foundation_manager.dart';

class LocalManager extends FoundationalManager {
  @override
  void placePiece(int index) {
    board.placePiece(index);
  }
}
