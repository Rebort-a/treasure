import 'dart:math';
import 'package:flutter/material.dart';

// ==================== 坐标 ====================

class GridPos {
  final int x;
  final int y;
  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPos && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => '($x,$y)';

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory GridPos.fromJson(Map<String, dynamic> json) =>
      GridPos(json['x'] as int, json['y'] as int);
}

// ==================== 格子类型 ====================

/// 统一格子类型：前 3 种为field（敌人可移动），剩下是tower（阻挡敌人、可被摧毁）
enum CellType {
  road,
  exit,
  enter,
  barrier,
  wall,
  fortress,
  archer,
  cannon,
  spear,
  ice,
  magic,
}

extension CellTypeX on CellType {
  bool get isTower => index >= CellType.barrier.index;
}

// ==================== 堡垒 ====================

class TowerConfig {
  final CellType type; // 类型
  final String name; // 名称
  final int cost; // 价值
  final int maxHp; // 血量上限
  final double range; // 攻击范围（格）
  final double fireRate; // 攻击频率（次/秒）
  final int damage; // 伤害
  final double splashRadius; // 溅射范围 （格）
  final double slowFactor; // 减速效果
  final List<CellType> upgrades; // 进化目标（空=已满级，仅可重建）

  const TowerConfig({
    required this.type,
    required this.name,
    required this.cost,
    required this.maxHp,
    this.range = 0,
    this.fireRate = 0,
    this.damage = 0,
    this.splashRadius = 0,
    this.slowFactor = 0,
    this.upgrades = const [],
  });
}

class TowerConfigs {
  static const barrier = TowerConfig(
    type: CellType.barrier,
    name: 'Barrier',
    cost: 10,
    maxHp: 100,
    upgrades: [CellType.wall, CellType.archer, CellType.ice],
  );
  static const wall = TowerConfig(
    type: CellType.wall,
    name: 'Wall',
    cost: 50,
    maxHp: 500,
    upgrades: [CellType.fortress],
  );
  static const fortress = TowerConfig(
    type: CellType.fortress,
    name: 'Fortress',
    cost: 60,
    maxHp: 1000,
  );
  static const archer = TowerConfig(
    type: CellType.archer,
    name: 'Archer',
    cost: 50,
    maxHp: 50,
    range: 2,
    fireRate: 2,
    damage: 5,
    upgrades: [CellType.cannon, CellType.spear],
  );
  static const cannon = TowerConfig(
    type: CellType.cannon,
    name: 'Cannon',
    cost: 60,
    maxHp: 50,
    range: 3,
    fireRate: 0.5,
    damage: 20,
    splashRadius: 1.5,
  );
  static const spear = TowerConfig(
    type: CellType.spear,
    name: 'Spear',
    cost: 50,
    maxHp: 100,
    range: 1.5,
    fireRate: 2,
    damage: 10,
    splashRadius: 1.0,
  );
  static const ice = TowerConfig(
    type: CellType.ice,
    name: 'Ice',
    cost: 75,
    maxHp: 40,
    range: 2,
    fireRate: 1.0,
    damage: 5,
    slowFactor: 0.5,
    upgrades: [CellType.magic],
  );
  static const magic = TowerConfig(
    type: CellType.magic,
    name: 'Magic',
    cost: 80,
    maxHp: 100,
    range: 3,
    fireRate: 1,
    damage: 5,
    splashRadius: 1.5,
    slowFactor: 0.5,
  );

  static TowerConfig getConfig(CellType type) => switch (type) {
    CellType.barrier => barrier,
    CellType.wall => wall,
    CellType.fortress => fortress,
    CellType.archer => archer,
    CellType.cannon => cannon,
    CellType.spear => spear,
    CellType.ice => ice,
    CellType.magic => magic,
    CellType.enter ||
    CellType.exit ||
    CellType.road => throw StateError('field 无塔配置'),
  };
}

class Tower {
  final CellType type;
  final GridPos pos;
  double cooldown; // 发射冷却时间
  int hp; // 血量

  Tower({required this.type, required this.pos, this.cooldown = 0})
    : hp = TowerConfigs.getConfig(type).maxHp;

  TowerConfig get config => TowerConfigs.getConfig(type);
  int get maxHp => config.maxHp;
  int get cost => config.cost;
  bool get canAttack => config.fireRate > 0;
  double get range => config.range;
  int get damage => config.damage;
  List<CellType> get upgrades => config.upgrades;
}

// ==================== 怪物 ====================

enum EnemyType { slime, goblin, troll, cyclops }

class EnemyConfig {
  final EnemyType type; // 类型
  final String name; // 名称
  final int maxHp; // 血量上限
  final double speed; // 移速（格/秒）
  final int attackDamage; // 攻击 tower 每秒伤害
  final int reward; // 击杀奖励

  const EnemyConfig({
    required this.type,
    required this.name,
    required this.maxHp,
    required this.speed,
    required this.attackDamage,
    required this.reward,
  });
}

class EnemyConfigs {
  static const slime = EnemyConfig(
    type: EnemyType.slime,
    name: 'Slime',
    maxHp: 60,
    speed: 0.25,
    attackDamage: 5,
    reward: 10,
  );
  static const goblin = EnemyConfig(
    type: EnemyType.goblin,
    name: 'Goblin',
    maxHp: 150,
    speed: 0.175,
    attackDamage: 10,
    reward: 20,
  );
  static const troll = EnemyConfig(
    type: EnemyType.troll,
    name: 'Troll',
    maxHp: 400,
    speed: 0.1,
    attackDamage: 15,
    reward: 40,
  );
  static const cyclops = EnemyConfig(
    type: EnemyType.cyclops,
    name: 'Cyclops',
    maxHp: 1500,
    speed: 0.075,
    attackDamage: 20,
    reward: 100,
  );

  static EnemyConfig getConfig(EnemyType type) => switch (type) {
    EnemyType.slime => slime,
    EnemyType.goblin => goblin,
    EnemyType.troll => troll,
    EnemyType.cyclops => cyclops,
  };
}

class Enemy {
  final int id; // 唯一标识（飞弹反查用）
  final EnemyType type;
  int hp; // 血量
  double speedMultiplier; // 移速
  double pathProgress; // 路径进程
  bool alive; // 存活

  List<GridPos> path; // 路径
  bool attacking; // 是否正在攻击Tower
  double attackCooldown; // 攻击间隔

  Enemy({required this.id, required this.type, required this.path})
    : hp = EnemyConfigs.getConfig(type).maxHp,
      speedMultiplier = 1.0,
      pathProgress = 0,
      alive = true,
      attacking = false,
      attackCooldown = 0;

  EnemyConfig get config => EnemyConfigs.getConfig(type);
  double get speed => config.speed * speedMultiplier;
  int get reward => config.reward;

  int get pathIndex {
    if (path.isEmpty) return 0;
    return pathProgress.floor().clamp(0, path.length - 1);
  }

  double get pathFraction => pathProgress - pathIndex;
}

// ==================== 波次 ====================

class WaveConfig {
  final List<(EnemyType, int)> groups;
  final double spawnInterval;
  const WaveConfig({required this.groups, this.spawnInterval = 1.6});
}

class WaveGenerator {
  static WaveConfig generate(int waveNumber) {
    final groups = <(EnemyType, int)>[];
    groups.add((EnemyType.slime, 3 + waveNumber));
    if (waveNumber >= 3) {
      groups.add((EnemyType.goblin, 1 + (waveNumber - 3) ~/ 2));
    }
    if (waveNumber >= 6) {
      groups.add((EnemyType.troll, 1 + (waveNumber - 6) ~/ 3));
    }
    if (waveNumber > 0 && waveNumber % 5 == 0) {
      groups.add((EnemyType.cyclops, 1));
    }
    return WaveConfig(
      groups: groups,
      spawnInterval: max(0.6, 1.6 - waveNumber * 0.04),
    );
  }

  static int scaledHp(int baseHp, int waveNumber) {
    return (baseHp * (1.0 + waveNumber * 0.15)).toInt();
  }
}

// ==================== 飞弹 ====================

class Projectile {
  final GridPos from;
  final int targetId;
  final int damage;
  final double splashRadius;
  final double slowFactor;
  double progress;
  Projectile({
    required this.from,
    required this.targetId,
    required this.damage,
    this.splashRadius = 0,
    this.slowFactor = 0,
    this.progress = 0,
  });
}

// ==================== 击杀特效

/// 击杀飞溅特效（基于 animTime 播一次即逝）
class KillEffect {
  final Offset pos; // 像素坐标
  final double bornAt; // 出生时的 animTime
  KillEffect({required this.pos, required this.bornAt});
}

// ==================== 地图 ====================

class GameMapData {
  final int width;
  final int height;
  late final List<List<CellType>> cells;

  GameMapData({required this.width, required this.height});

  bool inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  /// 玩家是否可交互（塔格可进化/重建）
  bool canBuild(int x, int y) => inBounds(x, y) && cells[y][x].isTower;

  /// 初始：最左列 road（enter 候选），最右列 exit，中间按密度随机部署 barrier
  factory GameMapData.generate({
    int width = 20,
    int height = 12,
    Random? random,
    double barrierDensity = 0.65,
  }) {
    final map = GameMapData(width: width, height: height);
    final rand = random ?? Random();
    map.cells = List.generate(
      height,
      (_) => List.filled(width, CellType.road),
    );
    for (int y = 0; y < height; y++) {
      for (int x = 1; x < width - 1; x++) {
        map.cells[y][x] =
            rand.nextDouble() < barrierDensity
                ? CellType.barrier
                : CellType.road;
      }
      map.cells[y][0] = CellType.road;
      map.cells[y][width - 1] = CellType.exit;
    }
    return map;
  }

  /// 最左列 road → enter
  void toEnter(int y) {
    cells[y][0] = CellType.enter;
  }

  /// 塔被摧毁→road
  void breakToField(int x, int y) {
    cells[y][x] = CellType.road;
  }
}

// ==================== 游戏状态 ====================

enum GameState { preparing, playing, paused, won, lost }

// ==================== 颜色 ====================

/// 战场统一蓝灰色（网格底色与道具卡片背景）
const Color kFieldColor = Color(0xFF607D8B);

String towerEmoji(CellType type) => switch (type) {
  CellType.barrier => '🚧',
  CellType.wall => '🧱',
  CellType.fortress => '🏰',
  CellType.archer => '🏹',
  CellType.cannon => '💣',
  CellType.spear => '🔱',
  CellType.ice => '❄️',
  CellType.magic => '🔮',
  CellType.enter || CellType.exit || CellType.road => '',
};

class EnemyColors {
  static const slime = Color(0xFF8BC34A);
  static const goblin = Color(0xFF689F38);
  static const troll = Color(0xFF607D8B);
  static const cyclops = Color(0xFFD32F2F);

  static Color get(EnemyType type) => switch (type) {
    EnemyType.slime => slime,
    EnemyType.goblin => goblin,
    EnemyType.troll => troll,
    EnemyType.cyclops => cyclops,
  };
}
