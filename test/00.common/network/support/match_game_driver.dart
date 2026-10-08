import 'package:treasure/00.common/network/client/base/game_engine.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/net_real_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/game/step.dart';

NetTurnEngine configureTurnEngine({
  required SocketClient room,
  required TurnResourceMode resourceMode,
  void Function()? searchHandler,
  void Function(GameStep, NetworkMessage)? resourceHandler,
  required void Function(bool, NetworkMessage) actionHandler,
  required void Function() exitHandler,
}) => NetTurnEngine.forClient(room)
  ..configureGame(
    resourceMode: resourceMode,
    searchHandler: searchHandler,
    resourceHandler: resourceHandler,
    actionHandler: actionHandler,
    exitHandler: exitHandler,
  );

NetRealEngine configureRealEngine({
  required SocketClient room,
  int? maxPlayers,
  required void Function(int) searchHandler,
  required void Function(NetworkMessage) resourceHandler,
  required void Function(NetworkMessage) syncHandler,
  required void Function(NetworkMessage) actionHandler,
  required void Function(int) exitHandler,
}) => NetRealEngine.forClient(room)
  ..configureGame(
    maxPlayers: maxPlayers,
    searchHandler: searchHandler,
    resourceHandler: resourceHandler,
    syncHandler: syncHandler,
    actionHandler: actionHandler,
    exitHandler: exitHandler,
  );

/// 网络层测试先完成真实匹配协议，再把结果交给被测对局引擎。
T startGame<T extends GameEngine>(T game) {
  if (game.ended.value) return game;
  final room = game.client;
  final engine = game;
  var released = false;

  late final void Function() onMatch;
  void onLost() {
    if (room.identity == 0 && !game.ended.value) {
      game.finishGame(sendExit: false);
    }
  }

  void release({bool cancel = true}) {
    if (released) return;
    released = true;
    engine.matchPhase.removeListener(onMatch);
    room.identityNotifier.removeListener(onLost);
    if (cancel) engine.cancelMatching();
  }

  void onEnd() {
    if (game.ended.value) {
      game.ended.removeListener(onEnd);
      release();
    }
  }

  game.ended.addListener(onEnd);
  onMatch = () {
    if (engine.matchPhase.value != RoomMatchPhase.matched || game.ended.value) {
      return;
    }
    game.startFromRoom();
    engine.openMatchedGame();
    release(cancel: false);
  };
  engine.matchPhase.addListener(onMatch);
  room.identityNotifier.addListener(onLost);
  engine.startMatching();
  return game;
}
