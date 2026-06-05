import 'package:flutter/material.dart';

import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/network/network_room.dart';
import '../l10n/strings.dart';
import 'route.dart';

class RoomDialog {
  static void showCreateRoomDialog({
    required BuildContext context,
    required Function(String roomName, NetItemType roomType) onConfirm,
  }) {
    DialogTemplate.optionDialog<NetItemType>(
      context: context,
      title: S.createRoom,
      hintText: S.enterRoomName,
      confirmButtonText: S.create,
      options: NetItemType.values,
      onConfirm: onConfirm,
    );
  }

  static void showJoinRoomDialog({
    required BuildContext context,
    required RoomInfo room,
    required Function(String userName, RoomInfo room, BuildContext context)
    onConfirm,
  }) {
    DialogTemplate.inputDialog(
      context: context,
      title: S.joinRoom,
      hintText: S.enterUserName,
      confirmButtonText: S.join,
      onConfirm: (userName) => onConfirm(userName, room, context),
    );
  }

  static void showLeaveRoomDialog({
    required BuildContext context,
    required RoomInfo room,
    required Function() onConfirm,
  }) {
    DialogTemplate.promptDialog(
      context: context,
      title: S.leave,
      content: S.leaveRoom,
      before: () => true,
      after: onConfirm,
    );
  }

  /// Web 端：手动输入 Host IP、端口和用户名加入房间
  static void showJoinByIpDialog({
    required BuildContext context,
    required Function(String userName, String host, int port, NetItemType type)
        onConfirm,
  }) {
    String userName = '';
    String host = '';
    String portStr = '';
    NetItemType selectedType = NetItemType.values.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.joinRoom),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (v) => userName = v,
                decoration: InputDecoration(hintText: S.userName),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => host = v,
                decoration: InputDecoration(
                    hintText: S.hostIp),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => portStr = v,
                decoration: InputDecoration(hintText: S.port),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<NetItemType>(
                initialValue: selectedType,
                onChanged: (v) {
                  if (v != null) setState(() => selectedType = v);
                },
                items: NetItemType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.toString().split('.').last),
                        ))
                    .toList(),
                decoration: InputDecoration(labelText: S.game),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: () {
                final port = int.tryParse(portStr);
                if (userName.isNotEmpty && host.isNotEmpty && port != null) {
                  Navigator.pop(context);
                  onConfirm(userName, host, port, selectedType);
                }
              },
              child: Text(S.join),
            ),
          ],
        ),
      ),
    );
  }
}
