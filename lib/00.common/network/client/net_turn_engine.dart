import 'package:flutter/foundation.dart';

import '../../game/step.dart';
import 'turn_game_session.dart';
import '../protocol/network_message.dart';
import 'network_engine.dart';

/// 房间唯一的回合网络引擎；每局对战只创建一个不持有连接的会话。
class NetTurnEngine extends NetworkEngine {
  TurnGameSession? _session;

  NetTurnEngine({
    required super.userName,
    required super.endpoint,
    super.transport,
  });

  TurnGameSession createSession({
    required TurnResourceMode resourceMode,
    void Function()? searchHandler,
    void Function(GameStep, NetworkMessage)? resourceHandler,
    required void Function(bool, NetworkMessage) actionHandler,
    required VoidCallback exitHandler,
  }) {
    if (_session case final game? when !game.ended.value) {
      throw StateError('Turn game is already active in this room');
    }
    final game = TurnGameSession(
      room: this,
      resourceMode: resourceMode,
      searchHandler: searchHandler ?? () {},
      resourceHandler: resourceHandler ?? (_, __) {},
      actionHandler: actionHandler,
      exitHandler: exitHandler,
    );
    _session = game;
    game.ended.addListener(() {
      if (game.ended.value && identical(_session, game)) _session = null;
    });
    return game;
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }
}

/// 自动发现的回合房间使用专属引擎；手动地址使用认证后的原连接。
TurnGameSession createTurnSession({
  required NetworkEngine room,
  required TurnResourceMode resourceMode,
  void Function()? searchHandler,
  void Function(GameStep, NetworkMessage)? resourceHandler,
  required void Function(bool, NetworkMessage) actionHandler,
  required VoidCallback exitHandler,
}) {
  final onSearch = searchHandler ?? () {};
  final onResource = resourceHandler ?? (_, __) {};
  if (room is NetTurnEngine) {
    return room.createSession(
      resourceMode: resourceMode,
      searchHandler: onSearch,
      resourceHandler: onResource,
      actionHandler: actionHandler,
      exitHandler: exitHandler,
    );
  }
  return room.createTurnGameForUnknownRoom(
    resourceMode: resourceMode,
    searchHandler: onSearch,
    resourceHandler: onResource,
    actionHandler: actionHandler,
    exitHandler: exitHandler,
  );
}
