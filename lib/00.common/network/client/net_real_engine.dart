import 'base/net_multi_engine.dart';
import 'room_chat_engine.dart';
import 'socket_client.dart';

/// 实时游戏沿用多人入局协议，由游戏 Manager 实现资源、同步和实时动作回调。
class NetRealEngine extends NetMultiEngine {
  NetRealEngine(super.client);

  static NetRealEngine forClient(SocketClient client) {
    final engine = RoomChatEngine.forClient(client);
    if (engine is! NetRealEngine) {
      throw StateError('Real-time room is not authenticated');
    }
    return engine;
  }
}
