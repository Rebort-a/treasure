import 'package:flutter/material.dart';

import '../00.common/network/network_room.dart';
import '../00.common/l10n/strings.dart';

class RoomDialog {
  static void showCreateRoomDialog({
    required BuildContext context,
    required void Function(String roomName, String? password) onConfirm,
  }) {
    var roomName = '';
    var password = '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.createRoom),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(labelText: S.enterRoomName),
                onChanged: (value) => roomName = value,
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: S.roomPassword,
                  helperText: S.passwordOptional,
                ),
                onChanged: (value) => password = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = roomName.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext);
              onConfirm(name, password.trim().isEmpty ? null : password);
            },
            child: Text(S.create),
          ),
        ],
      ),
    );
  }

  static void showJoinRoomDialog({
    required BuildContext context,
    required RoomInfo room,
    required String defaultUserName,
    required void Function(String userName, String? password, RoomInfo room)
    onConfirm,
  }) {
    var userName = defaultUserName;
    var password = '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.joinRoom),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (defaultUserName.isEmpty)
              TextFormField(
                initialValue: defaultUserName,
                autofocus: true,
                decoration: InputDecoration(labelText: S.enterUserName),
                onChanged: (value) => userName = value,
              ),
            if (room.hasPassword)
              TextField(
                autofocus: defaultUserName.isNotEmpty,
                obscureText: true,
                decoration: InputDecoration(labelText: S.roomPassword),
                onChanged: (value) => password = value,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = userName.trim();
              if (name.isEmpty || (room.hasPassword && password.isEmpty)) {
                return;
              }
              Navigator.pop(dialogContext);
              onConfirm(name, room.hasPassword ? password : null, room);
            },
            child: Text(S.join),
          ),
        ],
      ),
    );
  }

  /// 手动输入 Host IP、端口和用户名加入聊天室
  static void showJoinByIpDialog({
    required BuildContext context,
    required String defaultUserName,
    required void Function(
      String userName,
      String host,
      int port,
      String? password,
    )
    onConfirm,
  }) {
    String userName = defaultUserName;
    String host = '';
    String portStr = '';
    String password = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.joinRoom),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: defaultUserName,
                onChanged: (v) => userName = v,
                decoration: InputDecoration(hintText: S.userName),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => host = v,
                decoration: InputDecoration(hintText: S.hostIp),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => portStr = v,
                decoration: InputDecoration(hintText: S.port),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                obscureText: true,
                onChanged: (v) => password = v,
                decoration: InputDecoration(
                  labelText: S.roomPassword,
                  helperText: S.passwordIfNeeded,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () {
              final port = int.tryParse(portStr);
              if (userName.trim().isNotEmpty &&
                  host.trim().isNotEmpty &&
                  port != null &&
                  port > 0 &&
                  port <= 65535) {
                Navigator.pop(context);
                onConfirm(
                  userName.trim(),
                  host.trim(),
                  port,
                  password.isEmpty ? null : password,
                );
              }
            },
            child: Text(S.join),
          ),
        ],
      ),
    );
  }
}
