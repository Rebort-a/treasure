import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/game/step.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final NetTurnGameEngine netTurnEngine;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  NetManager({required String userName, required RoomInfo roomInfo}) {
    netTurnEngine = NetTurnGameEngine(
      userName: userName,
      roomInfo: roomInfo,
      navigatorHandler: pageNavigator,
      searchHandler: _onSearch,
      resourceHandler: _onResource,
      actionHandler: _onAction,
      exitHandler: _onExit,
    );
  }

  void _onSearch() {
    netTurnEngine.sendNetworkMessage(MessageType.resource, 'ok');
  }

  void _onResource(GameStep step, NetworkMessage message) {
    if (step == GameStep.connected || step == GameStep.rearWait) {
      netTurnEngine.sendNetworkMessage(MessageType.resource, 'ok');
    } else if (step == GameStep.frontWait || step == GameStep.rearConfig) {
      board.restart();
    }
  }

  void _onAction(bool isSelf, NetworkMessage message) {
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    int index = data['index'] as int;
    board.placePiece(index);
  }

  void _onExit() {}

  @override
  void placePiece(int index) {
    if (board.currentGamer.value == netTurnEngine.playerType) {
      netTurnEngine.sendNetworkMessage(
        MessageType.action,
        jsonEncode({'index': index}),
      );
    }
  }

  void leavePage() => netTurnEngine.leavePage();
}
