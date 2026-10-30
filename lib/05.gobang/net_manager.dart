import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/sound/sound_manager.dart';

import '../00.common/network/client/net_turn_engine.dart';
import '../00.common/game/step.dart';
import '../00.common/model/notifiers.dart';
import '../00.common/network/protocol/network_message.dart';
import '../00.common/network/client/socket_client.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  @override
  Sound get resultSound =>
      board.lastWinner == turnEngine.playerType ? Sound.win : Sound.lose;
  late final NetTurnEngine turnEngine;
  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  NetManager({required SocketClient room}) {
    turnEngine = NetTurnEngine.forClient(room)
      ..configureGame(
        resourceMode: TurnResourceMode.none,
        actionHandler: _onAction,
        exitHandler: _onExit,
        restartHandler: restart,
      );
  }

  void _onAction(bool isSelf, NetworkMessage message) {
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    int index = data['index'] as int;
    applyBoardMove(index);
    if (board.gameOver) turnEngine.completeRound();
  }

  void resign() {
    emitSound(Sound.lose);
    turnEngine.completeRound();
  }

  void _onExit() => turnEngine.leavePage();

  @override
  void placePiece(int index) {
    if (turnEngine.gameStep.value == GameStep.action &&
        board.currentGamer.value == turnEngine.playerType) {
      turnEngine.sendGameMessage(
        MessageType.action,
        jsonEncode({'index': index}),
      );
    }
  }

  void leavePage() => turnEngine.leavePage();
  @override
  void dispose() {
    if (disposed) return;
    turnEngine.releaseGame();
    pageNavigator.dispose();
    super.dispose();
  }
}
