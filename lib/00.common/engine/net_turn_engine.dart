import 'package:flutter/material.dart';

import 'network_engine.dart';
import '../network/network_message.dart';
import '../game/gamer.dart';
import '../game/step.dart';

class NetTurnGameEngine extends NetworkEngine {
  final ValueNotifier<GameStep> gameStep = ValueNotifier(GameStep.disconnect);

  late TurnGamerType playerType;
  int _enemyId = 0;

  final void Function() searchHandler;
  final void Function(GameStep, NetworkMessage) resourceHandler;
  final void Function(bool, NetworkMessage) actionHandler;
  final void Function() exitHandler;

  NetTurnGameEngine({
    required super.userName,
    required super.roomInfo,
    required super.navigatorHandler,
    required this.searchHandler,
    required this.resourceHandler,
    required this.actionHandler,
    required this.exitHandler,
  }) {
    // 在构造函数体中设置messageHandler
    super.messageHandler = _handleMessage;

    // 重连后重置游戏状态，使 accept 处理器能重新触发
    super.onReconnected = () {
      gameStep.value = GameStep.disconnect;
      _enemyId = 0;
    };
  }

  void _handleMessage(NetworkMessage message) {
    switch (message.type) {
      case MessageType.accept:
        _handleAcceptMessage(message);
        break;
      case MessageType.search:
        _handleSearchMessage(message);
        break;
      case MessageType.match:
        _handleMatchMessage(message);
        break;
      case MessageType.resource:
        _handleResourceMessage(message);
        break;
      case MessageType.action:
        _handleActionMessage(message);
        break;
      case MessageType.exit:
        _handleExitMessage(message);
        break;
      default:
        break;
    }
  }

  void _handleAcceptMessage(NetworkMessage message) {
    // 先手和后手都会处理
    // 获取服务器连接消息后，更新游戏阶段到connected，同时查找对手
    if (gameStep.value == GameStep.disconnect) {
      gameStep.value = GameStep.connected;
      sendNetworkMessage(MessageType.search, 'Searching for opponent');
    }
  }

  void _handleSearchMessage(NetworkMessage message) {
    // 只有先手才能获得非自身发出的SearchMessage
    // 如果在连接状态下，收到他人查找对手的消息，那么直接匹配到对手，确定自身为先手，更新游戏状态到先手配置阶段，同时向对手发送匹配成功的信息
    if (gameStep.value == GameStep.connected && message.id != identity) {
      _enemyId = message.id;
      sendNetworkMessage(MessageType.match, 'Match to opponent');
      playerType = TurnGamerType.front;
      gameStep.value = GameStep.frontConfig;
      // 然后有两种选择，要么界面上根据游戏阶段，出现配置按钮，点击后生成游戏资源，要么直接生成游戏资源，并通过网络发送
      searchHandler();
    }
  }

  void _handleMatchMessage(NetworkMessage message) {
    // 只有后手才会收到非自身发出的MatchMessage
    // 如果在连接状态下，收到对手匹配成功的消息，那么直接匹配到对手，确认自己为后手，进入后手等待先手配置阶段
    if (gameStep.value == GameStep.connected && message.id != identity) {
      _enemyId = message.id;
      playerType = TurnGamerType.rear;
      gameStep.value = GameStep.rearWait;
    }
  }

  void _handleResourceMessage(NetworkMessage message) {
    // 匹配到对手后进入，交换资源阶段，不是所有游戏都需要先后手都生成资源并交互
    // 正常顺序为，先手在frontConfig->frontWait->action
    //   后手在(connected/rearWait)->rearConfig->action
    bool isSelf = message.id == identity && message.source == userName;
    bool isEnemy = message.id == _enemyId;

    // 先手
    // 1.在frontConfig收到自己的信息，更新阶段到frontWait，等待对手配置完成
    // 2.在frontWait收到对手的配置信息，更新阶段到行动阶段，轮到自己行动
    if (gameStep.value == GameStep.frontConfig && isSelf) {
      gameStep.value = GameStep.frontWait;
      resourceHandler(GameStep.frontConfig, message);
    } else if (gameStep.value == GameStep.frontWait && isEnemy) {
      gameStep.value = GameStep.action;
      resourceHandler(GameStep.frontWait, message);
    } else
    // 后手
    // 1.在connected收到对手的配置信息，匹配对手，更新阶段到rearWait，等待对手配置完成，防止之前未匹配成功
    // 2.在rearWait收到对手的配置信息，更新阶段到rearWait，等待对手配置完成
    // 3.在rearConfig收到自己的信息，更新阶段到行动阶段，轮到对方行动
    if (gameStep.value == GameStep.connected && !isSelf) {
      _enemyId = message.id;
      playerType = TurnGamerType.rear;
      gameStep.value = GameStep.rearConfig;
      resourceHandler(GameStep.connected, message);
    } else if (gameStep.value == GameStep.rearWait && isEnemy) {
      gameStep.value = GameStep.rearConfig;
      resourceHandler(GameStep.rearWait, message);
    } else if (gameStep.value == GameStep.rearConfig && isSelf) {
      gameStep.value = GameStep.action;
      resourceHandler(GameStep.rearConfig, message);
    }
  }

  void _handleActionMessage(NetworkMessage message) {
    if (gameStep.value == GameStep.action) {
      bool isSelf = message.id == identity && message.source == userName;

      bool isEnemy = message.id == _enemyId;

      if (isSelf || isEnemy) {
        // 处理敌人和自己的行动信息
        actionHandler(isSelf, message);
      }
    }
  }

  void _handleExitMessage(NetworkMessage message) {
    if (identity != 0 && _enemyId != 0) {
      bool isEnemy = message.id == _enemyId;
      if (isEnemy) {
        exitHandler();
      }
    }
  }

  void resetForRematch() {
    _enemyId = 0;
    gameStep.value = GameStep.connected;
  }
}
