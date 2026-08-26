import 'dart:math';
import 'package:flutter/material.dart';

// ==================== 坐标 ====================

class GridPos {
  final int x;
  final int y;
  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GridPos && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => '($x,$y)';

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory GridPos.fromJson(Map<String, dynamic> json) =>
      GridPos(json['x'] as int, json['y'] as int);
}

// ==================== 网格类型 ====================

/// tower=塔格(空墙wallHp或堡垒Tower，阻挡+被攻击) / enter=左列入口 / exit=右列出口 / road=普通道路
enum CellType { tower, enter, exit, road }

// ==================== 堡垒（防御塔） ====================

/// 三分支进化：Wall→Fortress、Archer→Cannon|Spear、Ice→Magic
enum TowerType { wall, fortress, archer, cannon, spear, ice, magic }

class TowerConfig {
  final TowerType type;
  final String name;
  final int cost;        // 建造费（0=不可直接建，仅升级得）
  final int maxHp;
  final int damage;
  final double range;    // 格数
  final double fireRate; // 次/秒
  final double splashRadius;
  final double slowFactor;
  final int upgradeCost;        // 升级费（0=不可升级）
  final List<TowerType> upgrades; // 升级目标

  const TowerConfig({
    required this.type,
    required this.name,
    required this.cost,
    required this.maxHp,
    this.damage = 0,
    this.range = 0,
    this.fireRate = 0,
    this.splashRadius = 0,
    this.slowFactor = 0,
    this.upgradeCost = 0,
    this.upgrades = const [],
  });
}

class TowerConfigs {
  static const wall = TowerConfig(
    type: TowerType.wall, name: 'Wall', cost: 50, maxHp: 500,
    upgradeCost: 60, upgrades: [TowerType.fortress],
  );
  static const fortress = TowerConfig(
    type: TowerType.fortress, name: 'Fortress', cost: 0, maxHp: 1000,
    upgradeCost: 60, upgrades: [TowerType.fortress],
  );
  static const archer = TowerConfig(
    type: TowerType.archer, name: 'Archer', cost: 50, maxHp: 50,
    damage: 5, range: 2.0, fireRate: 4.0,
    upgradeCost: 50, upgrades: [TowerType.cannon, TowerType.spear],
  );
  static const cannon = TowerConfig(
    type: TowerType.cannon, name: 'Cannon', cost: 0, maxHp: 50,
    damage: 20, range: 3.0, fireRate: 1.0, splashRadius: 1.5,
  );
  static const spear = TowerConfig(
    type: TowerType.spear, name: 'Spear', cost: 0, maxHp: 100,
    damage: 10, range: 1.0, fireRate: 2.0, splashRadius: 1.0,
  );
  static const ice = TowerConfig(
    type: TowerType.ice, name: 'Ice', cost: 75, maxHp: 20,
    damage: 5, range: 2.0, fireRate: 2.0, slowFactor: 0.5,
    upgradeCost: 60, upgrades: [TowerType.magic],
  );
  static const magic = TowerConfig(
    type: TowerType.magic, name: 'Magic', cost: 0, maxHp: 50,
    damage: 5, range: 3.0, fireRate: 2.0, splashRadius: 1.5, slowFactor: 0.5,
  );

  static TowerConfig getConfig(TowerType type) => switch (type) {
    TowerType.wall => wall,
    TowerType.fortress => fortress,
    TowerType.archer => archer,
    TowerType.cannon => cannon,
    TowerType.spear => spear,
    TowerType.ice => ice,
    TowerType.magic => magic,
  };
}

class Tower {
  final TowerType type;
  final GridPos pos;
  double cooldown;
  int hp;

  Tower({required this.type, required this.pos, this.cooldown = 0})
      : hp = TowerConfigs.getConfig(type).maxHp;

  TowerConfig get config => TowerConfigs.getConfig(type);
  int get maxHp => config.maxHp;
  int get damage => config.damage;
  double get range => config.range;
  int get upgradeCost => config.upgradeCost;
  bool get canUpgrade => config.upgrades.isNotEmpty;
  List<TowerType> get upgrades => config.upgrades;
  bool get canAttack => config.fireRate > 0;
}

// ==================== 敌人 ====================

enum EnemyType { goblin, orc, troll, boss }

class EnemyConfig {
  final EnemyType type;
  final String name;
  final int maxHp;
  final double speed;    // 格/秒
  final int attackDamage; // 攻击 tower 每秒伤害
  final int reward;

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
  static const goblin = EnemyConfig(
    type: EnemyType.goblin, name: 'Goblin',
    maxHp: 60, speed: 0.25, attackDamage: 5, reward: 10,
  );
  static const orc = EnemyConfig(
    type: EnemyType.orc, name: 'Orc',
    maxHp: 150, speed: 0.175, attackDamage: 10, reward: 20,
  );
  static const troll = EnemyConfig(
    type: EnemyType.troll, name: 'Troll',
    maxHp: 400, speed: 0.10, attackDamage: 15, reward: 40,
  );
  static const boss = EnemyConfig(
    type: EnemyType.boss, name: 'Boss',
    maxHp: 1500, speed: 0.075, attackDamage: 20, reward: 100,
  );

  static EnemyConfig getConfig(EnemyType type) => switch (type) {
    EnemyType.goblin => goblin,
    EnemyType.orc => orc,
    EnemyType.troll => troll,
    EnemyType.boss => boss,
  };
}

class Enemy {
  final EnemyType type;
  int hp;
  double speedMultiplier;
  double pathProgress;
  bool alive;

  List<GridPos> path;
  Tower? targetFort;
  bool attacking;
  double attackCooldown;

  Enemy({required this.type, required this.path})
      : hp = EnemyConfigs.getConfig(type).maxHp,
        speedMultiplier = 1.0,
        pathProgress = 0,
        alive = true,
        targetFort = null,
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
  const WaveConfig({required this.groups, this.spawnInterval = 0.8});
}

class WaveGenerator {
  static WaveConfig generate(int waveNumber) {
    final groups = <(EnemyType, int)>[];
    groups.add((EnemyType.goblin, 3 + waveNumber));
    if (waveNumber >= 3) {
      groups.add((EnemyType.orc, 1 + (waveNumber - 3) ~/ 2));
    }
    if (waveNumber >= 6) {
      groups.add((EnemyType.troll, 1 + (waveNumber - 6) ~/ 3));
    }
    if (waveNumber > 0 && waveNumber % 5 == 0) {
      groups.add((EnemyType.boss, 1));
    }
    return WaveConfig(
      groups: groups,
      spawnInterval: max(0.3, 0.8 - waveNumber * 0.02),
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

// ==================== 地图 ====================

class GameMapData {
  final int width;
  final int height;
  final List<List<CellType>> cells;
  final List<List<int>> wallHp; // 空 tower 格 hp（有 Tower 时为 0）
  final List<GridPos> leftGaps;  // enter 列表
  final List<GridPos> rightGaps; // exit 列表

  GameMapData({
    required this.width,
    required this.height,
    required this.cells,
    required this.wallHp,
    required this.leftGaps,
    required this.rightGaps,
  });

  bool inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  /// tower 格可建堡垒（空墙；已有 Tower 由 foundation 检查）
  bool canBuild(int x, int y) =>
      inBounds(x, y) && cells[y][x] == CellType.tower;

  /// 初始：最左列 enter，最右列 exit，中间全 tower（100hp）
  factory GameMapData.generate({int width = 20, int height = 12, int? seed}) {
    final cells = List.generate(height, (_) => List.filled(width, CellType.tower));
    final wallHp = List.generate(height, (_) => List.filled(width, 100));
    final leftGaps = <GridPos>[];
    final rightGaps = <GridPos>[];
    for (int y = 0; y < height; y++) {
      cells[y][0] = CellType.enter;
      wallHp[y][0] = 0;
      leftGaps.add(GridPos(0, y));
      cells[y][width - 1] = CellType.exit;
      wallHp[y][width - 1] = 0;
      rightGaps.add(GridPos(width - 1, y));
    }
    return GameMapData(
      width: width,
      height: height,
      cells: cells,
      wallHp: wallHp,
      leftGaps: leftGaps,
      rightGaps: rightGaps,
    );
  }

  /// tower 被打破→field：第一列→enter，最后列→exit，其他→road
  void breakToField(int x, int y) {
    if (x == 0) {
      cells[y][x] = CellType.enter;
      final g = GridPos(x, y);
      if (!leftGaps.contains(g)) leftGaps.add(g);
    } else if (x == width - 1) {
      cells[y][x] = CellType.exit;
      final g = GridPos(x, y);
      if (!rightGaps.contains(g)) rightGaps.add(g);
    } else {
      cells[y][x] = CellType.road;
    }
    wallHp[y][x] = 0;
  }
}

// ==================== 游戏状态 ====================

enum GameState { preparing, playing, won, lost }

// ==================== 颜色 ====================

class TowerColors {
  static const wall = Color(0xFF607D8B);
  static const fortress = Color(0xFF455A64);
  static const archer = Color(0xFF6D4C41);
  static const cannon = Color(0xFFFF5722);
  static const spear = Color(0xFF795548);
  static const ice = Color(0xFF01579B);
  static const magic = Color(0xFF9C27B0);

  static Color get(TowerType type) => switch (type) {
    TowerType.wall => wall,
    TowerType.fortress => fortress,
    TowerType.archer => archer,
    TowerType.cannon => cannon,
    TowerType.spear => spear,
    TowerType.ice => ice,
    TowerType.magic => magic,
  };
}

String towerEmoji(TowerType type) => switch (type) {
  TowerType.wall => '🧱',
  TowerType.fortress => '🏰',
  TowerType.archer => '🏹',
  TowerType.cannon => '💣',
  TowerType.spear => '🔱',
  TowerType.ice => '❄️',
  TowerType.magic => '🔮',
};

class EnemyColors {
  static const goblin = Color(0xFF8BC34A);
  static const orc = Color(0xFF795548);
  static const troll = Color(0xFF607D8B);
  static const boss = Color(0xFFD32F2F);

  static Color get(EnemyType type) => switch (type) {
    EnemyType.goblin => goblin,
    EnemyType.orc => orc,
    EnemyType.troll => troll,
    EnemyType.boss => boss,
  };
}
