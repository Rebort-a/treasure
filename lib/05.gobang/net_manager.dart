import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/network/middle/turn_game_session.dart';
import '../00.common/model/notifiers.dart';
import '../00.common/network/base/network_message.dart';
import '../00.common/network/upper/network_engine.dart';
import '../00.common/network/upper/net_turn_engine.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final TurnGameSession turnSession;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  NetManager({required NetworkEngine room}) {
    turnSession = createTurnSession(
      room: room,
      resourceMode: TurnResourceMode.none,
      actionHandler: _onAction,
      exitHandler: _onExit,
    );
  }

  void _onAction(bool isSelf, NetworkMessage message) {
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    int index = data['index'] as int;
    board.placePiece(index);
    if (board.gameOver) turnSession.finish();
  }

  void resign() {
    turnSession.finish();
  }

  void _onExit() => turnSession.leavePage();

  @override
  void placePiece(int index) {
    if (board.currentGamer.value == turnSession.playerType) {
      turnSession.sendNetworkMessage(
        MessageType.action,
        jsonEncode({'index': index}),
      );
    }
  }

  void leavePage() => turnSession.leavePage();
  void dispose() {
    turnSession.dispose();
    pageNavigator.dispose();
  }
}
