import 'dart:math';

import '../../00.common/image/entity.dart';
import '../../00.common/l10n/strings.dart';
import '../base/energy.dart';
import 'elemental.dart';

class RandomEnemy extends ElementalEntity {
  static final enemyNames = [
    S.enemyImp,
    S.enemyClown,
    S.enemyDemon,
    S.enemyKing,
  ];

  final int grade;

  RandomEnemy._({
    required super.baseName,
    required super.configs,
    required super.current,
    required super.id,
    required super.y,
    required super.x,
    required this.grade,
  });

  factory RandomEnemy.generate({
    required EntityType id,
    required int y,
    required int x,
    required int grade,
  }) {
    int typeIndex = id.index - EntityType.weak.index;
    final baseName = enemyNames[typeIndex];
    final configs = _generateRandomConfig(grade + typeIndex);

    return RandomEnemy._(
      baseName: baseName,
      configs: configs,
      current: Random().nextInt(EnergyType.values.length),
      id: id,
      y: y,
      x: x,

      grade: grade,
    );
  }

  static EnergyConfigs _generateRandomConfig(int upgradePoints) {
    EnergyConfigs configs = EnergyConfigs.defaultConfigs(skillPoints: 2);

    Random random = Random();
    List<EnergyType> types = List.of(EnergyType.values);

    // 随机禁用部分灵根
    types.shuffle();
    int disableCount = random.nextInt(EnergyType.values.length);
    types.take(disableCount).forEach((t) {
      configs[t].aptitude = false;
      upgradePoints += 3;
    });

    // 分配点数到启用的灵根
    List<EnergyType> enabledTypes = types.skip(disableCount).toList();
    List<int> pointsPerType = _distributePoints(
      enabledTypes.length,
      upgradePoints,
      random,
    );

    // 分配属性点
    for (int i = 0; i < enabledTypes.length; i++) {
      final config = configs[enabledTypes[i]];
      final points = pointsPerType[i];
      _allocateAttributes(config, points, random);
    }

    return configs;
  }

  static List<int> _distributePoints(int count, int total, Random random) {
    final points = List.filled(count, 0);
    for (int i = 0; i < total; i++) {
      points[random.nextInt(count)]++;
    }
    return points;
  }

  static void _allocateAttributes(
    EnergyConfig config,
    int points,
    Random random,
  ) {
    final attributes = [
      () => config.healthPoints++,
      () => config.attackPoints++,
      () => config.defencePoints++,
    ];

    for (int i = 0; i < points; i++) {
      attributes[random.nextInt(attributes.length)]();
    }
  }
}
