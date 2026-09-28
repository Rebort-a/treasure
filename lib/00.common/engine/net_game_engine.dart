import 'package:flutter/material.dart';

import '../chat/chat_channel.dart';
import '../game/step.dart';
import '../network/network_message.dart';
import '../tool/notifiers.dart';
import 'network_engine.dart';

/// 复用房间现有连接的单次游戏会话，生命周期仅覆盖本次对局。
abstract class NetGameEngine implements ChatChannel {
  static int _sequence = 0;
  final NetworkEngine room;
  late final String requestId =
      '$identity-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  late String sessionId = requestId;
  final gameStep = ValueNotifier(GameStep.start);
  final readyToOpen = ValueNotifier(false);
  final ended = ValueNotifier(false);
  bool _started = false;
  bool _disposed = false;

  @override
  final messageList = ListNotifier<NetworkMessage>([]);
  @override
  final scrollController = ScrollController();
  @override
  final textController = TextEditingController();
  @override
  int get identity => room.identity;
  @override
  String get userName => room.userName;
  bool get isActive => _started && !ended.value;

  NetGameEngine({required this.room});

  void start() {
    if (_started || identity == 0 || ended.value) return;
    _started = true;
    room.addMessageListener(_receive);
    room.identityNotifier.addListener(_identityChanged);
    room.sendRoomNotice(RoomNotice.matchingPlayers);
    sendNetworkMessage(MessageType.search, 'search');
  }

  void _identityChanged() {
    if (identity == 0) finish(sendExit: false);
  }

  void _receive(NetworkMessage message) {
    if (!isActive) return;
    if (message.type == MessageType.exit && message.id == 0) {
      finish(sendExit: false);
      return;
    }
    try {
      handleMessage(message);
    } on FormatException {
      debugPrint('[Game] Ignored malformed game data');
    } on TypeError {
      debugPrint('[Game] Ignored invalid game data');
    }
  }

  void handleMessage(NetworkMessage message);

  void sendNetworkMessage(MessageType type, String content, {int? targetId}) {
    if (!isActive) return;
    room.sendNetworkMessage(
      type,
      content,
      targetId: targetId,
      sessionId: sessionId,
    );
  }

  @override
  void sendInputText() {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    sendNetworkMessage(MessageType.text, text);
    textController.clear();
  }

  void leavePage() => finish();

  void finish({bool sendExit = true}) {
    if (ended.value) return;
    if (isActive && sendExit && identity != 0) {
      sendNetworkMessage(MessageType.exit, 'game');
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
    scrollController.dispose();
    textController.dispose();
    gameStep.dispose();
    readyToOpen.dispose();
    ended.dispose();
  }
}
