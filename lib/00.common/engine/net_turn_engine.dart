import 'dart:convert';

import '../game/gamer.dart';
import '../game/step.dart';
import '../network/network_message.dart';
import 'net_game_engine.dart';

enum TurnResourceMode { none, frontOnly, both }

class NetTurnGameEngine extends NetGameEngine {
  final TurnResourceMode resourceMode;
  final void Function() searchHandler;
  final void Function(GameStep, NetworkMessage) resourceHandler;
  final void Function(bool, NetworkMessage) actionHandler;
  final void Function() exitHandler;
  late TurnGamerType playerType;
  int _enemyId = 0;
  String? _enemyRequestId;
  bool _searchEchoed = false;
  int get enemyId => _enemyId;

  NetTurnGameEngine({
    required super.room,
    required this.resourceMode,
    this.searchHandler = _noSearch,
    this.resourceHandler = _noResource,
    required this.actionHandler,
    required this.exitHandler,
  });

  static void _noSearch() {}
  static void _noResource(GameStep step, NetworkMessage message) {}

  @override
  void sendNetworkMessage(MessageType type, String content, {int? targetId}) {
    if (type == MessageType.search) {
      super.sendNetworkMessage(type, content);
      return;
    }
    if (_enemyId == 0) {
      if (type == MessageType.exit) super.sendNetworkMessage(type, content);
      return;
    }
    if (type == MessageType.image || type == MessageType.file) return;
    if (const {
      MessageType.resource,
      MessageType.action,
      MessageType.text,
      MessageType.emoji,
    }.contains(type)) {
      super.sendNetworkMessage(type, content, targetId: identity);
    }
    super.sendNetworkMessage(type, content, targetId: targetId ?? _enemyId);
  }

  @override
  void handleMessage(NetworkMessage message) {
    if (message.type == MessageType.search) {
      if (message.id == identity && message.sessionId == requestId) {
        _searchEchoed = true;
        return;
      }
      if (!_searchEchoed ||
          gameStep.value != GameStep.start ||
          message.id == identity ||
          message.sessionId == null) {
        return;
      }
      _enemyId = message.id;
      _enemyRequestId = message.sessionId;
      playerType = TurnGamerType.front;
      gameStep.value = resourceMode == TurnResourceMode.none
          ? GameStep.action
          : GameStep.frontConfig;
      sendNetworkMessage(
        MessageType.match,
        jsonEncode({'request': message.sessionId}),
      );
      readyToOpen.value = true;
      if (resourceMode != TurnResourceMode.none) searchHandler();
      return;
    }
    if (message.type == MessageType.match &&
        gameStep.value == GameStep.start &&
        message.targetId == identity &&
        message.sessionId != null) {
      final data = jsonDecode(message.content) as Map<String, dynamic>;
      if (data['request'] != requestId) return;
      _enemyId = message.id;
      _enemyRequestId = message.sessionId;
      sessionId = message.sessionId!;
      playerType = TurnGamerType.rear;
      gameStep.value = resourceMode == TurnResourceMode.none
          ? GameStep.action
          : GameStep.rearWait;
      readyToOpen.value = true;
      return;
    }
    if (message.id != identity && message.id != _enemyId) return;
    if (message.type == MessageType.exit &&
        message.id == _enemyId &&
        (message.sessionId == null ||
            message.sessionId == sessionId ||
            message.sessionId == _enemyRequestId)) {
      exitHandler();
      // 对手离开仅结束本次对局，不关闭房间连接。
      finish();
      return;
    }
    if (message.sessionId != sessionId || message.targetId != identity) return;
    switch (message.type) {
      case MessageType.resource:
        _resource(message);
      case MessageType.action:
        if (gameStep.value == GameStep.action) {
          actionHandler(message.id == identity, message);
        }
      case MessageType.text:
      case MessageType.emoji:
        messageList.add(message);
      default:
        break;
    }
  }

  void _resource(NetworkMessage message) {
    final self = message.id == identity;
    final step = gameStep.value;
    if (resourceMode == TurnResourceMode.frontOnly) {
      if ((step == GameStep.frontConfig && self) ||
          (step == GameStep.rearWait && !self)) {
        resourceHandler(step, message);
        gameStep.value = GameStep.action;
      }
      return;
    }
    if (resourceMode != TurnResourceMode.both) return;
    if (step == GameStep.frontConfig && self) {
      resourceHandler(step, message);
      gameStep.value = GameStep.frontWait;
    } else if (step == GameStep.frontWait && !self) {
      resourceHandler(step, message);
      gameStep.value = GameStep.action;
    } else if (step == GameStep.rearWait && !self) {
      resourceHandler(step, message);
      gameStep.value = GameStep.rearConfig;
    } else if (step == GameStep.rearConfig && self) {
      resourceHandler(step, message);
      gameStep.value = GameStep.action;
    }
  }
}
