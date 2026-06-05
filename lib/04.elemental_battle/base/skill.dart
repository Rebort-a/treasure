import 'effect.dart';
import '../../l10n/strings.dart';

enum SkillID {
  // 基础技
  parry,

  // 被动技
  metalPassive_0,
  waterPassive_0,
  woodPassive_0,
  firePassive_0,
  earthPassive_0,

  // 主动技
  metalActive_0,
  waterActive_0,
  woodActive_0,
  fireActive_0,
  earthActive_0,

  // 进阶技
  metalAdvanced_0,
  waterAdvanced_0,
  woodAdvanced_0,
  fireAdvanced_0,
  earthAdvanced_0,

  // 辅助技
  metalAuxiliary_0,
  waterAuxiliary_0,
  woodAuxiliary_0,
  fireAuxiliary_0,
  earthAuxiliary_0,

  // 终结技
  metalFinal_0,
  waterFinal_0,
  woodFinal_0,
  fireFinal_0,
  earthFinal_0,
}

// 技能类型
enum SkillType { active, passive }

// 技能目标类型
enum SkillTarget {
  selfFront,
  selfAny,
  enemyFront,
  enemyAny;

  String get text {
    switch (this) {
      case SkillTarget.selfFront:
        return S.targetSelfFront;
      case SkillTarget.selfAny:
        return S.targetSelfAny;
      case SkillTarget.enemyFront:
        return S.targetEnemyFront;
      case SkillTarget.enemyAny:
        return S.targetEnemyAny;
    }
  }
}

// 技能
class CombatSkill {
  final SkillID id;
  final String name;
  final String description;
  final SkillType type;
  SkillTarget targetType;
  void Function(List<CombatSkill> skills, List<CombatEffect> effects) handler;
  bool learned = false;

  CombatSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.targetType,
    required this.handler,
  });

  // 实现copyWith方法
  CombatSkill copyWith({
    SkillID? id,
    String? name,
    String? description,
    SkillType? type,
    SkillTarget? targetType,
    void Function(List<CombatSkill> skills, List<CombatEffect> effects)?
    handler,
  }) {
    return CombatSkill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      targetType: targetType ?? this.targetType,
      handler: handler ?? this.handler,
    );
  }
}

class SkillCollection {
  SkillCollection._();

  // 各属性可学习技能列表
  static final List<CombatSkill> metalAvailableSkills = [
    SkillCollection.metalPassive_0,
    SkillCollection.metalActive_0,
    SkillCollection.metalAdvanced_0,
    SkillCollection.metalAuxiliary_0,
    SkillCollection.metalFinal_0,
  ];
  static final List<CombatSkill> woodAvailableSkills = [
    SkillCollection.woodPassive_0,
    SkillCollection.woodActive_0,
    SkillCollection.woodAdvanced_0,
    SkillCollection.woodAuxiliary_0,
    SkillCollection.woodFinal_0,
  ];
  static final List<CombatSkill> waterAvailableSkills = [
    SkillCollection.waterPassive_0,
    SkillCollection.waterActive_0,
    SkillCollection.waterAdvanced_0,
    SkillCollection.waterAuxiliary_0,
    SkillCollection.waterFinal_0,
  ];
  static final List<CombatSkill> fireAvailableSkills = [
    SkillCollection.firePassive_0,
    SkillCollection.fireActive_0,
    SkillCollection.fireAdvanced_0,
    SkillCollection.fireAuxiliary_0,
    SkillCollection.fireFinal_0,
  ];
  static final List<CombatSkill> earthAvailableSkills = [
    SkillCollection.earthPassive_0,
    SkillCollection.earthActive_0,
    SkillCollection.earthAdvanced_0,
    SkillCollection.earthAuxiliary_0,
    SkillCollection.earthFinal_0,
  ];

  // 总的技能列表，包含所有被动和主动技能
  static final List<List<CombatSkill>> totalSkills = [
    SkillCollection.metalAvailableSkills,
    SkillCollection.woodAvailableSkills,
    SkillCollection.waterAvailableSkills,
    SkillCollection.fireAvailableSkills,
    SkillCollection.earthAvailableSkills,
  ];

  // 示例技能

  static final CombatSkill baseParry = CombatSkill(
    id: SkillID.parry,
    name: S.skParry,
    description: S.skParryDesc,
    type: SkillType.active,
    targetType: SkillTarget.selfAny,
    handler: (skills, effects) {
      effects[EffectID.parryState.index].value = 0.75;
      effects[EffectID.parryState.index].times += 1;
    },
  );

  static final CombatSkill metalPassive_0 = CombatSkill(
    id: SkillID.metalPassive_0,
    name: S.skMetalP0,
    description: S.skMetalP0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.strengthen.index].type = EffectType.infinite;
      effects[EffectID.strengthen.index].value = 0.5;
    },
  );

  static final CombatSkill woodPassive_0 = CombatSkill(
    id: SkillID.woodPassive_0,
    name: S.skWoodP0,
    description: S.skWoodP0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.absorbBlood.index].type = EffectType.infinite;
      effects[EffectID.absorbBlood.index].value = 0.25;
    },
  );

  static final CombatSkill waterPassive_0 = CombatSkill(
    id: SkillID.waterPassive_0,
    name: S.skWaterP0,
    description: S.skWaterP0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.adjustAttribute.index].type = EffectType.infinite;
      effects[EffectID.adjustAttribute.index].value = 0.75;
    },
  );

  static final CombatSkill firePassive_0 = CombatSkill(
    id: SkillID.firePassive_0,
    name: S.skFireP0,
    description: S.skFireP0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.enchanting.index].type = EffectType.infinite;
      effects[EffectID.enchanting.index].value = 1.0;
    },
  );

  static final CombatSkill earthPassive_0 = CombatSkill(
    id: SkillID.earthPassive_0,
    name: S.skEarthP0,
    description: S.skEarthP0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.accumulateAnger.index].type = EffectType.infinite;
      effects[EffectID.accumulateAnger.index].value = 0.5;
    },
  );

  static final CombatSkill metalActive_0 = CombatSkill(
    id: SkillID.metalActive_0,
    name: S.skMetalA0,
    description: S.skMetalA0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.multipleHit.index].value = 1;
      effects[EffectID.multipleHit.index].times += 1;
    },
  );

  static final CombatSkill woodActive_0 = CombatSkill(
    id: SkillID.woodActive_0,
    name: S.skWoodA0,
    description: S.skWoodA0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.restoreLife.index].value = 0.125;
      effects[EffectID.restoreLife.index].times += 1;
    },
  );

  static final CombatSkill waterActive_0 = CombatSkill(
    id: SkillID.waterActive_0,
    name: S.skWaterA0,
    description: S.skWaterA0Desc,
    type: SkillType.active,
    targetType: SkillTarget.enemyFront,
    handler: (skills, effects) {
      effects[EffectID.weakenAttack.index].value = 0.5;
      effects[EffectID.weakenAttack.index].times += 2;
    },
  );

  static final CombatSkill fireActive_0 = CombatSkill(
    id: SkillID.fireActive_0,
    name: S.skFireA0,
    description: S.skFireA0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.sacrificing.index].value = 1;
      effects[EffectID.sacrificing.index].times += 1;
    },
  );

  static final CombatSkill earthActive_0 = CombatSkill(
    id: SkillID.earthActive_0,
    name: S.skEarthA0,
    description: S.skEarthA0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.revengeAtonce.index].value = 1;
      effects[EffectID.revengeAtonce.index].times += 1;
    },
  );

  static final CombatSkill metalAdvanced_0 = CombatSkill(
    id: SkillID.metalAdvanced_0,
    name: S.skMetalAdv0,
    description: S.skMetalAdv0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      skills[1].targetType = SkillTarget.selfAny;
    },
  );

  static final CombatSkill woodAdvanced_0 = CombatSkill(
    id: SkillID.woodAdvanced_0,
    name: S.skWoodAdv0,
    description: S.skWoodAdv0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      skills[1].targetType = SkillTarget.selfAny;
    },
  );

  static final CombatSkill waterAdvanced_0 = CombatSkill(
    id: SkillID.waterAdvanced_0,
    name: S.skWaterAdv0,
    description: S.skWaterAdv0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      skills[1].targetType = SkillTarget.enemyAny;
    },
  );

  static final CombatSkill fireAdvanced_0 = CombatSkill(
    id: SkillID.fireAdvanced_0,
    name: S.skFireAdv0,
    description: S.skFireAdv0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      skills[1].targetType = SkillTarget.selfAny;
    },
  );

  static final CombatSkill earthAdvanced_0 = CombatSkill(
    id: SkillID.earthAdvanced_0,
    name: S.skEarthAdv0,
    description: S.skEarthAdv0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      skills[1].targetType = SkillTarget.selfAny;
    },
  );

  static final CombatSkill metalAuxiliary_0 = CombatSkill(
    id: SkillID.metalAuxiliary_0,
    name: S.skMetalAux0,
    description: S.skMetalAux0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfAny,
    handler: (skills, effects) {
      effects[EffectID.strengthen.index].value = 0.5;
      effects[EffectID.strengthen.index].times += 2;
    },
  );

  static final CombatSkill woodAuxiliary_0 = CombatSkill(
    id: SkillID.woodAuxiliary_0,
    name: S.skWoodAux0,
    description: S.skWoodAux0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfAny,
    handler: (skills, effects) {
      effects[EffectID.absorbBlood.index].value = 0.25;
      effects[EffectID.absorbBlood.index].times += 2;
    },
  );

  static final CombatSkill waterAuxiliary_0 = CombatSkill(
    id: SkillID.waterAuxiliary_0,
    name: S.skWaterAux0,
    description: S.skWaterAux0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfAny,
    handler: (skills, effects) {
      effects[EffectID.adjustAttribute.index].value = 0.75;
      effects[EffectID.adjustAttribute.index].times += 2;
    },
  );

  static final CombatSkill fireAuxiliary_0 = CombatSkill(
    id: SkillID.fireAuxiliary_0,
    name: S.skFireAux0,
    description: S.skFireAux0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfAny,
    handler: (skills, effects) {
      effects[EffectID.enchanting.index].value = 1.0;
      effects[EffectID.enchanting.index].times += 2;
    },
  );

  static final CombatSkill earthAuxiliary_0 = CombatSkill(
    id: SkillID.earthAuxiliary_0,
    name: S.skEarthAux0,
    description: S.skEarthAux0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfAny,
    handler: (skills, effects) {
      effects[EffectID.accumulateAnger.index].value = 0.5;
      effects[EffectID.accumulateAnger.index].times += 2;
    },
  );

  static final CombatSkill metalFinal_0 = CombatSkill(
    id: SkillID.metalFinal_0,
    name: S.skMetalF0,
    description: S.skMetalF0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.giantKiller.index].value = 0.25;
      effects[EffectID.giantKiller.index].times += 1;
    },
  );

  static final CombatSkill woodFinal_0 = CombatSkill(
    id: SkillID.woodFinal_0,
    name: S.skWoodF0,
    description: S.skWoodF0Desc,
    type: SkillType.passive,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.increaseCapacity.index].type = EffectType.infinite;
      effects[EffectID.increaseCapacity.index].value = 1;
    },
  );

  static final CombatSkill waterFinal_0 = CombatSkill(
    id: SkillID.waterFinal_0,
    name: S.skWaterF0,
    description: S.skWaterF0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.exemptionDeath.index].value = 1;
      effects[EffectID.exemptionDeath.index].times += 1;
    },
  );

  static final CombatSkill fireFinal_0 = CombatSkill(
    id: SkillID.fireFinal_0,
    name: S.skFireF0,
    description: S.skFireF0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.hotDamage.index].value = 0.25;
      effects[EffectID.hotDamage.index].times += 2;
    },
  );

  static final CombatSkill earthFinal_0 = CombatSkill(
    id: SkillID.earthFinal_0,
    name: S.skEarthF0,
    description: S.skEarthF0Desc,
    type: SkillType.active,
    targetType: SkillTarget.selfFront,
    handler: (skills, effects) {
      effects[EffectID.rugged.index].value = 0.25;
      effects[EffectID.rugged.index].times += 2;
    },
  );
}
