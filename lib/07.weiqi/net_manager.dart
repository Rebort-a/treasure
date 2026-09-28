import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/game/gamer.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/network/network_message.dart';
import '../00.common/engine/network_engine.dart';
import 'base.dart';
import 'foundation_manager.dart';

class GoNetManager extends GoFoundationalManager {
  late final NetTurnGameEngine netTurnEngine;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  StoneState get localPlayer => netTurnEngine.playerType == TurnGamerType.front
      ? StoneState.black
      : StoneState.white;

  GoNetManager({required NetworkEngine room}) {
    netTurnEngine = NetTurnGameEngine(
      room: room,
      resourceMode: TurnResourceMode.none,
      actionHandler: _onAction,
      exitHandler: _onExit,
    );
  }

  void _onAction(bool isSelf, NetworkMessage message) {
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    if (data['type'] == 'place') {
      board.placeStone(data['index'] as int);
    }
    if (board.gameOver) netTurnEngine.finish();
  }

  void _onExit() => netTurnEngine.leavePage();

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
    netTurnEngine.finish();
  }

  void leavePage() => netTurnEngine.leavePage();
}
