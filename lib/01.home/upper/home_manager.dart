import 'dart:async';

import 'package:flutter/material.dart';

import '../../00.common/l10n/strings.dart';
import '../../00.common/model/notifiers.dart';
import '../../00.common/network/client/socket_client.dart';
import '../../00.common/network/protocol/network_room.dart';
import '../base/created_room_info.dart';
import '../middle/player_settings.dart';
import '../middle/room_manager.dart';
import 'route.dart';
import 'widgets/room_dialog.dart';
import 'widgets/room_type_picker.dart';

export '../base/created_room_info.dart';

/// 首页界面协调器，只负责弹窗、路由与待加入连接的交接。
class HomeManager {
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  final HomeRoomManager _rooms;
  ListNotifier<CreatedRoomInfo> get createdRooms => _rooms.createdRooms;
  ListNotifier<RoomInfo> get othersRooms => _rooms.othersRooms;

  late final Future<void> _playerSettingsReady;
  SocketClient? _pendingRoom;
  bool _joiningRoom = false;
  bool _disposed = false;

  HomeManager({bool startDiscovery = true})
    : _rooms = HomeRoomManager(startDiscovery: startDiscovery) {
    _playerSettingsReady = PlayerSettings.instance.load();
  }

  Future<void> stopCreatedRoom(int index) => _rooms.stopCreatedRoom(index);

  Future<void> stopAllCreatedRooms() => _rooms.stopAllCreatedRooms();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pendingRoom?.dispose();
    _rooms.dispose();
    pageNavigator.dispose();
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
      if (!context.mounted || _disposed || type == null) return;
      RoomDialog.showCreateRoomDialog(
        context: context,
        onConfirm: (name, password) => unawaited(
          _rooms.createRoom(
            roomName: name,
            password: password,
            type: type.index,
          ),
        ),
      );
    };
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
        final dialog = DialogRoute<SocketClient>(
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
