import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../00.common/model/notifiers.dart';
import '../../00.common/network/broadcast_discovery.dart';
import '../../00.common/network/protocol/network_message.dart';
import '../../00.common/network/protocol/network_room.dart';
import '../../00.common/network/server/socket_server.dart';
import '../base/created_room_info.dart';

/// 首页房间业务：发现房间、管理本地服务端及其成员监听，不依赖界面。
class HomeRoomManager {
  final ListNotifier<CreatedRoomInfo> createdRooms = ListNotifier([]);
  final ListNotifier<RoomInfo> othersRooms = ListNotifier([]);
  final Discovery _discovery = Discovery();
  final Map<SocketServer, VoidCallback> _serverListeners = {};
  bool _disposed = false;

  HomeRoomManager({bool startDiscovery = true}) {
    if (startDiscovery) {
      unawaited(_discovery.startReceive(_handleReceivedMessage));
    }
  }

  void _handleReceivedMessage(String address, List<int> data) {
    if (_disposed) return;
    final message = NetworkMessage.fromPlainSocketData(data);
    if (message == null) {
      debugPrint('[Home] 丢弃畸形房间广播消息');
      return;
    }
    if (message.type == MessageType.broadcast) {
      try {
        final config = jsonDecode(message.content) as Map<String, dynamic>;
        final operation = RoomInfo.getOperationFromJson(config);
        final port = RoomInfo.getPortFromJson(config);

        if (operation == RoomState.stop) {
          othersRooms.removeWhere(
            (room) =>
                room.name == message.source &&
                room.address == address &&
                room.port == port,
          );
        } else if (operation == RoomState.start) {
          final type = RoomInfo.getTypeFromJson(config);
          final count = (config['count'] as num?)?.toInt() ?? 0;
          final key = RoomInfo.getKeyFromJson(config);
          RoomInfo newRoom = RoomInfo(
            name: message.source,
            type: type,
            address: address,
            port: port,
            encryptionKey: key,
            hasPassword: config['hasPassword'] == true,
            count: count,
          );
          bool isNewRoom = !othersRooms.value.any(
            (room) =>
                room.name == newRoom.name &&
                room.address == newRoom.address &&
                room.port == newRoom.port,
          );
          if (isNewRoom) {
            othersRooms.add(newRoom);
            debugPrint(
              '[Room] Discovered: ${newRoom.name} at ${newRoom.address}:${newRoom.port} '
              'type=${newRoom.type} encrypted=true',
            );
          } else {
            final rooms = [...othersRooms.value];
            final index = rooms.indexWhere(
              (r) =>
                  r.name == newRoom.name &&
                  r.address == newRoom.address &&
                  r.port == newRoom.port,
            );
            if (rooms[index].count != newRoom.count ||
                rooms[index].type != newRoom.type ||
                rooms[index].hasPassword != newRoom.hasPassword ||
                rooms[index].encryptionKey != newRoom.encryptionKey) {
              rooms[index] = newRoom;
              othersRooms.value = rooms;
            }
          }
        }
      } catch (_) {
        debugPrint('[Home] 丢弃畸形房间配置');
      }
    }
  }

  Future<void> createRoom({
    required String roomName,
    required int type,
    String? password,
  }) async {
    if (_disposed) return;
    final encryptionKey = RoomInfo.generateEncryptionKey();

    SocketServer server = SocketServer(
      roomName: roomName,
      roomType: type,
      encryptionKey: encryptionKey,
      password: password,
    );

    await server.start();
    if (_disposed) {
      await server.stop();
      return;
    }

    debugPrint(
      '[Room] Created: $roomName on port ${server.port} '
      'type=$type locked=${password != null}',
    );

    createdRooms.add(
      CreatedRoomInfo(
        name: roomName,
        type: type,
        port: server.port,
        server: server,
        encryptionKey: encryptionKey,
        hasPassword: password != null,
        password: password,
      ),
    );
    void refresh() {
      if (!_disposed) createdRooms.value = [...createdRooms.value];
    }

    _serverListeners[server] = refresh;
    server.membersNotifier.addListener(refresh);
  }

  Future<void> stopCreatedRoom(int index) async {
    if (_disposed) return;
    final room = createdRooms.value[index];
    _detachServer(room.server);
    // 在异步停服前移出列表，避免连续操作或销毁后再次更新状态。
    createdRooms.removeAt(index);
    await room.server.stop();
  }

  Future<void> stopAllCreatedRooms() async {
    if (_disposed) return;
    final rooms = [...createdRooms.value];
    for (final room in rooms) {
      _detachServer(room.server);
    }
    createdRooms.clear();
    await Future.wait(rooms.map((room) => room.server.stop()));
  }

  void _detachServer(SocketServer server) {
    final listener = _serverListeners.remove(server);
    if (listener != null) server.membersNotifier.removeListener(listener);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _discovery.stopReceive();
    for (final server in _serverListeners.keys.toList()) {
      _detachServer(server);
    }
    for (final room in createdRooms.value) {
      unawaited(
        room.server.stop().catchError((Object error) {
          debugPrint('[Home] Room shutdown failed: $error');
        }),
      );
    }
    createdRooms.dispose();
    othersRooms.dispose();
  }
}
