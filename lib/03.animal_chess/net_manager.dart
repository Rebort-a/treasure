import 'dart:convert';

import 'package:treasure/00.common/widget/dialog/template_dialog.dart';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/step.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';

import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final NetTurnGameEngine netTurnEngine;

  NetManager({required String userName, required RoomInfo roomInfo}) {
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
    initGame();
    netTurnEngine.sendNetworkMessage(MessageType.resource, _mapToString());
  }

  void _onResource(GameStep step, NetworkMessage message) {
    if (step == GameStep.connected || step == GameStep.rearWait) {
      _stringToMap(message.content);
      resetGameState();
      netTurnEngine.sendNetworkMessage(MessageType.resource, "ok");
    }
  }

  void _onAction(bool isSelf, NetworkMessage message) {
    if (netTurnEngine.gameStep.value == GameStep.action) {
      int index = jsonDecode(message.content)['index'] as int;
      if (index >= 0 && index < displayMap.length) {
        if (currentGamer.value == netTurnEngine.playerType && isSelf) {
          selectGrid(index);
        } else if (!isSelf) {
          selectGrid(index);
        }
      }
    }
  }

  void _onExit() {}

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

  void requestSelectGrid(int index) {
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

  @override
  void showChessResult(TurnGamerType winner) {
    netTurnEngine.gameStep.value = GameStep.gameOver;
    pageNavigator.value = (context) {
      DialogTemplate.promptDialog(
        context: context,
        title: S.gameOver,
        content: winner == TurnGamerType.front ? S.redWin() : S.blueWin(),
        before: () => true,
        after: () {
          netTurnEngine.leavePage();
        },
      );
    };
  }

  void leavePage() => netTurnEngine.leavePage();
}
