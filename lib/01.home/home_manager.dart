import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/model/notifiers.dart';
import '../00.common/network/base/broadcast_discovery.dart';
import '../00.common/network/base/network_message.dart';
import '../00.common/network/base/network_room.dart';
import '../00.common/network/middle/socket_server.dart';
import '../00.common/network/upper/network_engine.dart';
import 'room_type_picker.dart';
import '../00.common/l10n/strings.dart';
import 'player_settings.dart';

import 'dialog.dart';
import 'route.dart';

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
  late final Future<void> _playerSettingsReady;
  NetworkEngine? _pendingRoom;
  bool _joiningRoom = false;
  bool _disposed = false;

  HomeManager({bool startDiscovery = true}) {
    _playerSettingsReady = PlayerSettings.instance.load();
    if (startDiscovery) {
      _discovery.startReceive(_handleReceivedMessage);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pendingRoom?.dispose();
    _discovery.stopReceive();
    for (final entry in _serverListeners.entries) {
      entry.key.membersNotifier.removeListener(entry.value);
    }
    _serverListeners.clear();
    for (final room in createdRooms.value) {
      unawaited(room.server.stop());
    }
  }

  void _handleReceivedMessage(String address, List<int> data) {
    if (_disposed) return;
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

  void showCreateRoomDialog({OnlineItemType? onlineType}) {
    pageNavigator.value = (BuildContext context) async {
      final type =
          onlineType ??
          await RoomTypePicker.show<OnlineItemType>(
            context: context,
            options: OnlineItemType.values,
            titleOf: (value) => S.roomTypeString(value.name),
            isChat: (value) => value == OnlineItemType.onlyChat,
          );
      if (!context.mounted || type == null) return;
      RoomDialog.showCreateRoomDialog(
        context: context,
        onConfirm: (name, password) => _createRoom(name, password, type),
      );
    };
  }

  void _createRoom(
    String roomName,
    String? password,
    OnlineItemType type,
  ) async {
    final encryptionKey = RoomInfo.generateEncryptionKey();

    SocketServer server = SocketServer(
      roomName: roomName,
      roomType: type.index,
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
    server.membersNotifier.addListener(refresh);
  }

  void stopAllCreatedRooms() async {
    for (var room in createdRooms.value) {
      room.server.membersNotifier.removeListener(
        _serverListeners.remove(room.server)!,
      );
      await room.server.stop();
    }
    createdRooms.clear();
  }

  void stopCreatedRoom(int index) async {
    var room = createdRooms.value[index];
    room.server.membersNotifier.removeListener(
      _serverListeners.remove(room.server)!,
    );
    await room.server.stop();
    createdRooms.removeAt(index);
  }

  void showJoinRoomDialog(RoomInfo room) => _joinRoom(room);

  void showJoinByIpDialog() => _joinRoom(null);

  void _joinRoom(RoomInfo? room) {
    if (_joiningRoom || _disposed) return;
    _joiningRoom = true;
    pageNavigator.value = (BuildContext context) async {
      try {
        await _playerSettingsReady;
        if (!context.mounted || _disposed) return;
        final name = PlayerSettings.instance.defaultName.value.trim();
        final password = room is CreatedRoomInfo ? room.password : null;
        final dialog = DialogRoute<NetworkEngine>(
          context: context,
          barrierDismissible: false,
          builder: (_) => JoinRoomDialog(
            room: room,
            userName: name,
            password: password,
            startImmediately:
                room != null &&
                name.isNotEmpty &&
                (!room.hasPassword || password != null),
            onAttempt: (engine) => _pendingRoom = engine,
          ),
        );
        final engine = await Navigator.of(context).push(dialog);
        // 等待弹窗退场后再交接页面，期间仍由主页负责待加入连接。
        await dialog.completed;
        _pendingRoom = null;
        if (engine == null) return;
        if (!context.mounted || _disposed || !engine.isJoined) {
          engine.dispose();
          return;
        }
        try {
          await RouteManager.navigateToNetPage(context, engine);
        } finally {
          // 正常由聊天室释放；路由创建失败也不能遗留连接。
          engine.dispose();
        }
      } finally {
        _joiningRoom = false;
        _pendingRoom = null;
      }
    };
  }

  void routeLocal(AppItemType routeType) {
    pageNavigator.value = (BuildContext context) {
      RouteManager.navigateToLocalPage(context, routeType);
    };
  }
}
