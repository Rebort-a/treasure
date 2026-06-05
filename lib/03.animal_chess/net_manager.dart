import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:treasure/00.common/widget/dialog/template_dialog.dart';

import '../00.common/engine/net_turn_engine.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/net_turn_game_base.dart';
import '../00.common/game/step.dart';
import '../00.common/tool/notifiers.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';

import '../l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationalManager {
  late final NetTurnGameService _netService;

  NetTurnGameService get netService => _netService;
  NetTurnGameEngine get netTurnEngine => _netService.netTurnEngine;

  /// 覆盖父类的 pageNavigator，使其指向网络服务的 pageNavigator，
  /// 确保引擎和 UI 的导航通知使用同一个实例。
  @override
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
      int index = jsonDecode(message.content)['index'];
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
    boardLevel = jsonData['boardLevel'];

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

  void sendActionMessage(int index) {
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
  void showChessResult(bool isRedWin) {
    netTurnEngine.gameStep.value = GameStep.gameOver;
    _netService.pageNavigator.value = (context) {
      DialogTemplate.promptDialog(
        context: context,
        title: S.gameOver,
        content: isRedWin ? S.redWin() : S.blueWin(),
        before: () => true,
        after: () {
          netTurnEngine.leavePage();
        },
      );
    };
  }

  @override
  void leavePage() => _netService.leavePage();
}
