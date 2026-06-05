import 'package:flutter/material.dart';

import 'network_engine.dart';
import '../network/network_message.dart';
import '../game/step.dart';

class NetRealGameEngine extends NetworkEngine {
  final ValueNotifier<GameStep> gameStep = ValueNotifier(GameStep.disconnect);

  int _publisherId = 0;

  final void Function(int) searchHandler;
  final void Function(NetworkMessage) resourceHandler;
  final void Function(int) syncHandler;
  final void Function(NetworkMessage) actionHandler;
  final void Function(int) exitHandler;

  NetRealGameEngine({
    required super.userName,
    required super.roomInfo,
    required super.navigatorHandler,
    required this.searchHandler,
    required this.resourceHandler,
    required this.syncHandler,
    required this.actionHandler,
    required this.exitHandler,
  }) {
    super.messageHandler = _handleMessage;

    // 重连后重置游戏状态
    super.onReconnected = () {
      gameStep.value = GameStep.disconnect;
      _publisherId = 0;
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
      case MessageType.resource:
        _handleResourceMessage(message);
        break;
      case MessageType.sync:
        _handleSyncMessage(message);
        break;
      case MessageType.action:
        _handleActionMessage(message);
        break;
      case MessageType.exit:
        _handleExitMessage(message);
        break;
      case MessageType.match:
        _handleMatchMessage(message.id);
        break;
      default:
        break;
    }
  }

  void _handleAcceptMessage(NetworkMessage message) {
    if (gameStep.value == GameStep.disconnect) {
      gameStep.value = GameStep.connected;
      _publisherId = identity; // 先假定房间内没人，自己就是发布者
      sendNetworkMessage(MessageType.search, 'Searching for publisher');
    }
  }

  void _handleSearchMessage(NetworkMessage message) {
    if (message.id != identity) {
      // 收到他人的查找消息
      if (identity == _publisherId) {
        // 如果自己就是发布者，发布资源
        searchHandler(message.id);
      }
    }
  }

  void _handleResourceMessage(NetworkMessage message) {
    _handleMatchMessage(message.id);
    if (gameStep.value == GameStep.connected ||
        gameStep.value == GameStep.action) {
      resourceHandler(message);
      gameStep.value = GameStep.action;
    }
  }

  void _handleSyncMessage(NetworkMessage message) {
    _handleMatchMessage(message.id);
    syncHandler(message.id);
  }

  void _handleActionMessage(NetworkMessage message) {
    _handleMatchMessage(message.id);
    if (gameStep.value == GameStep.action) {
      actionHandler(message);
    }
  }

  void _handleExitMessage(NetworkMessage message) {
    if (message.id != identity) {
      // 只处理他人的退出消息，因为自己会直接退出
      exitHandler(message.id);
      if (message.id == _publisherId) {
        _publisherId = identity; // 发布者退出，假定自己就是发布者，然后竞选
        sendNetworkMessage(MessageType.match, 'Election publisher');
      }
    }
  }

  void _handleMatchMessage(int messageId) {
    if (messageId < _publisherId) {
      _publisherId = messageId;
    }
  }
}
