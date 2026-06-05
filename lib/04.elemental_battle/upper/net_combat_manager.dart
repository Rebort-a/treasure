import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../00.common/engine/net_turn_engine.dart';
import '../../00.common/game/step.dart';
import '../../00.common/network/network_message.dart';
import '../../00.common/network/network_room.dart';
import '../../l10n/strings.dart';

import '../middle/foundation_combat_manager.dart';
import '../middle/elemental.dart';
import '../base/energy.dart';

import '../middle/common.dart';
import '../base/skill.dart';

import '../upper/cast_page.dart';
import '../upper/status_page.dart';

class NetCombatManager extends FoundationalCombatManager {
  late final NetTurnGameEngine netTurnEngine;

  NetCombatManager({required String userName, required RoomInfo roomInfo}) {
    // 使用局部函数初始化NetTurnEngine
    netTurnEngine = NetTurnGameEngine(
      userName: userName,
      roomInfo: roomInfo,
      navigatorHandler: pageNavigator,
      searchHandler: _searchHandler,
      resourceHandler: _resourceHandler,
      actionHandler: _actionHandler,
      exitHandler: _exitHandler,
    );
  }

  void _searchHandler() {
    // 由于NetCombatPage在游戏阶段更新为frontConfig时，会出现配置按钮，点击后会生成配置并发送，所以这里不需要处理
  }

  void _resourceHandler(GameStep step, NetworkMessage message) {
    final jsonData = jsonDecode(message.content);

    if (step == GameStep.frontConfig) {
      // 先手收到自己的信息，初始化player
      player = Elemental.fromJson(jsonData);
    } else if (step == GameStep.frontWait) {
      // 先手收到敌人的信息，初始化enemy，并开始战斗
      enemy = Elemental.fromJson(jsonData);
      initCombat(netTurnEngine.playerType);
    } else if (step == GameStep.connected || step == GameStep.rearWait) {
      // 后手收到敌人的信息，初始化enemy
      enemy = Elemental.fromJson(jsonData);
    } else if (step == GameStep.rearConfig) {
      // 后手收到自己的信息，初始化player，并开始战斗
      player = Elemental.fromJson(jsonData);
      initCombat(netTurnEngine.playerType);
    }
  }

  // 定义动作处理局部函数
  void _actionHandler(bool isSelf, NetworkMessage message) {
    final action = GameAction.fromJson(jsonDecode(message.content));
    final actionType = _getActionType(action.actionIndex);

    if (isSelf && (netTurnEngine.playerType != currentGamer.value)) {
      return addCombatInfo(S.serverNotYourTurn);
    }

    final actionHandlers = {
      ConationType.attack: () => handleAttack(isSelf),
      ConationType.escape: () => handleEscape(isSelf),
      ConationType.parry: () => handleSkill(isSelf, action),
      ConationType.skill: () => handleSkill(isSelf, action),
    };

    actionHandlers[actionType]?.call();
  }

  void _exitHandler() {}

  @override
  void handleEnemyAction() {}

  void navigateToCastPage() {
    pageNavigator.value = (context) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              maintainState: true,
              builder: (_) => const CastPage(totalPoints: 30),
            ),
          )
          .then((value) {
            if (value != null && value is EnergyConfigs) {
              _sendRoleConfig(value);
            }
          });
    };
  }

  void _sendRoleConfig(EnergyConfigs configs) {
    netTurnEngine.sendNetworkMessage(
      MessageType.resource,
      Elemental.configToJsonString(
        netTurnEngine.userName,
        configs,
        Random().nextInt(EnergyType.values.length),
      ),
    );
  }

  void navigateToStatePage() {
    pageNavigator.value = (BuildContext context) {
      Navigator.of(context).push(
        MaterialPageRoute(
          maintainState: true,
          builder: (_) => StatusPage(elemental: enemy),
        ),
      );
    };
  }

  @override
  void handlePlayerAction(ConationType action) {
    if (combatResult != ResultType.continued) {
      leavePage();
    } else {
      switch (action) {
        case ConationType.attack:
          _sendActionMessage(ConationType.attack.index, enemy.current.index);
          break;
        case ConationType.parry:
          handlePlayerSkillTarget(-1);
          break;
        case ConationType.skill:
          showSkillSelection();
          break;
        case ConationType.escape:
          leavePage();
          break;
      }
    }
  }

  @override
  void handlePlayerSkillTarget(int skillIndex) {
    final actionIndex = ConationType.skill.index + skillIndex;
    final skills = player.getAppointSkills(player.current);
    final skill = skillIndex == -1
        ? SkillCollection.baseParry
        : skills[skillIndex];

    bool isSelf = getSkillCategory(skill);
    bool isFront = getSkillRange(skill);

    final elemental = isSelf ? player : enemy;

    if (isFront) {
      _sendActionMessage(actionIndex, elemental.current.index);
    } else {
      showEnergySelection(
        elemental,
        (i) => _sendActionMessage(actionIndex, i.index),
      );
    }
  }

  void _sendActionMessage(int actionIndex, int targetIndex) {
    if ((netTurnEngine.playerType == currentGamer.value) ||
        (actionIndex == ConationType.escape.index)) {
      netTurnEngine.sendNetworkMessage(
        MessageType.action,
        jsonEncode(
          GameAction(actionIndex: actionIndex, targetIndex: targetIndex),
        ),
      );
    } else {
      addCombatInfo('\n${S.notYourTurn}!\n');
    }
  }

  ConationType _getActionType(int index) {
    return index < ConationType.values.length
        ? ConationType.values[index]
        : ConationType.skill;
  }

  @override
  void leavePage() {
    netTurnEngine.leavePage();
  }
}
