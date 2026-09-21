import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../00.common/engine/net_real_engine.dart';
import '../00.common/game/step.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import 'base.dart';
import 'foundation_manager.dart';

enum SnakeAction { joystick, speedButton }

/// 联机模式不区分碰撞权威方，所有端加载同一资源并执行相同模拟。
///
/// 玩家输入只发送到服务器，收到服务器回环后才应用；新玩家加入时所有端
/// 重新执行一次资源同步。
class NetManager extends FoundationalManager {
  static const int generateCount = 10;

  late final NetRealGameEngine engine;

  final Set<int> _pendingSyncIds = {};
  int _syncId = 0;

  NetManager({required String userName, required RoomInfo roomInfo}) {
    engine = NetRealGameEngine(
      userName: userName,
      roomInfo: roomInfo,
      navigatorHandler: pageNavigator,
      searchHandler: _handleSearch,
      resourceHandler: _handleResource,
      syncHandler: _handleSync,
      actionHandler: _handleAction,
      exitHandler: _handleEnd,
    );
    initTicker();
  }

  @override
  int get identity => engine.identity;

  void _handleSearch(int id) {
    if (!snakes.containsKey(identity)) {
      addSnake(identity, FoundationalManager.initialLength);
    }
    if (!snakes.containsKey(id)) {
      addSnake(id, snakes[identity]!.length ~/ 2);
    }
    for (var i = 0; i < generateCount; i++) {
      addFood(randomSafePosition);
    }

    _syncId++;
    engine.sendNetworkMessage(
      MessageType.resource,
      json.encode({'syncId': _syncId, 'state': _toJson()}),
    );
  }

  void _handleResource(NetworkMessage message) {
    try {
      final envelope = json.decode(message.content) as Map<String, dynamic>;
      final incomingSyncId = (envelope['syncId'] as num?)?.toInt() ?? 0;
      if (incomingSyncId < _syncId) return;
      final state = envelope['state'];
      if (state is! Map<String, dynamic>) return;

      suspendGame();
      _syncId = incomingSyncId;
      _fromJson(state);
      _pendingSyncIds
        ..clear()
        ..addAll(snakes.keys);
      engine.sendNetworkMessage(
        MessageType.sync,
        json.encode({'syncId': _syncId}),
      );
    } on Object catch (error) {
      debugPrint('[Snake] ignored invalid resource: $error');
    }
  }

  Map<String, dynamic> _toJson() => {
    'snakes': snakes.map((key, value) {
      return MapEntry(key.toString(), value.toJson());
    }),
    'foods': foodGrid.toJson(),
  };

  void _fromJson(Map<String, dynamic> json) {
    final rawSnakes = json['snakes'];
    final rawFoods = json['foods'];
    if (rawSnakes is! Map<String, dynamic> ||
        rawFoods is! Map<String, dynamic>) {
      throw const FormatException('invalid snake resource');
    }

    snakes.clear();
    rawSnakes.forEach((key, value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('invalid snake entry');
      }
      snakes[int.parse(key)] = Snake.fromJson(value);
    });

    foodGrid
      ..clear()
      ..fromJson(rawFoods);
  }

  void _handleSync(NetworkMessage message) {
    try {
      final content = json.decode(message.content) as Map<String, dynamic>;
      final syncId = (content['syncId'] as num?)?.toInt() ?? -1;
      if (syncId != _syncId) return;
      if (!_pendingSyncIds.remove(message.id)) return;
      _resumeWhenSynchronized();
    } on Object catch (error) {
      debugPrint('[Snake] ignored invalid sync: $error');
    }
  }

  void _resumeWhenSynchronized() {
    if (_pendingSyncIds.isNotEmpty) return;
    engine.gameStep.value = GameStep.action;
    resumeGame();
  }

  void _handleAction(NetworkMessage message) {
    try {
      final content = json.decode(message.content) as Map<String, dynamic>;
      final actionSyncId = (content['syncId'] as num?)?.toInt() ?? 0;
      if (actionSyncId != _syncId) return;

      final rawAction = content['actionType'];
      if (rawAction is! String) return;
      final action = SnakeAction.values.asNameMap()[rawAction];
      final snake = snakes[message.id];
      if (action == null || snake == null) return;

      switch (action) {
        case SnakeAction.joystick:
          final rawAngle = content['angle'];
          if (rawAngle is! num || !rawAngle.isFinite) return;
          snake.updateAngle(rawAngle.toDouble());
          break;
        case SnakeAction.speedButton:
          final isFaster = content['isFaster'];
          if (isFaster is! bool) return;
          snake.updateSpeed(isFaster);
          break;
      }
    } on Object catch (error) {
      debugPrint('[Snake] ignored invalid action: $error');
    }
  }

  void _handleEnd(int id) {
    snakes.remove(id);
    if (_pendingSyncIds.remove(id)) _resumeWhenSynchronized();
  }

  @override
  void updatePlayerAngle(double angle) {
    _sendAction(SnakeAction.joystick, {'angle': angle});
  }

  @override
  void updatePlayerSpeed(bool isFaster) {
    _sendAction(SnakeAction.speedButton, {'isFaster': isFaster});
  }

  void _sendAction(
    SnakeAction action, [
    Map<String, dynamic> payload = const {},
  ]) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': action.name, 'syncId': _syncId, ...payload}),
    );
  }

  @override
  void handleTickerCallback(double deltaTime) {}

  @override
  void handleRemoveSnakeCallback(int index) {}

  @override
  void handleGameOverCallback() {
    engine.closeSocket();
  }

  @override
  void leavePage() {
    engine.leavePage();
  }

  @override
  void dispose() {
    engine.closeSocket();
    super.dispose();
  }
}
