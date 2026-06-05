import 'dart:math';

import 'package:flutter/material.dart';
import 'package:treasure/00.common/game/gamer.dart';

import '../middle/foundation_combat_manager.dart';
import '../middle/common.dart';
import '../middle/elemental.dart';
import '../base/skill.dart';

class LocalCombatManager extends FoundationalCombatManager {
  final _random = Random();

  late final TurnGamerType playerType;

  LocalCombatManager({
    required Elemental player,
    required Elemental enemy,
    required this.playerType,
  }) {
    this.player = player;
    this.enemy = enemy;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initCombat(playerType);
      handleEnemyAction();
    });
  }

  @override
  void handlePlayerAction(ConationType action) {
    if (combatResult != ResultType.continued) {
      leavePage();
    } else {
      switch (action) {
        case ConationType.attack:
          handleAttack(true);
          break;
        case ConationType.parry:
          handlePlayerSkillTarget(-1);
          break;
        case ConationType.skill:
          showSkillSelection();
          break;
        case ConationType.escape:
          handleEscape(true);
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
      handleSkill(
        true,
        GameAction(
          actionIndex: actionIndex,
          targetIndex: elemental.current.index,
        ),
      );
    } else {
      showEnergySelection(
        elemental,
        (i) => handleSkill(
          true,
          GameAction(actionIndex: actionIndex, targetIndex: i.index),
        ),
      );
    }
  }

  ConationType _getEnemyAction() {
    int randVal = _random.nextInt(128);
    if (randVal < 1) return ConationType.escape;
    if (randVal < 16) return ConationType.parry;
    if (randVal < 32) return ConationType.skill;
    return ConationType.attack;
  }

  @override
  void handleEnemyAction() {
    if (currentGamer.value != playerType) {
      ConationType action = _getEnemyAction();

      switch (action) {
        case ConationType.attack:
          handleAttack(false);
          break;
        case ConationType.parry:
          handleSkill(
            false,
            GameAction(
              actionIndex: ConationType.parry.index,
              targetIndex: enemy.current.index,
            ),
          );
          break;
        case ConationType.skill:
          handleSkill(
            false,
            GameAction(
              actionIndex: ConationType.skill.index + 1,
              targetIndex: enemy.current.index,
            ),
          );
          break;
        case ConationType.escape:
          handleEscape(false);
          break;
      }
    }
  }
}
