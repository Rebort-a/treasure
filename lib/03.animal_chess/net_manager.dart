import 'dart:convert';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/step.dart';
import '../00.common/network/network_message.dart';
import '../00.common/engine/network_engine.dart';

import 'base.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final NetTurnGameEngine netTurnEngine;

  NetManager({required NetworkEngine room}) {
    netTurnEngine = NetTurnGameEngine(
      room: room,
      resourceMode: TurnResourceMode.frontOnly,
      searchHandler: _onSearch,
      resourceHandler: _onResource,
      actionHandler: _onAction,
      exitHandler: _onExit,
    );
  }

  void _onSearch() {
    initGame();
    netTurnEngine.sendNetworkMessage(MessageType.resource, _mapToString());
  }

  void _onResource(GameStep step, NetworkMessage message) {
    if (step == GameStep.rearWait) {
      _stringToMap(message.content);
      resetGameState();
    }
  }

  void _onAction(bool isSelf, NetworkMessage message) {
    if (netTurnEngine.gameStep.value == GameStep.action) {
      int index = jsonDecode(message.content)['index'] as int;
      if (index >= 0 && index < displayMap.length) {
        if (!isSelf) {
          autoProcess(index);
        } else if (currentGamer.value == netTurnEngine.playerType) {
          autoProcess(index);
        }
      }
    }
  }

  void _onExit() {}

  void surrender() => netTurnEngine.finish();

  @override
  void handleGameOver(TurnGamerType winner) => netTurnEngine.finish();

  String _mapToString() {
    List<List<int>> animalDistribution = displayMap.value
        .asMap()
        .entries
        .where((entry) => entry.value.value.hasAnimal)
        .map((entry) {
          final animal = entry.value.value.animal!;
          return [
            entry.key,
            animal.owner.index,
            animal.type.index,
            animal.isHidden ? 1 : 0,
          ];
        })
        .toList();

    return jsonEncode({
      'boardLevel': boardLevel,
      'animals': animalDistribution,
    });
  }

  void _stringToMap(String content) {
    final jsonData = jsonDecode(content);
    boardLevel = jsonData['boardLevel'] as int;

    setupBoard();

    final animalDistribution = jsonData['animals'] as List<dynamic>;
    for (final animalData in animalDistribution) {
      final data = animalData as List<dynamic>;
      final index = data[0] as int;
      final owner = TurnGamerType.values[data[1] as int];
      final type = AnimalType.values[data[2] as int];
      final isHidden = data[3] == 1;

      placeAnimalByIndex(
        index,
        Animal(type: type, owner: owner, isHidden: isHidden),
      );
    }
  }

  @override
  void onCellClick(int index) {
    _sendActionMessage(index);
  }

  void _sendActionMessage(int index) {
    if ((netTurnEngine.gameStep.value == GameStep.action &&
            currentGamer.value == netTurnEngine.playerType) ||
        index == -1) {
      netTurnEngine.sendNetworkMessage(
        MessageType.action,
        jsonEncode({'index': index}),
      );
    }
  }

  void leavePage() => netTurnEngine.leavePage();
}
