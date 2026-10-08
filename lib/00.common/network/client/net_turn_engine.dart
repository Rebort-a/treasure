import 'package:flutter/foundation.dart';

import '../../game/gamer.dart';
import '../../game/step.dart';
import '../protocol/network_message.dart';
import 'game_engine.dart';
import 'room_chat_engine.dart';
import 'socket_client.dart';

enum TurnResourceMode { none, frontOnly, both }

/// 回合制引擎：房间聊天与一局对战共用连接，但各自保存聊天记录。
class NetTurnEngine extends RoomChatEngine with GameEngine {
  TurnResourceMode _resourceMode = TurnResourceMode.none;
  void Function() _searchHandler = _noSearch;
  void Function(GameStep, NetworkMessage) _resourceHandler = _noResource;
  void Function(bool, NetworkMessage) _actionHandler = _noAction;
  VoidCallback _exitHandler = _noSearch;
  TurnGamerType playerType = TurnGamerType.front;
  int _enemyId = 0;
  int get enemyId => _enemyId;
  bool _disposed = false;

  NetTurnEngine(super.client);

  static NetTurnEngine forClient(SocketClient client) {
    final engine = RoomChatEngine.forClient(client);
    if (engine is! NetTurnEngine) {
      throw StateError('Turn room is not authenticated');
    }
    return engine;
  }

  static void _noSearch() {}
  static void _noResource(GameStep step, NetworkMessage message) {}
  static void _noAction(bool isSelf, NetworkMessage message) {}

  /// 仅更新本局配置，不创建子会话或新连接。
  void configureGame({
    required TurnResourceMode resourceMode,
    void Function()? searchHandler,
    void Function(GameStep, NetworkMessage)? resourceHandler,
    required void Function(bool, NetworkMessage) actionHandler,
    required VoidCallback exitHandler,
  }) {
    prepareGame();
    _resourceMode = resourceMode;
    _searchHandler = searchHandler ?? _noSearch;
    _resourceHandler = resourceHandler ?? _noResource;
    _actionHandler = actionHandler;
    _exitHandler = exitHandler;
    _enemyId = 0;
  }

  @override
  void startFromRoom() {
    final opponent = matchedOpponentId;
    final matchGame = matchedGameId;
    if (opponent <= 0 || matchGame == null) return;
    startMatched(
      opponentId: opponent,
      role: matchInitiated ? TurnGamerType.front : TurnGamerType.rear,
      gameId: matchGame,
    );
  }

  void startMatched({
    required int opponentId,
    required TurnGamerType role,
    required String gameId,
  }) {
    if (isActive || ended.value) return;
    _enemyId = opponentId;
    playerType = role;
    gameStep.value = _resourceMode == TurnResourceMode.none
        ? GameStep.action
        : role == TurnGamerType.front
        ? GameStep.frontConfig
        : GameStep.rearWait;
    activateAfterMatch(gameId: gameId);
    if (!isActive) return;
    readyToOpen.value = true;
    if (role == TurnGamerType.front && _resourceMode != TurnResourceMode.none) {
      _searchHandler();
    }
  }

  @override
  void sendGameMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
  }) {
    if (_enemyId == 0 ||
        type == MessageType.image ||
        type == MessageType.file ||
        recipientIds != null ||
        (recipientId != null && recipientId != _enemyId)) {
      return;
    }
    super.sendGameMessage(type, content, recipientId: _enemyId);
  }

  @override
  void handleGameMessage(NetworkMessage message) {
    if (!isActive ||
        message.type == MessageType.search ||
        message.type == MessageType.match ||
        !message.isPrivateMessage ||
        // ACK 重发可能晚于下一局开始；同一对手的旧包不得进入新局。
        message.gameId != gameId ||
        (message.id != identity && message.id != _enemyId) ||
        (message.recipientId != identity && message.recipientId != _enemyId)) {
      return;
    }
    if (message.type == MessageType.exit && message.id == _enemyId) {
      _exitHandler();
      finishGame();
      return;
    }
    switch (message.type) {
      case MessageType.resource:
        _resource(message);
      case MessageType.action:
        if (gameStep.value == GameStep.action) {
          _actionHandler(message.id == identity, message);
        }
      case MessageType.text:
        gameMessageList.add(message);
      default:
        break;
    }
  }

  @override
  void memberLeft(int memberId) {
    if (memberId != _enemyId) return;
    finishGame(sendExit: false);
    _exitHandler();
  }

  void _resource(NetworkMessage message) {
    final self = message.id == identity;
    final step = gameStep.value;
    if (_resourceMode == TurnResourceMode.frontOnly) {
      if ((step == GameStep.frontConfig && self) ||
          (step == GameStep.rearWait && !self)) {
        _resourceHandler(step, message);
        gameStep.value = GameStep.action;
      }
      return;
    }
    if (_resourceMode != TurnResourceMode.both) return;
    if (step == GameStep.frontConfig && self) {
      _resourceHandler(step, message);
      gameStep.value = GameStep.frontWait;
    } else if (step == GameStep.frontWait && !self) {
      _resourceHandler(step, message);
      gameStep.value = GameStep.action;
    } else if (step == GameStep.rearWait && !self) {
      _resourceHandler(step, message);
      gameStep.value = GameStep.rearConfig;
    } else if (step == GameStep.rearConfig && self) {
      _resourceHandler(step, message);
      gameStep.value = GameStep.action;
    }
  }

  @override
  void releaseGame() {
    super.releaseGame();
    _enemyId = 0;
    _searchHandler = _noSearch;
    _resourceHandler = _noResource;
    _actionHandler = _noAction;
    _exitHandler = _noSearch;
  }

  @override
  void onMatchAborted() => finishGame();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disposeGameEngine();
    super.dispose();
  }
}
