import 'dart:math';

import 'effect.dart';
import 'skill.dart';
import '../../l10n/strings.dart';

// 属性枚举类型
enum AttributeType {
  hp,
  atk,
  def;

  String get text {
    switch (this) {
      case AttributeType.hp:
        return "❤️";
      case AttributeType.atk:
        return "⚔️";
      case AttributeType.def:
        return "🛡️";
    }
  }
}

// 灵根：特征，体系，潜力的统称（实在找不到更合适的单词[允悲]），灵根拥有独立的属性，技能和效果

// 灵根枚举类型
enum EnergyType {
  metal,
  wood,
  water,
  fire,
  earth;

  EnergyType getPreviousType() {
    return EnergyType.values[(index + EnergyType.values.length - 1) %
        EnergyType.values.length];
  }

  EnergyType getNextType() {
    return EnergyType.values[(index + 1) % EnergyType.values.length];
  }

  EnergyType getGenerativeType() {
    switch (this) {
      case EnergyType.metal:
        return EnergyType.water;
      case EnergyType.water:
        return EnergyType.wood;
      case EnergyType.wood:
        return EnergyType.fire;
      case EnergyType.fire:
        return EnergyType.earth;
      case EnergyType.earth:
        return EnergyType.metal;
    }
  }

  String get text {
    switch (this) {
      case EnergyType.metal:
        return "🔩";
      case EnergyType.wood:
        return "🪵";
      case EnergyType.water:
        return "🌊";
      case EnergyType.fire:
        return "🔥";
      case EnergyType.earth:
        return "🪨";
    }
  }

  List<int> get baseAttributes {
    switch (this) {
      case EnergyType.metal:
        return [128, 32, 32];
      case EnergyType.wood:
        return [256, 32, 16];
      case EnergyType.water:
        return [160, 16, 64];
      case EnergyType.fire:
        return [96, 64, 16];
      case EnergyType.earth:
        return [384, 16, 0];
    }
  }
}

// 灵根类
class Energy {
  late String _name;
  late final EnergyType _type;

  int _health = 0;
  int _capacityBase = 0;
  int _capacityExtra = 0;
  int _attackBase = 0;
  int _attackOffset = 0;
  int _defenceBase = 0;
  int _defenceOffset = 0;

  late final List<CombatSkill> _skills;
  late final List<CombatEffect> _effects;

  Energy({required String name, required EnergyType type}) {
    _name = name;
    _type = type;
    _initAttributes();
    _initSkills();
    _initEffects();
  }

  // 初始化属性
  void _initAttributes() {
    _capacityBase = _type.baseAttributes[AttributeType.hp.index];
    _attackBase = _type.baseAttributes[AttributeType.atk.index];
    _defenceBase = _type.baseAttributes[AttributeType.def.index];
    restoreAttributes();
  }

  // 初始化技能
  void _initSkills() {
    _skills = SkillCollection.totalSkills[_type.index]
        .map((skill) => skill.copyWith())
        .toList();
  }

  // 初始化效果
  void _initEffects() {
    _effects = EffectID.values
        .map(
          (id) => CombatEffect(
            id: id,
            type: EffectType.limited,
            value: 0,
            times: 0,
          ),
        )
        .toList();
  }

  // 属性访问器
  String get name => _name;
  EnergyType get type => _type;
  int get health => _health;
  int get capacityBase => _capacityBase;
  int get capacityExtra => _capacityExtra;
  int get capacityTotal => capacityBase + capacityExtra;
  int get attackBase => _attackBase;
  int get attackOffset => _attackOffset;
  int get attackTotal => attackBase + attackOffset;
  int get defenceBase => _defenceBase;
  int get defenceOffset => _defenceOffset;
  int get defenceTotal => defenceBase + defenceOffset;
  List<CombatSkill> get skills => _skills;
  List<CombatEffect> get effects => _effects;

  static int get healthStep => 32;
  static int get attackStep => 8;
  static int get defenceStep => 8;

  void changeName(String newName) {
    _name = newName;
  }

  // 还原效果
  void restoreEffects() {
    for (CombatEffect effect in _effects) {
      effect.reset();
    }
  }

  // 还原属性
  void restoreAttributes() {
    _capacityExtra = 0;
    _attackOffset = 0;
    _defenceOffset = 0;
    _health = capacityTotal;
  }

  // 调整生命值，封装成内部函数，只能通过recoverHealth和deductHealth的回调调用
  int _changeHealth(int value) {
    final newHealth = (_health + value).clamp(0, capacityTotal);
    final actualChange = newHealth - _health;
    _health = newHealth;

    return actualChange;
  }

  // 回复生命
  int recoverHealth(int value) {
    if (value <= 0) return 0;
    return EnergyCombat.handleRecoverHealth(this, value, _changeHealth);
  }

  // 扣除生命
  int deductHealth(int value, bool isMagic) {
    if (value <= 0) return 0;
    return EnergyCombat.handleDeductHealth(
      this,
      value,
      isMagic,
      (v) => -_changeHealth(-v),
    );
  }

  void changeAttackOffset(int value) {
    _attackOffset += value;
  }

  void changeDefenceOffset(int value) {
    _defenceOffset += value;
  }

  void changeCapacityExtra(int value) {
    _capacityExtra = (_capacityExtra + value).clamp(0, capacityBase);
  }

  // 升级属性
  void upgradeAttributes(AttributeType attribute) {
    switch (attribute) {
      case AttributeType.hp:
        _capacityBase += healthStep;
        _changeHealth(healthStep);
        break;
      case AttributeType.atk:
        _attackBase += attackStep;
        break;
      case AttributeType.def:
        _defenceBase += defenceStep;
        break;
    }
  }

  // 学习技能
  void learnSkill(int index) {
    if (index >= 0 && index < _skills.length) {
      _skills[index].learned = true;
    }
  }

  // 遭受技能
  void sufferSkill(CombatSkill skill) {
    skill.handler(_skills, _effects);
  }

  // 施加被动技能影响
  void applyPassiveEffect() {
    for (final skill in _skills) {
      if (skill.learned && skill.type == SkillType.passive) {
        if (skill.targetType == SkillTarget.selfFront) {
          sufferSkill(skill);
        }
      }
    }
  }

  // 获取效果
  CombatEffect getEffect(EffectID id) => _effects[id.index];
}

enum CombatResult {
  attackerWin,
  defenderWin,
  undecided,
  attackerEscape,
  defenderEscape,
}

extension CombatResultExtension on CombatResult {
  CombatResult get reversed {
    switch (this) {
      case CombatResult.attackerWin:
        return CombatResult.defenderWin;
      case CombatResult.defenderWin:
        return CombatResult.attackerWin;
      case CombatResult.undecided:
        return CombatResult.undecided;
      case CombatResult.attackerEscape:
        return CombatResult.defenderEscape;
      case CombatResult.defenderEscape:
        return CombatResult.attackerEscape;
    }
  }
}

class EnergyCombat {
  final Energy source;
  final Energy target;
  String message = "";
  CombatResult result = CombatResult.undecided;

  EnergyCombat({required this.source, required this.target});

  void execute() {
    result = _handleExecute(source, target);
  }

  // 处理执行
  CombatResult _handleExecute(Energy source, Energy target) {
    //如果有即时效果，处理完退出
    if (_handleInstantEffect(source, target)) return CombatResult.undecided;

    // 如果没有，进行战斗
    return _handleCombat(source, target);
  }

  // 处理即时效果
  bool _handleInstantEffect(Energy source, Energy target) {
    CombatEffect effect = target.getEffect(EffectID.restoreLife);
    if (effect.expend()) {
      int recovery = (effect.value * source.capacityTotal).round();
      int actual = target.recoverHealth(recovery);
      message += '${S.healLog(target.name, actual, target.health)}\n';
      return true;
    }
    return false;
  }

  // 处理战斗
  CombatResult _handleCombat(Energy attacker, Energy defender) {
    int combatCount = 1 + _handleHitCount(attacker);

    for (int i = 0; i < combatCount; i++) {
      CombatResult result = _handleBattle(attacker, defender);
      if (result != CombatResult.undecided) return result;
    }
    return CombatResult.undecided;
  }

  // 处理额外攻击次数
  int _handleHitCount(Energy energy) {
    CombatEffect effect = energy.getEffect(EffectID.multipleHit);
    return effect.expend() ? effect.value.round() : 0;
  }

  // 执行一轮攻击
  CombatResult _handleBattle(Energy attacker, Energy defender) {
    int attack = handleAttackEffect(attacker, defender, true);
    int defence = handleDefenceEffect(attacker, defender, true);
    double coeff = _handleCoeffcientEffect(attacker, defender);
    double enchantRatio = _handleEnchantRatio(attacker, defender);

    double physicsAttack = attack * (1 - enchantRatio);
    double magicAttack = attack * enchantRatio;

    CombatEffect physicsAddition = attacker.getEffect(EffectID.physicsAddition);
    if (physicsAddition.expend()) {
      physicsAttack += physicsAddition.value;
      physicsAddition.value = 0;
    }

    CombatEffect magicAddition = attacker.getEffect(EffectID.magicAddition);
    if (magicAddition.expend()) {
      magicAttack += magicAddition.value;
      magicAddition.value = 0;
    }

    CombatResult result = _handleAttack(
      attacker,
      defender,
      physicsAttack,
      defence,
      coeff,
      false,
    );
    if (result != CombatResult.undecided) return result;

    return _handleAttack(attacker, defender, magicAttack, 0, coeff, true);
  }

  // 计算攻击力
  static int handleAttackEffect(Energy attacker, Energy defender, bool expend) {
    int attack = attacker.attackTotal;

    CombatEffect giantKiller = attacker.getEffect(EffectID.giantKiller);
    if (expend ? giantKiller.expend() : giantKiller.check()) {
      attack += (defender.health * giantKiller.value).round();
    }

    CombatEffect strengthen = attacker.getEffect(EffectID.strengthen);
    if (expend ? strengthen.expend() : strengthen.check()) {
      attack += (attacker.attackBase * strengthen.value).round();
    }

    CombatEffect weakenAttack = attacker.getEffect(EffectID.weakenAttack);
    if (expend ? weakenAttack.expend() : weakenAttack.check()) {
      attack -= (attack * weakenAttack.value).round();
    }

    return attack;
  }

  // 计算防御力
  static int handleDefenceEffect(
    Energy attacker,
    Energy defender,
    bool expend,
  ) {
    int defence = defender.defenceTotal;

    CombatEffect strengthen = defender.getEffect(EffectID.strengthen);
    if (expend ? strengthen.expend() : strengthen.check()) {
      defence += (defender.defenceBase * strengthen.value).round();
    }

    CombatEffect weakenDefence = defender.getEffect(EffectID.weakenDefence);
    if (expend ? weakenDefence.expend() : weakenDefence.check()) {
      defence -= (defence * weakenDefence.value).round();
    }

    return defence;
  }

  // 计算伤害系数
  double _handleCoeffcientEffect(Energy attacker, Energy defender) {
    double coeff = 1.0;

    CombatEffect sacrificing = attacker.getEffect(EffectID.sacrificing);
    if (sacrificing.expend()) {
      int deduction = attacker.health - sacrificing.value.round();
      double increaseCoeff = deduction / attacker.capacityBase;
      coeff *= (1 + increaseCoeff);
      attacker.deductHealth(deduction, true);
      message +=
          '${S.selfDamageLog(attacker.name, deduction)} ${(increaseCoeff * 100).toStringAsFixed(0)}%\n';
    }

    CombatEffect coefficient = attacker.getEffect(EffectID.coeffcient);
    if (coefficient.expend()) {
      coeff *= (1 + coefficient.value);
    }

    CombatEffect parry = defender.getEffect(EffectID.parryState);
    if (parry.expend()) {
      coeff *= (1 - parry.value);
    }

    return coeff;
  }

  // 获取附魔比例
  double _handleEnchantRatio(Energy attacker, Energy defender) {
    double ratio = 0.0;
    CombatEffect enchanting = attacker.getEffect(EffectID.enchanting);
    if (enchanting.expend()) {
      ratio += enchanting.value.clamp(0.0, 1.0);
      if (!enchanting.check()) {
        enchanting.value = 0;
      }
    }

    return ratio;
  }

  // 处理攻击
  CombatResult _handleAttack(
    Energy attacker,
    Energy defender,
    double attack,
    int defence,
    double coeff,
    bool isMagic,
  ) {
    if (attack <= 0) return CombatResult.undecided;

    int damage = _handleDamageAddition(
      defender,
      _calculateDamage(attack, defence, coeff),
    );
    int actualDamage = defender.deductHealth(damage, isMagic);

    message +=
        '${S.damageLog(defender.name, actualDamage, isMagic, defender.health)}\n';

    if (isMagic) {
      // 如果是法术伤害处理灼烧
      _handleHotDamage(attacker, defender, damage);
    } else {
      // 如果是物理伤害处理吸血
      _handleBloodAbsorption(attacker, actualDamage);
    }

    if (defender.health <= 0) {
      // 决出胜负
      return CombatResult.attackerWin;
    } else {
      // 未决出胜负，处理复仇
      return _handleRevenge(attacker, defender);
    }
  }

  // 计算伤害
  int _calculateDamage(double attack, int defence, double coeff) {
    double damage = defence > 0
        ? attack * (attack / (attack + defence)) * coeff
        : (attack - defence) * coeff;

    int damageRound = damage.round();

    message +=
        "⚔️:${attack.toStringAsFixed(1)} 🛡️:$defence ${(coeff * 100).toStringAsFixed(0)}% => 💔:$damageRound\n";
    return damageRound;
  }

  // 处理伤害加成
  int _handleDamageAddition(Energy energy, int damage) {
    CombatEffect effect = energy.getEffect(EffectID.burnDamage);
    if (effect.expend()) {
      damage += effect.value.round();
      effect.value = 0;
    }

    return damage;
  }

  // 处理吸血效果
  void _handleBloodAbsorption(Energy energy, int damage) {
    CombatEffect absorbBlood = energy.getEffect(EffectID.absorbBlood);
    if (absorbBlood.expend()) {
      int recovery = (damage * absorbBlood.value).round();
      int actual = energy.recoverHealth(recovery);
      message += '${S.healLog(energy.name, actual, energy.health)}\n';
    }
  }

  // 处理灼烧效果
  void _handleHotDamage(Energy attacker, Energy defender, int damage) {
    CombatEffect hotDamage = attacker.getEffect(EffectID.hotDamage);
    if (hotDamage.expend()) {
      CombatEffect burnDamage = defender.getEffect(EffectID.burnDamage);
      burnDamage.times += 1;
      burnDamage.value += damage * hotDamage.value;
    }
  }

  // 处理复仇
  CombatResult _handleRevenge(Energy attacker, Energy defender) {
    CombatResult result = _handleRugged(attacker, defender);
    if (result != CombatResult.undecided) return result;

    return _handleCounter(attacker, defender);
  }

  // 处理反伤
  CombatResult _handleRugged(Energy attacker, Energy defender) {
    CombatEffect rugged = defender.getEffect(EffectID.rugged);
    if (!rugged.expend()) return CombatResult.undecided;

    double attack = (defender.capacityTotal - defender.health) * rugged.value;

    int defence = handleDefenceEffect(defender, attacker, true);

    return _handleAttack(
      defender,
      attacker,
      attack,
      defence,
      rugged.value,
      false,
    ).reversed;
  }

  // 处理反击
  CombatResult _handleCounter(Energy attacker, Energy defender) {
    CombatEffect revenge = defender.getEffect(EffectID.revengeAtonce);
    if (!revenge.expend()) return CombatResult.undecided;

    for (int i = 0; i < revenge.value.round(); i++) {
      CombatResult result = _handleCombat(defender, attacker).reversed;
      if (result != CombatResult.undecided) return result;
    }
    return CombatResult.undecided;
  }

  // 处理生命值扣除
  static int handleDeductHealth(
    Energy energy,
    int damage,
    bool isMagic,
    int Function(int) delHealth,
  ) {
    // 扣除额外上限
    energy.changeCapacityExtra(-damage);

    // 应用伤害
    int actual = delHealth(damage);

    // 处理免死效果
    actual -= _handleExemptionDeath(energy);

    // 调整属性
    _handleAdjustAttributes(energy, -actual, isMagic);

    // 怒气积累
    _handleAngerAccumulation(energy, actual, isMagic);

    return actual;
  }

  // 处理免死效果
  static int _handleExemptionDeath(Energy energy) {
    if (energy.health <= 0) {
      CombatEffect exemption = energy.getEffect(EffectID.exemptionDeath);
      if (exemption.expend()) {
        return exemption.value.round();
      }
    }

    return 0;
  }

  // 处理怒气积累
  static void _handleAngerAccumulation(
    Energy energy,
    int damage,
    bool isMagic,
  ) {
    CombatEffect anger = energy.getEffect(EffectID.accumulateAnger);
    if (!anger.expend()) return;

    CombatEffect effect = isMagic
        ? energy.getEffect(EffectID.magicAddition)
        : energy.getEffect(EffectID.physicsAddition);

    effect.times += 1;
    effect.value += damage * anger.value * (isMagic ? 0.3 : 1.0);
  }

  // 处理生命值恢复
  static int handleRecoverHealth(
    Energy energy,
    int recovery,
    int Function(int) addHealth,
  ) {
    // 增加容量
    _handleIncreaseCapacity(energy, recovery);

    // 应用恢复
    int actual = addHealth(recovery);

    // 调整属性
    _handleAdjustAttributes(energy, actual, false);

    return actual;
  }

  // 处理增加容量
  static void _handleIncreaseCapacity(Energy energy, int recovery) {
    int overflow = energy.health + recovery - energy.capacityTotal;

    if (overflow > 0) {
      CombatEffect increase = energy.getEffect(EffectID.increaseCapacity);
      if (increase.expend()) {
        energy.changeCapacityExtra(overflow);
      }
    }
  }

  // 处理调整属性
  static void _handleAdjustAttributes(Energy energy, int value, bool isMagic) {
    CombatEffect adjustEffect = energy.getEffect(EffectID.adjustAttribute);
    if (!adjustEffect.expend()) return;

    int health = energy.health;
    if (value < 0) {
      health -= value;
    }

    double valueRatio = value / energy.capacityTotal;
    double healthRatio = health / energy.capacityTotal;

    int adjust = (energy.defenceBase * valueRatio * pow(healthRatio + 0.3, 6.2))
        .round();

    energy.changeDefenceOffset(adjust);
    energy.changeAttackOffset(-(adjust * adjustEffect.value).round());

    if (isMagic) {
      CombatEffect enchanting = energy.getEffect(EffectID.enchanting);
      enchanting.times += 1;
      enchanting.value += valueRatio;
    }
  }
}
