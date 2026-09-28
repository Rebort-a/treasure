import 'dart:convert';

import 'package:flutter/material.dart';

import 'route.dart';

import '../00.common/tool/notifiers.dart';
import '../00.common/network/broadcast_discovery.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import '../00.common/network/socket_server.dart';
import '../00.common/widget/dialog/room_type_picker.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/tool/player_settings.dart';
import 'dialog.dart';

class CreatedRoomInfo extends RoomInfo {
  final SocketServer server;

  CreatedRoomInfo({
    required super.name,
    required super.type,
    required super.port,
    required this.server,
    super.encryptionKey,
    super.hasPassword,
    super.password,
  }) : super(address: 'localhost');
}

class HomeManager {
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  final ListNotifier<CreatedRoomInfo> createdRooms = ListNotifier([]);
  final ListNotifier<RoomInfo> othersRooms = ListNotifier([]);

  final Discovery _discovery = Discovery();
  final Map<SocketServer, VoidCallback> _serverListeners = {};

  HomeManager({bool startDiscovery = true}) {
    if (startDiscovery) {
      _discovery.startReceive(_handleReceivedMessage);
    }
  }

  void dispose() {
    _discovery.stopReceive();
    for (final entry in _serverListeners.entries) {
      entry.key.sessionNotifier.removeListener(entry.value);
    }
    _serverListeners.clear();
  }

  void _handleReceivedMessage(String address, List<int> data) {
    final message = NetworkMessage.fromSocketData(data);
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
              'type=${newRoom.type} encrypted=${newRoom.encryptionKey != null}',
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

  void showCreateRoomDialog() {
    pageNavigator.value = (BuildContext context) async {
      final type = await RoomTypePicker.show<NetItemType>(
        context: context,
        options: NetItemType.values,
        titleOf: (value) => S.roomTypeString(value.name),
        isChat: (value) => value == NetItemType.onlyChat,
      );
      if (!context.mounted || type == null) return;
      RoomDialog.showCreateRoomDialog(
        context: context,
        onConfirm: (name, password) => _createRoom(name, password, type),
      );
    };
  }

  void _createRoom(String roomName, String? password, NetItemType type) async {
    final encryptionKey = RoomInfo.generateEncryptionKey();

    SocketServer server = SocketServer(
      roomName: roomName,
      roomType: type.index,
      encryptionKey: encryptionKey,
      password: password,
    );

    await server.start();

    debugPrint(
      '[Room] Created: $roomName on port ${server.port} '
      'type=${type.name} locked=${password != null}',
    );

    createdRooms.add(
      CreatedRoomInfo(
        name: roomName,
        type: type.index,
        port: server.port,
        server: server,
        encryptionKey: encryptionKey,
        hasPassword: password != null,
        password: password,
      ),
    );
    void refresh() => createdRooms.value = [...createdRooms.value];
    _serverListeners[server] = refresh;
    server.sessionNotifier.addListener(refresh);
  }

  void stopAllCreatedRooms() async {
    for (var room in createdRooms.value) {
      room.server.sessionNotifier.removeListener(
        _serverListeners.remove(room.server)!,
      );
      await room.server.stop();
    }
    createdRooms.clear();
  }

  void stopCreatedRoom(int index) async {
    var room = createdRooms.value[index];
    room.server.sessionNotifier.removeListener(
      _serverListeners.remove(room.server)!,
    );
    await room.server.stop();
    createdRooms.removeAt(index);
  }

  void showJoinRoomDialog(RoomInfo room) {
    final name = PlayerSettings.instance.defaultName.value.trim();
    final ownPassword = room is CreatedRoomInfo ? room.password : null;
    if (name.isNotEmpty && (!room.hasPassword || ownPassword != null)) {
      _joinRoom(name, ownPassword, room);
      return;
    }
    pageNavigator.value = (BuildContext context) {
      RoomDialog.showJoinRoomDialog(
        context: context,
        room: room,
        defaultUserName: name,
        onConfirm: _joinRoom,
      );
    };
  }

  /// Web 端：手动输入 Host IP 和端口加入房间
  void showJoinByIpDialog() {
    pageNavigator.value = (BuildContext context) {
      RoomDialog.showJoinByIpDialog(
        context: context,
        defaultUserName: PlayerSettings.instance.defaultName.value,
        onConfirm: _joinByIp,
      );
    };
  }

  void _joinByIp(String userName, String host, int port, String? password) {
    _joinRoom(
      userName,
      password,
      RoomInfo(
        name: host,
        type: RoomInfo.chatType, // 房间实际类型和密钥由 accept 返回。
        address: host,
        port: port,
      ),
    );
  }

  void _joinRoom(String userName, String? password, RoomInfo room) {
    pageNavigator.value = (BuildContext context) {
      RouteManager.navigateToNetPage(
        context,
        userName,
        room.withPassword(password),
      );
    };
  }

  void routeLocal(LocalItemType routeType) {
    pageNavigator.value = (BuildContext context) {
      RouteManager.navigateToLocalPage(context, routeType);
    };
  }
}
