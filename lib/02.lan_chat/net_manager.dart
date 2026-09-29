import 'dart:async';

import 'package:flutter/material.dart';

import '../00.common/network/engine/network_engine.dart';
import '../00.common/model/notifiers.dart';

/// 聊天室持有已认证的房间引擎，并独立处理页面生命周期。
class NetManager {
  final NetworkEngine room;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});
  bool _leaving = false;

  NetManager({required NetworkEngine room}) : room = room;

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
    room.dispose();
    pageNavigator.dispose();
  }
}
