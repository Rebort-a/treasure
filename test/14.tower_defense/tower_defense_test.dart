import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/14.tower_defense/base.dart';

void main() {
  test('GridPos JSON 往返和相等性', () {
    const pos = GridPos(3, 4);
    expect(GridPos.fromJson(pos.toJson()), pos);
    expect({pos, const GridPos(3, 4)}, hasLength(1));
  });

  test('Tower 配置、升级和攻击属性一致', () {
    final archer = Tower(type: CellType.archer, pos: const GridPos(1, 2));
    final barrier = Tower(type: CellType.barrier, pos: const GridPos(2, 2));

    expect(archer.hp, TowerConfigs.archer.maxHp);
    expect(archer.canAttack, isTrue);
    expect(archer.upgrades, containsAll([CellType.cannon, CellType.spear]));
    expect(barrier.canAttack, isFalse);
    expect(() => TowerConfigs.getConfig(CellType.road), throwsStateError);
  });

  test('Enemy 减速、路径索引和奖励计算正确', () {
    final enemy =
        Enemy(
            id: 1,
            type: EnemyType.goblin,
            path: const [GridPos(0, 0), GridPos(1, 0), GridPos(2, 0)],
          )
          ..pathProgress = 1.75
          ..slowTimer = 2
          ..speedMultiplier = 0.5;

    expect(enemy.pathIndex, 1);
    expect(enemy.pathFraction, closeTo(0.75, 1e-9));
    expect(enemy.speed, EnemyConfigs.goblin.speed * 0.5);
    expect(enemy.reward, EnemyConfigs.goblin.reward);
  });

  test('波次随关卡增加敌人并限制最低生成间隔', () {
    final wave10 = WaveGenerator.generate(10);
    expect(wave10.groups.map((g) => g.$1), containsAll(EnemyType.values));
    expect(WaveGenerator.generate(100).spawnInterval, 0.6);
    expect(WaveGenerator.scaledHp(100, 10), 250);
  });

  test('地图边界保持道路，入口出口和摧毁转换正确', () {
    final map = GameMapData.generate(
      width: 5,
      height: 3,
      random: Random(1),
      barrierDensity: 1,
    );

    for (int y = 0; y < map.height; y++) {
      expect(map.cells[y].first, CellType.road);
      expect(map.cells[y].last, CellType.road);
    }
    expect(map.cells[1][2], CellType.barrier);
    expect(map.canBuild(2, 1), isTrue);
    expect(map.canBuild(-1, 1), isFalse);

    map
      ..toEnter(0)
      ..toExit(2)
      ..breakToField(2, 1);
    expect(map.cells[0][0], CellType.enter);
    expect(map.cells[2][4], CellType.exit);
    expect(map.cells[1][2], CellType.road);
  });
}
