import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/network/network_message.dart';
import '../00.common/engine/network_engine.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final NetTurnGameEngine netTurnEngine;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  NetManager({required NetworkEngine room}) {
    netTurnEngine = NetTurnGameEngine(
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
    if (board.gameOver) netTurnEngine.finish();
  }

  void resign() {
    netTurnEngine.finish();
  }

  void _onExit() => netTurnEngine.leavePage();

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
