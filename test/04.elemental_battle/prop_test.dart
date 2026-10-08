import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/entity.dart';
import 'package:treasure/04.elemental_battle/base/energy.dart';
import 'package:treasure/04.elemental_battle/middle/elemental.dart';
import 'package:treasure/04.elemental_battle/middle/prop.dart';

MapProp _prop(PropEffect effect, {int count = 1}) => MapProp(
  id: EntityType.sword,
  name: 'test',
  description: '',
  icon: '',
  effect: effect,
  price: 10,
)..count = count;

Elemental _player() => Elemental(
  baseName: 'test',
  configs: EnergyConfigs.defaultConfigs(),
  current: 0,
);

void main() {
  for (final effect in [PropEffect.upgradeAttack, PropEffect.upgradeDefence]) {
    test('$effect 只修改选定五行并消耗一次，不依赖弹窗', () {
      final player = _player();
      final prop = _prop(effect);
      final beforeAttack = player.getAppointAttack(EnergyType.metal);
      final beforeDefence = player.getAppointDefence(EnergyType.metal);
      final otherAttack = player.getAppointAttack(EnergyType.wood);
      expect(prop.applyTo(player, EnergyType.metal), isTrue);
      expect(prop.count, 0);
      expect(
        effect == PropEffect.upgradeAttack
            ? player.getAppointAttack(EnergyType.metal) > beforeAttack
            : player.getAppointDefence(EnergyType.metal) > beforeDefence,
        isTrue,
      );
      expect(player.getAppointAttack(EnergyType.wood), otherAttack);
      expect(prop.applyTo(player, EnergyType.metal), isFalse);
      expect(prop.count, 0);
    });
  }

  test('恢复道具受生命上限约束，库存只扣一次', () {
    final player = _player();
    final health = player.getAppointHealth(EnergyType.metal);
    final prop = _prop(PropEffect.recoverHealth);
    expect(prop.applyTo(player, EnergyType.metal), isTrue);
    expect(player.getAppointHealth(EnergyType.metal), health);
    expect(prop.count, 0);
  });

  test('无效果道具和未启用五行不会消耗库存', () {
    final player = _player();
    final empty = _prop(PropEffect.none);
    expect(empty.applyTo(player, EnergyType.metal), isFalse);
    expect(empty.count, 1);
    final configs = EnergyConfigs.defaultConfigs();
    configs[EnergyType.wood].aptitude = false;
    final partial = Elemental(baseName: 'test', configs: configs, current: 0);
    final sword = _prop(PropEffect.upgradeAttack);
    expect(sword.applyTo(partial, EnergyType.wood), isFalse);
    expect(sword.count, 1);
  });

  test('回城只提供库存操作，不把导航回调保存到数据模型', () {
    final prop = _prop(PropEffect.returnHome);
    expect(prop.applyTo(_player(), EnergyType.metal), isFalse);
    expect(prop.consume(), isTrue);
    expect(prop.consume(), isFalse);
    expect(prop.count, 0);
  });
}
