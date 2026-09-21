import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/map.dart';
import 'package:treasure/17.tank/base.dart';
import 'package:treasure/17.tank/foundation_manager.dart';
import 'package:treasure/17.tank/foundation_widget.dart';

void main() {
  group('序列化默认值省略与回填', () {
    test('Tank 默认字段省略，反序列化后保持一致', () {
      final tank = Tank(
        position: const Offset(100, 100),
        angle: -pi / 2,
        playerId: 0,
        color: PlayerType.p1.color,
      );

      final json = tank.toJson();

      expect(json, containsPair('pid', 0));
      expect(json, contains('px'));
      expect(json, contains('color'));
      for (final key in [
        'ang',
        'tAng',
        'hp',
        'mhp',
        'sz',
        'spd',
        'dmg',
        'fiv',
        'rtm',
        'ivt',
        'reload',
        'alive',
        'respawn',
        'invincible',
        'fireBuff',
        'homingBuff',
        'playerShield',
        'moving',
        'enemy',
      ]) {
        expect(json, isNot(contains(key)), reason: '默认字段 $key 不应传输');
      }

      final restored = Tank.fromJson(json);
      expect(restored.position, tank.position);
      expect(restored.playerId, tank.playerId);
      expect(restored.angle, tank.angle);
      expect(restored.health, tank.health);
      expect(restored.size, tank.size);
      expect(restored.speed, tank.speed);
      expect(restored.damage, tank.damage);
      expect(restored.fireInterval, tank.fireInterval);
      expect(restored.respawnTime, tank.respawnTime);
      expect(restored.invincibleTime, tank.invincibleTime);
      expect(restored.isAlive, isTrue);
      expect(restored.moving, isTrue);
      expect(restored.enemyType, isNull);
    });

    test('Tank 非默认字段保留', () {
      final tank = Tank(
        position: const Offset(5, 5),
        angle: 0,
        health: 3,
        size: 40,
        speed: 80,
        damage: 12,
        fireInterval: 5,
        isAlive: false,
        moving: false,
        playerId: -1,
        color: EnemyType.armor.color,
        enemyType: EnemyType.armor,
        aiDestination: const Offset(120, 160),
        aiFiring: true,
        aiPlanTimer: 2.5,
      );

      final json = tank.toJson();

      expect(json['ang'], 0.0);
      expect(json['hp'], 3);
      expect(json['sz'], 40.0);
      expect(json['spd'], 80.0);
      expect(json['dmg'], 12);
      expect(json['fiv'], 5.0);
      expect(json['alive'], false);
      expect(json['moving'], false);
      expect(json['enemy'], 'armor');
      expect(json['aiDest'], isNotNull);
      expect(json['aiFiring'], isTrue);
      expect(json['aiPlan'], 2.5);

      final restored = Tank.fromJson(json);
      expect(restored.health, 3);
      expect(restored.size, 40);
      expect(restored.enemyType, EnemyType.armor);
      expect(restored.isAlive, isFalse);
      expect(restored.aiDestination, const Offset(120, 160));
      expect(restored.aiFiring, isTrue);
      expect(restored.aiPlanTimer, 2.5);
    });

    test('Bullet 默认字段省略，size 和 speed 可往返', () {
      final bullet = Bullet(
        position: const Offset(1, 2),
        angle: 1.5,
        ownerId: 7,
      );

      final json = bullet.toJson();

      expect(json, contains('px'));
      expect(json, containsPair('ang', 1.5));
      expect(json, containsPair('owner', 7));
      expect(json, isNot(contains('sz')));
      expect(json, isNot(contains('spd')));
      expect(json, isNot(contains('dmg')));
      expect(json, isNot(contains('hmg')));
      expect(json, isNot(contains('tgt')));

      final restored = Bullet.fromJson(json);
      expect(restored.size, 8);
      expect(restored.speed, 300);
      expect(restored.damage, Bullet.baseDamage);
      expect(restored.homing, isFalse);
      expect(restored.targetKey, isNull);

      final customized = Bullet(
        position: Offset.zero,
        angle: 0,
        ownerId: 1,
        size: 12,
        speed: 500,
        homing: true,
        targetKey: 3,
      );
      final customizedRestored = Bullet.fromJson(customized.toJson());
      expect(customizedRestored.size, 12);
      expect(customizedRestored.speed, 500);
      expect(customizedRestored.homing, isTrue);
      expect(customizedRestored.targetKey, 3);
    });

    test('空地 Tile 省略 type', () {
      expect(Tile(TileType.empty).toJson(), isEmpty);
      expect(Tile(TileType.brick).toJson(), {'type': 'brick'});
      expect(Tile.fromJson({}).type, TileType.empty);
      expect(Tile.fromJson({'type': 'steel'}).type, TileType.steel);
    });
  });

  group('模型职责', () {
    test('玩家与敌方工厂应用各自规格', () {
      final player = Tank.player(
        position: const Offset(20, 20),
        playerId: 2,
        color: PlayerType.p3.color,
      );
      final enemy = Tank.enemy(
        position: const Offset(40, 40),
        type: EnemyType.armor,
      );

      expect(player.isPlayer, isTrue);
      expect(player.moving, isFalse);
      expect(player.invincibleTimer, TankGameConfig.spawnInvincibleDuration);
      expect(enemy.isPlayer, isFalse);
      expect(enemy.health, EnemyType.armor.health);
      expect(enemy.damage, EnemyType.armor.damage);
      expect(enemy.enemyType, EnemyType.armor);
    });

    test('TankMap 集中处理边界、阻挡和基地围墙', () {
      final map = TankMap.classic();
      const outside = Rect.fromLTWH(-1, 0, 10, 10);
      final openCell = Rect.fromCenter(
        center: const Offset(20, 20),
        width: TankDefaults.size,
        height: TankDefaults.size,
      );

      expect(map.containsRect(outside), isFalse);
      expect(map.containsRect(openCell), isTrue);
      expect(map.blocksTank(openCell), isFalse);

      map.setBaseWall(TileType.steel);
      final baseCol = (map.baseCenter.dx / TankGameConfig.tileSize).floor();
      final baseRow = (map.baseCenter.dy / TankGameConfig.tileSize).floor();
      expect(map.tileAt(baseCol - 1, baseRow).type, TileType.steel);
      expect(map.tileAt(baseCol, baseRow).type, TileType.base);
    });

    test('随机地图为所有出生点保留连通主干', () {
      const hub = Point<int>(6, 6);
      const spawnCells = <Point<int>>[
        Point(0, 0),
        Point(6, 0),
        Point(12, 0),
        Point(3, 12),
        Point(4, 12),
        Point(9, 12),
        Point(10, 12),
      ];

      for (var seed = 0; seed < 20; seed++) {
        final map = TankMap.random(Random(seed));
        final reachable = _reachableCells(map, hub);
        for (final spawn in spawnCells) {
          expect(
            reachable,
            contains(spawn),
            reason: 'seed=$seed 的出生点 $spawn 与主战场不连通',
          );
        }
      }
    });

    test('playerLives 表示包含当前坦克在内的总生命数', () {
      final manager = _TestTankManager();
      addTearDown(manager.dispose);
      manager.addPlayerTank(manager.identity);
      final tank = manager.tanks[manager.identity]!;

      for (var death = 1; death <= TankGameConfig.playerLives; death++) {
        tank
          ..isAlive = true
          ..health = Bullet.baseDamage
          ..invincibleTimer = 0
          ..respawnTimer = 0;

        expect(manager.applyHit(manager.identity), isTrue);
        expect(
          manager.livesByPlayer[manager.identity],
          TankGameConfig.playerLives - death,
        );
        expect(tank.respawnTimer > 0, death < TankGameConfig.playerLives);
      }
    });

    test('应用全量快照会清理上一局的结果和瞬时效果', () {
      final source = _TestTankManager()..addPlayerTank(0);
      final target = _TestTankManager()
        ..addPlayerTank(0)
        ..gameResult.value = const TankGameResult(victory: false, score: 10)
        ..explosions.add(Explosion(position: const Offset(20, 20), size: 32));
      addTearDown(source.dispose);
      addTearDown(target.dispose);

      target.fromJson(source.toJson());

      expect(target.gameResult.value, isNull);
      expect(target.explosions, isEmpty);
    });

    test('构造子弹不会提前修改状态，确认后才应用', () {
      final manager = _TestTankManager()..addPlayerTank(0);
      addTearDown(manager.dispose);
      final tank = manager.tanks[0]!
        ..invincibleTimer = 0
        ..reloadTimer = 0;

      final bullet = manager.buildBullet(0, tank);

      expect(bullet, isNotNull);
      expect(manager.bullets, isEmpty);
      expect(tank.reloadTimer, 0);

      manager.applyFire(0, bullet!);

      expect(manager.bullets, [bullet]);
      expect(tank.reloadTimer, tank.fireInterval);
    });

    test('AI 计划一次设置目的地和持续开火阶段', () {
      final manager = _TestTankManager();
      addTearDown(manager.dispose);
      final enemy = Tank.enemy(
        position: const Offset(20, 20),
        type: EnemyType.basic,
      );
      manager
        ..tanks[-1] = enemy
        ..applyAiPlan(-1, const Offset(100, 180), Direction.down, true, 3);

      // 即使收到斜向目的地，也只保留计划方向上的位移。
      expect(enemy.aiDestination, const Offset(20, 180));
      expect(enemy.aiFiring, isTrue);
      expect(enemy.aiPlanTimer, 3);
      expect(enemy.angle, Direction.down.angle);
      expect(enemy.turretAngle, Direction.down.angle);
      expect(enemy.moving, isTrue);
    });
  });

  testWidgets('HUD 不显示重生和无敌倒计时，并提供 Material 文本环境', (tester) async {
    final manager = _TestTankManager()..addPlayerTank(0);
    addTearDown(manager.dispose);
    final tank = manager.tanks[0]!
      ..invincibleTimer = 1
      ..isAlive = false
      ..respawnTimer = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: TankGameScreen(manager: manager, showStateButton: true),
      ),
    );

    expect(find.byType(Material), findsWidgets);
    expect(find.byIcon(Icons.flash_on), findsNothing);
    expect(find.byIcon(Icons.autorenew), findsNothing);
    expect(tank.invincibleTimer, 1);
    expect(tank.respawnTimer, 1);
  });
}

Set<Point<int>> _reachableCells(TankMap map, Point<int> start) {
  final visited = <Point<int>>{start};
  final pending = <Point<int>>[start];
  const offsets = <Point<int>>[
    Point(0, -1),
    Point(0, 1),
    Point(-1, 0),
    Point(1, 0),
  ];

  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    for (final offset in offsets) {
      final next = Point(current.x + offset.x, current.y + offset.y);
      if (next.x < 0 ||
          next.x >= map.cols ||
          next.y < 0 ||
          next.y >= map.rows ||
          map.tileAt(next.x, next.y).type.blocksTank ||
          !visited.add(next)) {
        continue;
      }
      pending.add(next);
    }
  }
  return visited;
}

class _TestTankManager extends TankGameManager {
  _TestTankManager() {
    initTicker();
  }

  @override
  int get identity => 0;

  @override
  bool get isAuthority => true;

  @override
  void leavePage() {}

  @override
  void requestRestart() {}

  @override
  void updatePlayerAim(double angle) {}

  @override
  void updatePlayerAimStop() {}

  @override
  void updatePlayerFire() {}

  @override
  void updatePlayerMove(double angle) {}

  @override
  void updatePlayerStop() {}
}
