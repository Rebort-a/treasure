import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../game/step.dart';
import '../../../model/notifiers.dart';
import '../../protocol/network_message.dart';
import '../room_chat_engine.dart';
import 'round_replay.dart';

/// 回合和实时引擎复用的“单局”生命周期；不是另一个连接或会话对象。
///
/// 引擎随房间页面存在，每次进入游戏页时配置回调并建立会话聊天。
/// 棋盘结束不解除订阅；快速重开保留聊天，离开会话才停止局内订阅。
mixin GameEngine on RoomChatEngine {
  final gameStep = ValueNotifier(GameStep.start);
  final readyToOpen = ValueNotifier(false);
  final ended = ValueNotifier(true);
  final gameMessageList = ListNotifier<NetworkMessage>([]);

  /// 各类游戏共用的当前棋盘成员表，不包含房间旁观者或尚未准备重开的玩家。
  @protected
  final Map<int, String> gameMembers = {};
  Map<int, String> get participants => Map.unmodifiable(gameMembers);
  bool _configured = false;
  bool _started = false;
  int _gameEpoch = 0;
  int _gameMessageCounter = 0;
  String? _gameId;
  RoundReplay? roundReplay;
  Map<int, String> Function()? _replayRoster;
  final List<NetworkMessage> _roundBuffer = [];

  bool get isActive => _configured && _started && !ended.value;
  String? get gameId => _gameId;

  void configureReplay({
    required Map<int, String> Function() roster,
    required void Function(List<int>, bool, bool) startRound,
  }) {
    _replayRoster = roster;
    roundReplay = RoundReplay(
      identity: () => identity,
      availableMembers: () => members.value,
      send: (content, targets) =>
          _sendSessionMessage(MessageType.sync, content, targets),
      start: startRound,
      onFinished: () {
        _roundBuffer.clear();
        gameStep.value = GameStep.gameOver;
      },
      onDrain: () {
        final buffered = _roundBuffer.toList();
        _roundBuffer.clear();
        for (final message in buffered) {
          _receiveGameMessage(message);
        }
      },
      onMemberLeft: memberLeft,
    );
  }

  /// 结束棋盘但不解除会话订阅，聊天和重开控制仍然可用。
  void completeRound() {
    if (!isActive) return;
    roundReplay?.observe(_replayRoster!());
    roundReplay?.complete();
  }

  void requestReplay() => roundReplay?.request();

  void _sendSessionMessage(MessageType type, String content, Set<int> targets) {
    if (!isActive || targets.isEmpty) return;
    client.sendNetworkMessage(
      type,
      content,
      recipientIds: targets,
      messageId: 'game-$_gameEpoch-${++_gameMessageCounter}',
      gameId: _gameId,
    );
  }

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
    gameMembers.clear();
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
    roundReplay?.observe(_replayRoster!());
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
        roundReplay?.remove(notification!.memberId!);
        memberLeft(notification!.memberId!);
      }
      return;
    }
    // 房间通知与搜索不属于任何对局；其他定向消息必须带当前对局 ID。
    if (!message.isRoomMessage && message.gameId != _gameId) return;
    try {
      final replay = roundReplay;
      if (replay != null) {
        if (replay.handle(message)) return;
        if (message.type == MessageType.text &&
            replay.members.containsKey(message.id) &&
            !message.isRoomMessage &&
            message.recipientIds.contains(identity)) {
          gameMessageList.add(message);
          return;
        }
        if (!message.isRoomMessage &&
            message.type != MessageType.text &&
            message.type != MessageType.exit &&
            message.type != MessageType.confirm &&
            message.type != MessageType.match) {
          final envelope = jsonDecode(message.content);
          if (envelope is! Map<String, dynamic> ||
              envelope['round'] is! int ||
              envelope['version'] is! int ||
              envelope['data'] is! String) {
            return;
          }
          final messageRound = envelope['round'] as int;
          final messageVersion = envelope['version'] as int;
          if (message.type == MessageType.resource &&
              message.id == matchedOpponentId &&
              gameStep.value != GameStep.action) {
            final sessionPlayers = envelope['sessionPlayers'];
            if (sessionPlayers is List &&
                sessionPlayers.every(
                  (id) => id is int && members.value.containsKey(id),
                ) &&
                sessionPlayers.contains(identity) &&
                sessionPlayers.contains(message.id)) {
              replay.members.addAll({
                for (final id in sessionPlayers.cast<int>())
                  id: members.value[id]!,
              });
            }
            replay.bootstrap(messageRound, messageVersion);
          }
          if (replay.isPending(messageRound, messageVersion)) {
            if (_roundBuffer.length < 128) _roundBuffer.add(message);
            return;
          }
          if (replay.preparing.value ||
              !replay.accepts(messageRound, messageVersion)) {
            return;
          }
          message = NetworkMessage(
            id: message.id,
            type: message.type,
            source: message.source,
            content: envelope['data'] as String,
            timestamp: message.timestamp,
            recipientIds: message.recipientIds,
            messageId: message.messageId,
            gameId: message.gameId,
          );
        }
      }
      handleGameMessage(message);
      replay?.observe(_replayRoster!());
    } on FormatException {
      debugPrint('[Game] Ignored malformed game data');
    } on TypeError {
      debugPrint('[Game] Ignored invalid game data');
    }
  }

  /// 统一按当前成员限制接收范围；大厅文本仍使用 RoomChatEngine.sendText。
  void sendGameMessage(
    MessageType type,
    String content, {
    Set<int>? recipientIds,
  }) {
    if (!isActive || type == MessageType.image || type == MessageType.file) {
      return;
    }
    final targets = recipientIds ?? gameMembers.keys.toSet();
    // 默认投递给本局全体成员，显式子集也必须非空且全部属于当前局面。
    if (targets.isEmpty ||
        targets.any((id) => id <= 0 || !gameMembers.containsKey(id))) {
      return;
    }
    final replay = roundReplay;
    if (type == MessageType.resource) replay?.observe(_replayRoster!());
    if (replay != null &&
        type != MessageType.text &&
        type != MessageType.exit &&
        type != MessageType.confirm &&
        type != MessageType.match) {
      content = jsonEncode({
        'round': replay.round,
        'version': replay.version,
        'data': content,
        if (type == MessageType.resource)
          'sessionPlayers': replay.members.keys.toList(),
      });
    }
    client.sendNetworkMessage(
      type,
      content,
      recipientIds: targets,
      messageId: 'game-$_gameEpoch-${++_gameMessageCounter}',
      gameId: _gameId,
    );
  }

  void sendGameText(String input) {
    final text = input.trim();
    if (text.isEmpty) return;
    final replay = roundReplay;
    if (replay != null) {
      _sendSessionMessage(MessageType.text, text, replay.members.keys.toSet());
    } else {
      sendGameMessage(MessageType.text, text);
    }
  }

  void leavePage() => finishGame();

  void cancelMatch() {
    finishGame();
    cancelMatching();
  }

  void finishGame({bool sendExit = true}) {
    if (ended.value) return;
    if (sendExit && isActive) roundReplay?.leave();
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
    roundReplay?.dispose();
    roundReplay = null;
    _replayRoster = null;
    _roundBuffer.clear();
    gameMembers.clear();
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
