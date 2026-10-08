import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/network/client/net_turn_engine.dart';
import '../00.common/game/gamer.dart';
import '../00.common/model/notifiers.dart';
import '../00.common/network/protocol/network_message.dart';
import '../00.common/network/client/socket_client.dart';
import 'base.dart';
import 'foundation_manager.dart';

class GoNetManager extends GoFoundationalManager {
  late final NetTurnEngine turnEngine;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  StoneState get localPlayer => turnEngine.playerType == TurnGamerType.front
      ? StoneState.black
      : StoneState.white;

  GoNetManager({required SocketClient room}) {
    turnEngine = NetTurnEngine.forClient(room)
      ..configureGame(
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
    if (board.gameOver) turnEngine.finishGame();
  }

  void _onExit() => turnEngine.leavePage();

  @override
  void placePiece(int index) {
    if (!board.gameOver && board.currentPlayer.value == localPlayer) {
      turnEngine.sendGameMessage(
        MessageType.action,
        jsonEncode({'type': 'place', 'index': index}),
      );
    }
  }

  @override
  void resign() {
    turnEngine.finishGame();
  }

  void leavePage() => turnEngine.leavePage();
  void dispose() {
    turnEngine.releaseGame();
    pageNavigator.dispose();
  }
}
