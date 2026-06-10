import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:treasure/01.home/route.dart';

import '../00.common/tool/notifiers.dart';
import '../00.common/network/broadcast_discovery.dart';
import '../00.common/network/http_fetch.dart' as http_fetch;
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import '../00.common/network/socket_server.dart';
import 'dialog.dart';

class CreatedRoomInfo extends RoomInfo {
  final SocketServer server;

  CreatedRoomInfo({
    required super.name,
    required super.type,
    required super.port,
    required this.server,
    super.encryptionKey,
  }) : super(address: 'localhost');
}

class HomeManager {
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  final ListNotifier<CreatedRoomInfo> createdRooms = ListNotifier([]);
  final ListNotifier<RoomInfo> othersRooms = ListNotifier([]);

  final Discovery _discovery = Discovery();

  HomeManager() {
    _discovery.startReceive(_handleReceivedMessage);
  }

  void dispose() {
    _discovery.stopReceive();
  }

  void _handleReceivedMessage(String address, List<int> data) {
    NetworkMessage message = NetworkMessage.fromSocketData(data);
    if (message.type == MessageType.broadcast) {
      RoomState operation = RoomInfo.getOperationFromJsonString(
        message.content,
      );
      int port = RoomInfo.getPortFromJsonString(message.content);

      if (operation == RoomState.stop) {
        othersRooms.removeWhere(
          (room) =>
              room.name == message.source &&
              room.address == address &&
              room.port == port,
        );
      } else if (operation == RoomState.start) {
        int type = RoomInfo.getTypeFromJsonString(message.content);
        String? key = RoomInfo.getKeyFromJsonString(message.content);
        RoomInfo newRoom = RoomInfo(
          name: message.source,
          type: type,
          address: address,
          port: port,
          encryptionKey: key,
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
            'type=${newRoom.type} encrypted=${newRoom.encryptionKey != null}',
          );
        }
      }
    }
  }

  void showCreateRoomDialog() {
    pageNavigator.value = (BuildContext context) {
      RoomDialog.showCreateRoomDialog(context: context, onConfirm: _createRoom);
    };
  }

  void _createRoom(String roomName, NetItemType roomType) async {
    final encryptionKey = RoomInfo.generateEncryptionKey();

    SocketServer server = SocketServer(
      roomName: roomName,
      roomType: roomType.index,
      encryptionKey: encryptionKey,
    );

    await server.start();

    debugPrint(
      '[Room] Created: $roomName on port ${server.port} '
      'type=${roomType.index} encrypted=true',
    );

    createdRooms.add(
      CreatedRoomInfo(
        name: roomName,
        type: roomType.index,
        port: server.port,
        server: server,
        encryptionKey: encryptionKey,
      ),
    );
  }

  void stopAllCreatedRooms() async {
    for (var room in createdRooms.value) {
      await room.server.stop();
    }
    createdRooms.clear();
  }

  void stopCreatedRoom(int index) async {
    var room = createdRooms.value[index];
    await room.server.stop();
    createdRooms.removeAt(index);
  }

  void showJoinRoomDialog(RoomInfo room) {
    pageNavigator.value = (BuildContext context) {
      RoomDialog.showJoinRoomDialog(
        context: context,
        room: room,
        onConfirm: _joinRoom,
      );
    };
  }

  /// Web 端：手动输入 Host IP 和端口加入房间
  void showJoinByIpDialog() {
    pageNavigator.value = (BuildContext context) {
      RoomDialog.showJoinByIpDialog(context: context, onConfirm: _joinByIp);
    };
  }

  void _joinByIp(
    String userName,
    String host,
    int port,
    NetItemType type,
  ) async {
    String roomName = 'remote';
    String? encryptionKey;
    final body = await http_fetch.fetchRoomInfo(host, port);
    if (body != null) {
      try {
        final json = jsonDecode(body);
        if (json['source'] != null) roomName = json['source'] as String;
        encryptionKey = json['content'] != null
            ? RoomInfo.getKeyFromJsonString(json['content'] as String)
            : null;
      } catch (_) {}
    }

    final room = RoomInfo(
      name: roomName,
      type: type.index,
      address: host,
      port: port,
      encryptionKey: encryptionKey,
    );
    pageNavigator.value = (BuildContext context) {
      RouteManager.navigateToNetPage(context, userName, room);
    };
  }

  void _joinRoom(String userName, RoomInfo room, BuildContext context) {
    pageNavigator.value = (BuildContext context) {
      RouteManager.navigateToNetPage(context, userName, room);
    };
  }

  void routeLocal(LocalItemType routeType) {
    pageNavigator.value = (BuildContext context) {
      RouteManager.navigateToLocalPage(context, routeType);
    };
  }
}
