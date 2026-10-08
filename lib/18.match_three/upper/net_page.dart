import 'package:flutter/material.dart';

import '../../00.common/network/client/socket_client.dart';
import '../../00.common/network/widget/online_game_host.dart';
import '../middle/net_manager.dart';
import 'game_view.dart';

/// 游戏模块唯一联机入口，只接收已认证的房间连接，不暴露 Manager。
class NetMatchThreePage extends StatelessWidget {
  final SocketClient room;

  const NetMatchThreePage({super.key, required this.room});

  @override
  Widget build(BuildContext context) => OnlineGameHost<NetMatchManager>(
    createManager: () => NetMatchManager(room: room),
    engineOf: (manager) => manager.turnEngine,
    disposeManager: (manager) => manager.dispose(),
    pageBuilder: (_, manager, requestExit) => MatchGameView(
      manager: manager,
      engine: manager.turnEngine,
      onExit: requestExit,
    ),
  );
}
