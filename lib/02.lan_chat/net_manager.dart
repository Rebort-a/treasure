import 'package:flutter/material.dart';

import '../00.common/engine/network_engine.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/network/network_room.dart';

class NetManager {
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  late final NetworkEngine networkEngine;
  NetManager({required String userName, required RoomInfo roomInfo}) {
    networkEngine = NetworkEngine(
      userName: userName,
      roomInfo: roomInfo,
      navigatorHandler: pageNavigator,
    );
  }

  void leavePage() {
    networkEngine.leavePage();
  }
}
