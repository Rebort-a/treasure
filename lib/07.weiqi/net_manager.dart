import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/network/client/turn_game_session.dart';
import '../00.common/game/gamer.dart';
import '../00.common/model/notifiers.dart';
import '../00.common/network/protocol/network_message.dart';
import '../00.common/network/client/network_engine.dart';
import '../00.common/network/client/net_turn_engine.dart';
import 'base.dart';
import 'foundation_manager.dart';

class GoNetManager extends GoFoundationalManager {
  late final TurnGameSession turnSession;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  StoneState get localPlayer => turnSession.playerType == TurnGamerType.front
      ? StoneState.black
      : StoneState.white;

  GoNetManager({required NetworkEngine room}) {
    turnSession = createTurnSession(
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
    if (board.gameOver) turnSession.finish();
  }

  void _onExit() => turnSession.leavePage();

  @override
  void placePiece(int index) {
    if (!board.gameOver && board.currentPlayer.value == localPlayer) {
      turnSession.sendNetworkMessage(
        MessageType.action,
        jsonEncode({'type': 'place', 'index': index}),
      );
    }
  }

  @override
  void resign() {
    turnSession.finish();
  }

  void leavePage() => turnSession.leavePage();
  void dispose() {
    turnSession.dispose();
    pageNavigator.dispose();
  }
}
