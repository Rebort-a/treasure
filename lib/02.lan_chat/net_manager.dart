import 'dart:async';

import 'package:flutter/material.dart';

import '../00.common/network/client/socket_client.dart';
import '../00.common/model/notifiers.dart';

/// 聊天室导航管理器；离房先关闭连接，最终引擎和连接的释放归聊天室页面。
class NetManager {
  final SocketClient room;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  bool _leaving = false;

  NetManager({required SocketClient room}) : room = room;

  void leavePage() {
    if (_leaving) return;
    _leaving = true;
    unawaited(room.close());
    pageNavigator.value = (context) {
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      navigator.popUntil((candidate) => candidate == route);
      if (route?.isCurrent ?? false) navigator.pop();
    };
  }

  void dispose() {
    pageNavigator.dispose();
  }
}
