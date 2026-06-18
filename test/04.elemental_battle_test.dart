import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/04.elemental_battle/base/effect.dart';
import 'package:treasure/04.elemental_battle/base/energy.dart';
import 'package:treasure/04.elemental_battle/middle/elemental.dart';

void main() {
  group('Elemental Battle', () {
    group('EnergyType 五行关系', () {
      test('相生顺序：金生水、水生木、木生火、火生土、土生金', () {
        expect(EnergyType.metal.getGenerativeType(), EnergyType.water);
        expect(EnergyType.water.getGenerativeType(), EnergyType.wood);
        expect(EnergyType.wood.getGenerativeType(), EnergyType.fire);
        expect(EnergyType.fire.getGenerativeType(), EnergyType.earth);
        expect(EnergyType.earth.getGenerativeType(), EnergyType.metal);
      });

      test('getNextType 按枚举顺序循环', () {
        // getNextType 是枚举顺序：金(0)→木(1)→水(2)→火(3)→土(4)→金
        expect(EnergyType.metal.getNextType(), EnergyType.wood);
        expect(EnergyType.wood.getNextType(), EnergyType.water);
        expect(EnergyType.water.getNextType(), EnergyType.fire);
        expect(EnergyType.fire.getNextType(), EnergyType.earth);
        expect(EnergyType.earth.getNextType(), EnergyType.metal);
      });

      test('getPreviousType 按枚举顺序循环', () {
        expect(EnergyType.metal.getPreviousType(), EnergyType.earth);
        expect(EnergyType.earth.getPreviousType(), EnergyType.fire);
      });

      test('各属性基础值不同', () {
        final metal = EnergyType.metal.baseAttributes;
        final wood = EnergyType.wood.baseAttributes;
        final water = EnergyType.water.baseAttributes;
        final fire = EnergyType.fire.baseAttributes;
        final earth = EnergyType.earth.baseAttributes;

        // 金：高攻
        expect(metal, [128, 32, 32]);
        // 木：高血
        expect(wood, [256, 32, 16]);
        // 水：高防
        expect(water, [160, 16, 64]);
        // 火：高攻低血
        expect(fire, [96, 64, 16]);
        // 土：超高血无防
        expect(earth, [384, 16, 0]);

        // 确保各属性确实不同
        expect(metal, isNot(equals(wood)));
        expect(wood, isNot(equals(water)));
      });
    });

    group('EnergyConfig 序列化', () {
      test('toStringFormat ↔ fromStringFormat 互转', () {
        final config = EnergyConfig(
          aptitude: true,
          healthPoints: 3,
          attackPoints: 2,
          defencePoints: 1,
          skillPoints: 4,
        );

        final str = config.toStringFormat();
        final restored = EnergyConfig.fromStringFormat(str);

        expect(restored.aptitude, config.aptitude);
        expect(restored.healthPoints, config.healthPoints);
        expect(restored.attackPoints, config.attackPoints);
        expect(restored.defencePoints, config.defencePoints);
        expect(restored.skillPoints, config.skillPoints);
      });

      test('aptitude=false 序列化正确', () {
        final config = EnergyConfig(aptitude: false);
        final str = config.toStringFormat();
        expect(str, '[0,0,0,0,1]');

        final restored = EnergyConfig.fromStringFormat(str);
        expect(restored.aptitude, isFalse);
      });

      test('默认值正确', () {
        final config = EnergyConfig();
        expect(config.aptitude, isTrue);
        expect(config.healthPoints, 0);
        expect(config.attackPoints, 0);
        expect(config.defencePoints, 0);
        expect(config.skillPoints, 1);
      });

      test('level 计算', () {
        final config = EnergyConfig(
          healthPoints: 2,
          attackPoints: 3,
          defencePoints: 1,
          skillPoints: 4,
        );
        expect(config.level, 10); // 2+3+1+4
      });
    });

    group('EnergyConfigs 批量序列化', () {
      test('configToString ↔ fromString 互转', () {
        final configs = EnergyConfigs.defaultConfigs(
          healthPoints: 1,
          attackPoints: 2,
          defencePoints: 3,
          skillPoints: 4,
        );

        final str = configs.configToString();
        final restored = EnergyConfigs.fromString(str);

        for (final type in EnergyType.values) {
          expect(restored[type].healthPoints, configs[type].healthPoints);
          expect(restored[type].attackPoints, configs[type].attackPoints);
          expect(restored[type].defencePoints, configs[type].defencePoints);
          expect(restored[type].skillPoints, configs[type].skillPoints);
        }
      });
    });

    group('CombatEffect 效果系统', () {
      test('有限次数效果：expend 消耗次数', () {
        final effect = CombatEffect(
          id: EffectID.strengthen,
          type: EffectType.limited,
          value: 0.5,
          times: 2,
        );

        expect(effect.check(), isTrue);
        expect(effect.expend(), isTrue);
        expect(effect.times, 1);
        expect(effect.expend(), isTrue);
        expect(effect.times, 0);
        expect(effect.check(), isFalse);
        expect(effect.expend(), isFalse);
      });

      test('无限效果：expend 始终返回 true', () {
        final effect = CombatEffect(
          id: EffectID.strengthen,
          type: EffectType.infinite,
          value: 0.5,
          times: 0,
        );

        expect(effect.check(), isTrue);
        expect(effect.expend(), isTrue);
        expect(effect.expend(), isTrue);
        expect(effect.times, 0); // 次数不变
      });

      test('reset 重置效果', () {
        final effect = CombatEffect(
          id: EffectID.strengthen,
          type: EffectType.infinite,
          value: 0.75,
          times: 5,
        );

        effect.reset();
        expect(effect.type, EffectType.limited);
        expect(effect.value, 0);
        expect(effect.times, 0);
      });
    });

    group('Energy 基础属性', () {
      test('初始化后生命值等于容量上限', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        expect(energy.health, energy.capacityTotal);
      });

      test('各属性类型基础值正确', () {
        // 金：[128, 32, 32]
        final metal = Energy(name: 'test', type: EnergyType.metal);
        expect(metal.capacityBase, 128);
        expect(metal.attackBase, 32);
        expect(metal.defenceBase, 32);

        // 木：[256, 32, 16]
        final wood = Energy(name: 'test', type: EnergyType.wood);
        expect(wood.capacityBase, 256);
        expect(wood.attackBase, 32);
        expect(wood.defenceBase, 16);

        // 土：[384, 16, 0]
        final earth = Energy(name: 'test', type: EnergyType.earth);
        expect(earth.capacityBase, 384);
        expect(earth.attackBase, 16);
        expect(earth.defenceBase, 0);
      });

      test('生命值回复不超过上限', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        final maxHealth = energy.health;

        // 已满血，回复应该返回 0
        final actual = energy.recoverHealth(100);
        expect(actual, 0);
        expect(energy.health, maxHealth);
      });

      test('生命值扣除不低于 0', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        final maxHealth = energy.health;

        // 扣除超过生命值
        energy.deductHealth(maxHealth + 100, false);
        expect(energy.health, 0);
      });

      test('生命值扣除和回复', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        final maxHealth = energy.health;

        energy.deductHealth(50, false);
        expect(energy.health, maxHealth - 50);

        energy.recoverHealth(30);
        expect(energy.health, maxHealth - 20);
      });

      test('restoreAttributes 恢复满血', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        energy.deductHealth(100, false);
        expect(energy.health, lessThan(energy.capacityTotal));

        energy.restoreAttributes();
        expect(energy.health, energy.capacityTotal);
      });

      test('技能数量与类型匹配', () {
        for (final type in EnergyType.values) {
          final energy = Energy(name: 'test', type: type);
          expect(energy.skills.length, 5, reason: '${type.name} should have 5 skills');
        }
      });

      test('效果数量等于 EffectID 枚举数', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        expect(energy.effects.length, EffectID.values.length);
      });
    });

    group('Energy 属性升级', () {
      test('升级生命增加 capacityBase', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        final originalCap = energy.capacityBase;

        energy.upgradeAttributes(AttributeType.hp);
        expect(energy.capacityBase, originalCap + Energy.healthStep);
      });

      test('升级攻击增加 attackBase', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        final originalAtk = energy.attackBase;

        energy.upgradeAttributes(AttributeType.atk);
        expect(energy.attackBase, originalAtk + Energy.attackStep);
      });

      test('升级防御增加 defenceBase', () {
        final energy = Energy(name: 'test', type: EnergyType.metal);
        final originalDef = energy.defenceBase;

        energy.upgradeAttributes(AttributeType.def);
        expect(energy.defenceBase, originalDef + Energy.defenceStep);
      });
    });

    group('EnergyCombat 伤害计算', () {
      test('handleAttackEffect 基础攻击力', () {
        final attacker = Energy(name: 'atk', type: EnergyType.metal);
        final defender = Energy(name: 'def', type: EnergyType.earth);

        final attack = EnergyCombat.handleAttackEffect(attacker, defender, false);
        expect(attack, attacker.attackTotal);
      });

      test('handleDefenceEffect 基础防御力', () {
        final attacker = Energy(name: 'atk', type: EnergyType.metal);
        final defender = Energy(name: 'def', type: EnergyType.water);

        final defence = EnergyCombat.handleDefenceEffect(attacker, defender, false);
        expect(defence, defender.defenceTotal);
      });

      test('战斗执行不崩溃', () {
        final attacker = Energy(name: 'atk', type: EnergyType.fire);
        final defender = Energy(name: 'def', type: EnergyType.earth);

        final combat = EnergyCombat(source: attacker, target: defender);
        expect(() => combat.execute(), returnsNormally);
        expect(combat.result, isNotNull);
      });

      test('高攻低血火打高血低防土，土应该扣血', () {
        final fire = Energy(name: 'fire', type: EnergyType.fire);
        final earth = Energy(name: 'earth', type: EnergyType.earth);

        final earthHealthBefore = earth.health;
        final combat = EnergyCombat(source: fire, target: earth);
        combat.execute();

        // 火攻击 64+0=64，土防御 0+0=0，应该有伤害
        expect(earth.health, lessThan(earthHealthBefore));
      });
    });

    group('CombatResult', () {
      test('reversed 正确反转', () {
        expect(CombatResult.attackerWin.reversed, CombatResult.defenderWin);
        expect(CombatResult.defenderWin.reversed, CombatResult.attackerWin);
        expect(CombatResult.undecided.reversed, CombatResult.undecided);
        expect(CombatResult.attackerEscape.reversed, CombatResult.defenderEscape);
        expect(CombatResult.defenderEscape.reversed, CombatResult.attackerEscape);
      });
    });
  });
}
