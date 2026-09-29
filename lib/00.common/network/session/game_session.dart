import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../model/chat_channel.dart';
import '../../game/step.dart';
import '../network_message.dart';
import '../../model/notifiers.dart';
import '../engine/network_engine.dart';

/// 复用房间现有连接的单次游戏会话，生命周期仅覆盖本次对局。
abstract class GameSession implements ChatChannel {
  final NetworkEngine room;
  final gameStep = ValueNotifier(GameStep.start);
  final readyToOpen = ValueNotifier(false);
  final ended = ValueNotifier(false);
  bool _started = false;
  bool _disposed = false;

  @override
  final messageList = ListNotifier<NetworkMessage>([]);
  @override
  int get identity => room.identity;
  @override
  String get userName => room.userName;
  bool get isActive => _started && !ended.value;

  GameSession({required this.room});

  /// 从已确认的房间匹配状态启动，不再传递匹配包装对象。
  void startFromRoom();

  /// 已完成匹配时只接管房间消息，不重复广播搜索或匹配通知。
  void activateAfterMatch() => _activate();

  void _activate() {
    if (_started || !room.isJoined || ended.value) return;
    _started = true;
    room.identityNotifier.addListener(_identityChanged);
    room.addGameMessageListener(_receive);
  }

  void _identityChanged() {
    if (identity == 0) finish(sendExit: false);
  }

  void _receive(NetworkMessage message) {
    if (!isActive) return;
    if (message.type == MessageType.roomClosed && message.id == 0) {
      finish(sendExit: false);
      return;
    }
    try {
      if (message.type == MessageType.memberLeft && message.id == 0) {
        memberLeft(
          (jsonDecode(message.content) as Map<String, dynamic>)['memberId']
              as int,
        );
        return;
      }
      handleMessage(message);
    } on FormatException {
      debugPrint('[Game] Ignored malformed game data');
    } on TypeError {
      debugPrint('[Game] Ignored invalid game data');
    }
  }

  void handleMessage(NetworkMessage message);
  void memberLeft(int memberId);

  void sendNetworkMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
  }) {
    if (!isActive) return;
    room.sendNetworkMessage(
      type,
      content,
      recipientId: recipientId,
      recipientIds: recipientIds,
    );
  }

  @override
  void sendText(String input) {
    final text = input.trim();
    if (text.isEmpty) return;
    sendNetworkMessage(MessageType.text, text);
  }

  void leavePage() => finish();

  /// 游戏引擎只在匹配确认后创建；页面尚未打开也属于已成立的对局。
  void cancelMatch() => finish();

  void finish({bool sendExit = true}) {
    if (ended.value) return;
    if (isActive && sendExit && identity != 0) {
      sendNetworkMessage(MessageType.gameExit, 'game');
      room.sendRoomNotice(RoomNotice.leftGame);
    }
    room.removeMessageListener(_receive);
    room.identityNotifier.removeListener(_identityChanged);
    gameStep.value = GameStep.gameOver;
    ended.value = true;
  }

  void dispose() {
    if (_disposed) return;
    finish();
    _disposed = true;
    messageList.dispose();
    gameStep.dispose();
    readyToOpen.dispose();
    ended.dispose();
  }
}
