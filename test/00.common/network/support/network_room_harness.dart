import 'package:treasure/00.common/network/client/network_engine.dart';
import 'package:treasure/00.common/network/broadcast_discovery.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/00.common/network/server/socket_server.dart';

Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Expected network state was not reached');
}

class RoomHarness {
  final SocketServer server;
  final List<NetworkEngine> rooms = [];
  RoomHarness(int type, {String? password, String? key})
    : server = SocketServer(
        roomName: 'Test room',
        roomType: type,
        password: password,
        encryptionKey: key ?? 'test-key',
      );

  Future<NetworkEngine> join(String name, {String? password}) async {
    final room = NetworkEngine.forRoom(
      userName: name,
      endpoint: RoomInfo(
        name: '127.0.0.1',
        type: server.roomType,
        address: '127.0.0.1',
        port: server.port,
        encryptionKey: server.encryptionKey,
        password: password,
      ),
    );
    rooms.add(room);
    await room.join();
    return room;
  }

  Future<void> close() async {
    for (final room in rooms) {
      await room.close();
      room.dispose();
    }
    await server.stop();
    Broadcast.dispose();
  }
}
