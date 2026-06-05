import 'package:flutter/material.dart';

import '../engine/net_turn_engine.dart';
import '../network/network_message.dart';
import '../network/network_room.dart';
import '../tool/notifiers.dart';
import 'step.dart';

/// 联机回合制游戏的通用服务
///
/// 封装了 [NetTurnGameEngine] 的创建和生命周期管理，
/// 消除各游戏中重复的引擎初始化、导航返回等样板代码。
/// 通过组合方式使用：在各游戏的 NetManager 中创建一个实例。
class NetTurnGameService {
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  late final NetTurnGameEngine netTurnEngine;

  NetTurnGameService({
    required String userName,
    required RoomInfo roomInfo,
    required void Function() onSearch,
    required void Function(GameStep, NetworkMessage) onResource,
    required void Function(bool, NetworkMessage) onAction,
    required void Function() onExit,
  }) {
    netTurnEngine = NetTurnGameEngine(
      userName: userName,
      roomInfo: roomInfo,
      navigatorHandler: pageNavigator,
      searchHandler: onSearch,
      resourceHandler: onResource,
      actionHandler: onAction,
      exitHandler: onExit,
    );
  }

  /// 离开页面（发送退出消息并返回上一页）
  void leavePage() {
    netTurnEngine.leavePage();
  }
}
