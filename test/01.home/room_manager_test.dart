import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/broadcast_discovery.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/01.home/middle/room_manager.dart';

import '../00.common/network/support/network_room_harness.dart' show waitFor;

void main() {
  tearDown(Broadcast.dispose);

  test('房间业务维护创建信息与成员变化，停止一个房间不影响其他房间', () async {
    final manager = HomeRoomManager(startDiscovery: false);
    SocketClient? client;
    try {
      await manager.createRoom(
        roomName: 'Protected',
        type: 3,
        password: 'secret',
      );
      await manager.createRoom(roomName: 'Open', type: 0);
      final protected = manager.createdRooms.value.first;
      final open = manager.createdRooms.value.last;
      expect(protected.hasPassword, isTrue);
      expect(protected.server.roomType, 3);
      expect(protected.encryptionKey, protected.server.encryptionKey);
      expect(open.hasPassword, isFalse);

      var observedMembers = 0;
      manager.createdRooms.addListener(() {
        observedMembers = protected.server.members.length;
      });
      client = SocketClient(
        userName: 'Alice',
        endpoint: protected.withPassword('secret'),
      );
      await client.join();
      await waitFor(() => observedMembers == 1);

      await manager.stopCreatedRoom(0);
      expect(manager.createdRooms.value, [open]);
      expect(protected.server.members, isEmpty);
      await expectLater(
        Socket.connect(
          '127.0.0.1',
          protected.port,
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<SocketException>()),
      );

      await manager.stopAllCreatedRooms();
      expect(manager.createdRooms.value, isEmpty);
    } finally {
      client?.dispose();
      await manager.stopAllCreatedRooms();
      manager.dispose();
    }
  });

  test('销毁房间管理器会关闭服务端，异步停止不再更新已释放列表', () async {
    final manager = HomeRoomManager(startDiscovery: false);
    await manager.createRoom(roomName: 'Closing', type: 0);
    final room = manager.createdRooms.value.single;
    manager.dispose();
    // 等待同一个停服任务完成，验证管理器发起的资源释放。
    await room.server.stop();
    await expectLater(
      Socket.connect(
        '127.0.0.1',
        room.port,
        timeout: const Duration(seconds: 1),
      ),
      throwsA(isA<SocketException>()),
    );
    await expectLater(manager.stopAllCreatedRooms(), completes);
  });
}
