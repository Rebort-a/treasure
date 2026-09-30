import 'dart:convert';

import '../00.common/network/middle/turn_game_session.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/step.dart';
import '../00.common/network/base/network_message.dart';
import '../00.common/network/upper/network_engine.dart';
import '../00.common/network/upper/net_turn_engine.dart';

import 'base.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final TurnGameSession turnSession;

  NetManager({required NetworkEngine room}) {
    turnSession = createTurnSession(
      room: room,
      resourceMode: TurnResourceMode.frontOnly,
      searchHandler: _onSearch,
      resourceHandler: _onResource,
      actionHandler: _onAction,
      exitHandler: _onExit,
    );
  }

  void _onSearch() {
    // 暂时生成棋盘并提取资源，恢复原状态；收到自己的资源回环后再正式应用。
    final previousMap = displayMap.value;
    initGame();
    final resource = _mapToString();
    displayMap.value = previousMap;
    turnSession.sendNetworkMessage(MessageType.resource, resource);
  }

  void _onResource(GameStep step, NetworkMessage message) {
    if (step == GameStep.frontConfig || step == GameStep.rearWait) {
      _stringToMap(message.content);
      resetGameState();
    }
  }

  void _onAction(bool isSelf, NetworkMessage message) {
    if (turnSession.gameStep.value == GameStep.action) {
      int index = jsonDecode(message.content)['index'] as int;
      if (index >= 0 && index < displayMap.length) {
        if (!isSelf) {
          autoProcess(index);
        } else if (currentGamer.value == turnSession.playerType) {
          autoProcess(index);
        }
      }
    }
  }

  void _onExit() {}

  void surrender() => turnSession.finish();

  @override
  void handleGameOver(TurnGamerType winner) => turnSession.finish();

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
    if ((turnSession.gameStep.value == GameStep.action &&
            currentGamer.value == turnSession.playerType) ||
        index == -1) {
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
