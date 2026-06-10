import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/step.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import 'base.dart';
import 'foundation_manager.dart';

class GoNetManager extends GoFoundationalManager {
  late final NetTurnGameEngine netTurnEngine;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  StoneState get localPlayer => netTurnEngine.playerType == TurnGamerType.front
      ? StoneState.black
      : StoneState.white;

  GoNetManager({required String userName, required RoomInfo roomInfo}) {
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
    if (data['type'] == 'place') {
      board.placeStone(data['index'] as int);
    } else if (data['type'] == 'resign') {
      board.resign();
    }
  }

  void _onExit() {}

  @override
  void placePiece(int index) {
    if (!board.gameOver && board.currentPlayer.value == localPlayer) {
      netTurnEngine.sendNetworkMessage(
        MessageType.action,
        jsonEncode({'type': 'place', 'index': index}),
      );
    }
  }

  @override
  void resign() {
    if (!board.gameOver) {
      netTurnEngine.sendNetworkMessage(
        MessageType.action,
        jsonEncode({'type': 'resign'}),
      );
      board.resign();
    }
  }

  void leavePage() => netTurnEngine.leavePage();
}
