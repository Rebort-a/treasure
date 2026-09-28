import 'package:flutter/material.dart';
import 'package:treasure/00.common/engine/network_engine.dart';
import 'package:treasure/00.common/network/broadcast_discovery.dart';
import 'package:treasure/00.common/network/network_room.dart';
import 'package:treasure/00.common/network/socket_server.dart';
import 'package:treasure/00.common/tool/notifiers.dart';

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
        encryptionKey: key,
      );

  Future<NetworkEngine> join(String name, {String? password}) async {
    final room = NetworkEngine(
      userName: name,
      roomInfo: RoomInfo(
        name: '127.0.0.1',
        type: 0,
        address: '127.0.0.1',
        port: server.port,
        password: password,
      ),
      navigatorHandler: AlwaysNotifier<void Function(BuildContext)>((_) {}),
    );
    rooms.add(room);
    await waitFor(() => room.identity != 0);
    return room;
  }

  Future<void> close() async {
    for (final room in rooms) {
      await room.closeSocket();
      room.dispose();
      room.navigatorHandler.dispose();
    }
    await server.stop();
    Broadcast.dispose();
  }
}
