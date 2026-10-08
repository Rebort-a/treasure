import '../../00.common/game/entity.dart';
import '../../00.common/l10n/strings.dart';

import 'elemental.dart';
import '../base/energy.dart';

/// 道具效果只描述规则，图标与选择弹窗由界面层提供。
enum PropEffect {
  none,
  recoverHealth,
  upgradeAttack,
  upgradeDefence,
  returnHome,
}

class MapProp {
  final EntityType id;
  final String name;
  final String description;
  final String icon;
  final PropEffect effect;
  final int price;
  int count = 0;

  MapProp({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.effect,
    required this.price,
  });

  /// 只对已有的五行使用道具，成功后消耗一件；无效果或缺货不扣库存。
  bool applyTo(Elemental elemental, EnergyType target) {
    if (count <= 0 ||
        effect == PropEffect.none ||
        effect == PropEffect.returnHome ||
        !elemental.getAppointAptitude(target)) {
      return false;
    }
    switch (effect) {
      case PropEffect.recoverHealth:
        elemental.recoverAppoint(target, Energy.healthStep);
      case PropEffect.upgradeAttack:
        elemental.upgradeAppointAttribute(target, AttributeType.atk);
      case PropEffect.upgradeDefence:
        elemental.upgradeAppointAttribute(target, AttributeType.def);
      case PropEffect.none:
      case PropEffect.returnHome:
        return false;
    }
    count--;
    return true;
  }

  /// 导航类道具由界面层执行行为，库存消耗仍在模型中统一校验。
  bool consume() {
    if (count <= 0) return false;
    count--;
    return true;
  }
}

class PropCollection {
  PropCollection._();

  static final Map<EntityType, MapProp> totalItems = {
    EntityType.hospital: hospital,
    EntityType.sword: sword,
    EntityType.shield: shield,
    EntityType.scroll: scroll,
  };

  static MapProp emptyItem = MapProp(
    id: EntityType.road,
    name: '',
    description: '',
    icon: '',
    effect: PropEffect.none,
    price: 0,
  );

  static MapProp hospital = MapProp(
    id: EntityType.hospital,
    name: S.potion,
    description: S.potionDesc,
    icon: '💊',
    effect: PropEffect.recoverHealth,
    price: 10,
  );

  static MapProp sword = MapProp(
    id: EntityType.sword,
    name: S.sword,
    description: S.swordDesc,
    icon: '🗡️',
    effect: PropEffect.upgradeAttack,
    price: 10,
  );

  static MapProp shield = MapProp(
    id: EntityType.shield,
    name: S.shield,
    description: S.shieldDesc,
    icon: '🛡️',
    effect: PropEffect.upgradeDefence,
    price: 10,
  );
  static MapProp scroll = MapProp(
    id: EntityType.scroll,
    name: S.scroll,
    description: S.scrollDesc,
    icon: '📜',
    effect: PropEffect.returnHome,
    price: 10,
  );
}
