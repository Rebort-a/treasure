import 'package:flutter/material.dart';

import '../../00.common/image/entity.dart';
import '../../l10n/strings.dart';

import 'elemental.dart';
import 'dialog.dart';
import '../base/energy.dart';

class MapProp {
  final EntityType id;
  final String name;
  final String description;
  final String icon;
  final IconData? type;
  final int price;
  void Function(BuildContext context, Elemental elemental, VoidCallback after)
  handler;
  int count = 0;

  MapProp({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.price,
    required this.handler,
  });
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
    type: null,
    price: 0,
    handler: (context, elemental, after) {},
  );

  static MapProp hospital = MapProp(
    id: EntityType.hospital,
    name: S.potion,
    description: S.potionDesc,
    icon: '💊',
    type: Icons.local_hospital,
    price: 10,
    handler: (context, elemental, after) {
      ElementalDialog.showSelectEnergyDialog(
        context: context,
        elemental: elemental,
        onSelected: (index) {
          after();
          elemental.recoverAppoint(index, Energy.healthStep);
        },
        available: false,
      );
    },
  );

  static MapProp sword = MapProp(
    id: EntityType.sword,
    name: S.sword,
    description: S.swordDesc,
    icon: '🗡️',
    type: Icons.colorize,
    price: 10,
    handler: (context, elemental, after) {
      ElementalDialog.showSelectEnergyDialog(
        context: context,
        elemental: elemental,
        onSelected: (index) {
          after();
          elemental.upgradeAppointAttribute(index, AttributeType.atk);
        },
        available: false,
      );
    },
  );

  static MapProp shield = MapProp(
    id: EntityType.shield,
    name: S.shield,
    description: S.shieldDesc,
    icon: '🛡️',
    type: Icons.shield,
    price: 10,
    handler: (context, elemental, after) {
      ElementalDialog.showSelectEnergyDialog(
        context: context,
        elemental: elemental,
        onSelected: (index) {
          after();
          elemental.upgradeAppointAttribute(index, AttributeType.def);
        },
        available: false,
      );
    },
  );
  static MapProp scroll = MapProp(
    id: EntityType.scroll,
    name: S.scroll,
    description: S.scrollDesc,
    icon: '📜',
    type: null,
    price: 10,
    handler: (context, elemental, after) {},
  );
}
