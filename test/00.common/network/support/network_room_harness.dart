import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/client_abstract.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/model/notifiers.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/broadcast_discovery.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/00.common/network/server/socket_server.dart';

Future<void> waitFor(
  bool Function() condition, {
  String Function()? label,
}) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Expected network state was not reached: ${label?.call()}');
}

class RoomHarness {
  final SocketServer server;
  final List<SocketClient> rooms = [];
  final List<RoomChatEngine> engines = [];
  RoomHarness(int type, {String? password, String? key})
    : server = SocketServer(
        roomName: 'Test room',
        roomType: type,
        password: password,
        encryptionKey: key ?? 'test-key',
      );

  Future<SocketClient> join(
    String name, {
    String? password,
    ClientTransport? transport,
    Duration gameAckTimeout = const Duration(milliseconds: 250),
    int maxGameResendAttempts = 4,
  }) async {
    final room = SocketClient(
      userName: name,
      endpoint: RoomInfo(
        name: '127.0.0.1',
        type: server.roomType,
        address: '127.0.0.1',
        port: server.port,
        encryptionKey: server.encryptionKey,
        password: password,
      ),
      transport: transport,
      gameAckTimeout: gameAckTimeout,
      maxGameResendAttempts: maxGameResendAttempts,
    );
    rooms.add(room);
    await room.join();
    engines.add(RoomChatEngine.forClient(room));
    return room;
  }

  Future<void> close() async {
    for (final engine in engines) {
      engine.dispose();
    }
    for (final room in rooms) {
      await room.close();
      room.dispose();
    }
    await server.stop();
    Broadcast.dispose();
  }
}

/// 旧网络测试仍以连接为入口；通过扩展访问认证后实际创建的消息处理引擎。
extension TestRoomEngine on SocketClient {
  RoomChatEngine get chat => RoomChatEngine.forClient(this);
  ListNotifier<NetworkMessage> get messageList => chat.messageList;
  int get matchedOpponentId => chat.matchedOpponentId;
  bool get matchInitiated => chat.matchInitiated;
  get matchPhase => chat.matchPhase;
  void startMatching() => chat.startMatching();
  void cancelMatching() => chat.cancelMatching();
  void openMatchedGame() => chat.openMatchedGame();
  void sendText(String text) => chat.sendText(text);
}
