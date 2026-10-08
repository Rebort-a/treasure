import 'package:flutter/material.dart';

import '../middle/prop.dart';

/// 将道具规则映射为界面图标，逻辑层不依赖 Material。
IconData? propIcon(MapProp prop) => switch (prop.effect) {
  PropEffect.recoverHealth => Icons.local_hospital,
  PropEffect.upgradeAttack => Icons.colorize,
  PropEffect.upgradeDefence => Icons.shield,
  PropEffect.none || PropEffect.returnHome => null,
};
