import '../../game/gamer.dart';
import '../../game/step.dart';
import '../network_message.dart';
import 'game_session.dart';

enum TurnResourceMode { none, frontOnly, both }

class TurnGameSession extends GameSession {
  final TurnResourceMode resourceMode;
  final void Function() searchHandler;
  final void Function(GameStep, NetworkMessage) resourceHandler;
  final void Function(bool, NetworkMessage) actionHandler;
  final void Function() exitHandler;
  late TurnGamerType playerType;
  int _enemyId = 0;
  int get enemyId => _enemyId;

  TurnGameSession({
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
  void startFromRoom() {
    final opponent = room.matchedOpponentId;
    if (opponent <= 0) return;
    startMatched(
      opponentId: opponent,
      role: room.matchInitiated ? TurnGamerType.front : TurnGamerType.rear,
    );
  }

  /// 匹配协议已在聊天室完成，游戏引擎只接管已确认的对手和对局。
  void startMatched({required int opponentId, required TurnGamerType role}) {
    if (isActive || ended.value) return;
    _enemyId = opponentId;
    playerType = role;
    gameStep.value = resourceMode == TurnResourceMode.none
        ? GameStep.action
        : role == TurnGamerType.front
        ? GameStep.frontConfig
        : GameStep.rearWait;
    super.activateAfterMatch();
    if (!isActive) return;
    readyToOpen.value = true;
    if (role == TurnGamerType.front && resourceMode != TurnResourceMode.none) {
      searchHandler();
    }
  }

  @override
  void sendNetworkMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
  }) {
    if (_enemyId == 0) return;
    if (type == MessageType.image || type == MessageType.file) return;
    if (recipientIds != null ||
        (recipientId != null && recipientId != _enemyId)) {
      return;
    }
    super.sendNetworkMessage(type, content, recipientId: _enemyId);
  }

  @override
  void handleMessage(NetworkMessage message) {
    if (!isActive) return;
    if (message.type == MessageType.search ||
        message.type == MessageType.match) {
      return;
    }
    if (!message.isPrivateMessage ||
        (message.id != identity && message.id != _enemyId) ||
        (message.recipientId != identity && message.recipientId != _enemyId)) {
      return;
    }
    if (message.type == MessageType.gameExit && message.id == _enemyId) {
      exitHandler();
      // 对手离开仅结束本次对局，不关闭房间连接。
      finish();
      return;
    }
    switch (message.type) {
      case MessageType.resource:
        _resource(message);
      case MessageType.action:
        if (gameStep.value == GameStep.action) {
          actionHandler(message.id == identity, message);
        }
      case MessageType.text:
        messageList.add(message);
      default:
        break;
    }
  }

  @override
  void memberLeft(int memberId) {
    if (memberId != _enemyId) return;
    finish(sendExit: false);
    exitHandler();
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
