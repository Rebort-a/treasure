import 'package:flutter/material.dart';

import '../network/network_message.dart';
import '../tool/notifiers.dart';

/// 聊天展示与输入的公共接口，不负责网络连接。
///
/// 房间聊天和对局私聊分别维护消息记录、输入控制器和滚动控制器。
abstract interface class ChatChannel {
  int get identity;
  String get userName;
  ListNotifier<NetworkMessage> get messageList;
  ScrollController get scrollController;
  TextEditingController get textController;
  void sendInputText();
}
