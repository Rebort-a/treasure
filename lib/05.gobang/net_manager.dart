import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/game/net_turn_game_base.dart';
import '../00.common/game/step.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final NetTurnGameService _netService;

  NetTurnGameService get netService => _netService;
  NetTurnGameEngine get netTurnEngine => _netService.netTurnEngine;
  AlwaysNotifier<void Function(BuildContext)> get pageNavigator =>
      _netService.pageNavigator;

  NetManager({required String userName, required RoomInfo roomInfo}) {
    _netService = NetTurnGameService(
      userName: userName,
      roomInfo: roomInfo,
      onSearch: _onSearch,
      onResource: _onResource,
      onAction: _onAction,
      onExit: _onExit,
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
    final data = jsonDecode(message.content);
    int index = data['index'];
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

  void leavePage() => _netService.leavePage();
}
