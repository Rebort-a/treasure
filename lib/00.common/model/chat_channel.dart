import '../network/network_message.dart';
import 'notifiers.dart';

/// 聊天展示与输入的公共接口，不负责网络连接。
///
/// 房间聊天和对局私聊分别维护消息记录；输入与滚动控制器只归聊天组件所有。
abstract interface class ChatChannel {
  int get identity;
  String get userName;
  ListNotifier<NetworkMessage> get messageList;
  void sendText(String text);
}
