import 'package:treasure/00.common/network/client/game_session.dart';
import 'package:treasure/00.common/network/client/network_engine.dart';

/// 网络层测试先完成真实匹配协议，再把结果交给被测对局引擎。
T startGame<T extends GameSession>(T game) {
  if (game.ended.value) return game;
  final room = game.room;
  var released = false;

  late final void Function() onMatch;
  void onLost() {
    if (room.identity == 0 && !game.ended.value) game.finish(sendExit: false);
  }

  void release({bool cancel = true}) {
    if (released) return;
    released = true;
    room.matchPhase.removeListener(onMatch);
    room.identityNotifier.removeListener(onLost);
    if (cancel) room.cancelMatching();
  }

  game.ended.addListener(() {
    if (game.ended.value) release();
  });
  onMatch = () {
    if (room.matchPhase.value != RoomMatchPhase.matched ||
        game.ended.value) {
      return;
    }
    game.startFromRoom();
    room.openMatchedGame();
    release(cancel: false);
  };
  room.matchPhase.addListener(onMatch);
  room.identityNotifier.addListener(onLost);
  room.startMatching();
  return game;
}
