import 'real_game_session.dart';
import '../protocol/network_message.dart';
import 'network_engine.dart';

/// 房间唯一的实时网络引擎；参与者与发布者由当前对局会话维护。
class NetRealEngine extends NetworkEngine {
  RealGameSession? _session;

  NetRealEngine({
    required super.userName,
    required super.endpoint,
    super.transport,
  });

  RealGameSession createSession({
    int? maxPlayers,
    required void Function(int) searchHandler,
    required void Function(NetworkMessage) resourceHandler,
    required void Function(NetworkMessage) syncHandler,
    required void Function(NetworkMessage) actionHandler,
    required void Function(int) exitHandler,
  }) {
    if (_session case final game? when !game.ended.value) {
      throw StateError('Real-time game is already active in this room');
    }
    final game = RealGameSession(
      room: this,
      maxPlayers: maxPlayers,
      searchHandler: searchHandler,
      resourceHandler: resourceHandler,
      syncHandler: syncHandler,
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

/// 自动发现的实时房间使用专属引擎；手动地址使用认证后的原连接。
RealGameSession createRealSession({
  required NetworkEngine room,
  int? maxPlayers,
  required void Function(int) searchHandler,
  required void Function(NetworkMessage) resourceHandler,
  required void Function(NetworkMessage) syncHandler,
  required void Function(NetworkMessage) actionHandler,
  required void Function(int) exitHandler,
}) {
  if (room is NetRealEngine) {
    return room.createSession(
      maxPlayers: maxPlayers,
      searchHandler: searchHandler,
      resourceHandler: resourceHandler,
      syncHandler: syncHandler,
      actionHandler: actionHandler,
      exitHandler: exitHandler,
    );
  }
  return room.createRealGameForUnknownRoom(
    maxPlayers: maxPlayers,
    searchHandler: searchHandler,
    resourceHandler: resourceHandler,
    syncHandler: syncHandler,
    actionHandler: actionHandler,
    exitHandler: exitHandler,
  );
}
