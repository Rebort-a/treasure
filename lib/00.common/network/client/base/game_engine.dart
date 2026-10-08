import 'package:flutter/foundation.dart';

import '../../../game/step.dart';
import '../../../model/notifiers.dart';
import '../../protocol/network_message.dart';
import '../room_chat_engine.dart';

/// 回合和实时引擎复用的“单局”生命周期；不是另一个连接或会话对象。
///
/// 引擎随房间页面存在，每次进入游戏时重新配置回调并清空对局聊天。
/// 结束对局只取消局内消息订阅，不影响房间聊天与连接。
mixin GameEngine on RoomChatEngine {
  final gameStep = ValueNotifier(GameStep.start);
  final readyToOpen = ValueNotifier(false);
  final ended = ValueNotifier(true);
  final gameMessageList = ListNotifier<NetworkMessage>([]);
  bool _configured = false;
  bool _started = false;
  int _gameEpoch = 0;
  int _gameMessageCounter = 0;
  String? _gameId;

  bool get isActive => _configured && _started && !ended.value;
  String? get gameId => _gameId;

  /// 游戏 Manager 创建时调用；上一局必须已结束，不能同时配置两局。
  void prepareGame() {
    if (_configured) {
      throw StateError('Previous game manager has not been released');
    }
    _configured = true;
    _started = false;
    final now = DateTime.now().microsecondsSinceEpoch;
    _gameEpoch = now > _gameEpoch ? now : _gameEpoch + 1;
    _gameMessageCounter = 0;
    _gameId = null;
    gameStep.value = GameStep.start;
    readyToOpen.value = false;
    gameMessageList.clear();
    ended.value = false;
  }

  void startFromRoom();
  void handleGameMessage(NetworkMessage message);
  void memberLeft(int memberId);

  /// 匹配由房间引擎处理；游戏引擎只接管已确认的结果。
  void activateAfterMatch({required String gameId}) {
    if (!_configured || _started || !client.isJoined || ended.value) return;
    if (gameId.isEmpty || gameId.length > 128) {
      throw ArgumentError.value(gameId, 'gameId', 'Invalid game identity');
    }
    _gameId = gameId;
    _started = true;
    client.identityNotifier.addListener(_identityChanged);
    client.deliveryFailure.addListener(_deliveryFailed);
    addGameMessageListener(_receiveGameMessage);
  }

  void _deliveryFailed() {
    final message = client.deliveryFailure.value;
    if (message != null &&
        message.gameId == _gameId &&
        message.messageId?.startsWith('game-$_gameEpoch-') == true &&
        (const {
              MessageType.publish,
              MessageType.resource,
              MessageType.sync,
              MessageType.action,
              MessageType.exit,
            }.contains(message.type) ||
            (message.type == MessageType.text && !message.isRoomMessage))) {
      // 关键局内消息无法确认时不能继续在本地推进另一份不一致的游戏状态。
      finishGame(sendExit: false);
    }
  }

  void _identityChanged() {
    if (identity == 0) finishGame(sendExit: false);
  }

  void _receiveGameMessage(NetworkMessage message) {
    if (!isActive) return;
    if (message.type == MessageType.notify && message.id == 0) {
      final notification = RoomNotification.tryFromContent(message.content);
      if (notification?.type == NoticeType.close) {
        finishGame(sendExit: false);
      } else if (notification?.type == NoticeType.left) {
        memberLeft(notification!.memberId!);
      }
      return;
    }
    // 房间通知与搜索不属于任何对局；其他定向消息必须带当前对局 ID。
    if (!message.isRoomMessage && message.gameId != _gameId) return;
    try {
      handleGameMessage(message);
    } on FormatException {
      debugPrint('[Game] Ignored malformed game data');
    } on TypeError {
      debugPrint('[Game] Ignored invalid game data');
    }
  }

  /// 子类负责限制接收者；大厅文本仍使用 RoomChatEngine.sendText。
  void sendGameMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
  }) {
    if (!isActive) return;
    client.sendNetworkMessage(
      type,
      content,
      recipientId: recipientId,
      recipientIds: recipientIds,
      messageId: 'game-$_gameEpoch-${++_gameMessageCounter}',
      gameId: _gameId,
    );
  }

  void sendGameText(String input) {
    final text = input.trim();
    if (text.isNotEmpty) sendGameMessage(MessageType.text, text);
  }

  void leavePage() => finishGame();

  void cancelMatch() {
    finishGame();
    cancelMatching();
  }

  void finishGame({bool sendExit = true}) {
    if (ended.value) return;
    if (isActive && sendExit && identity != 0) {
      sendGameMessage(MessageType.exit, 'game');
    }
    removeGameMessageListener(_receiveGameMessage);
    client.identityNotifier.removeListener(_identityChanged);
    client.deliveryFailure.removeListener(_deliveryFailed);
    gameStep.value = GameStep.gameOver;
    ended.value = true;
    _started = false;
  }

  /// Manager 释放时解除本局配置，供同一引擎承接下一局。
  void releaseGame() {
    finishGame();
    _configured = false;
  }

  void disposeGameEngine() {
    releaseGame();
    gameMessageList.dispose();
    gameStep.dispose();
    readyToOpen.dispose();
    ended.dispose();
  }
}
