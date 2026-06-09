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

enum CellType { empty, path, tower }

// ==================== 防御塔 ====================

enum TowerType { arrow, cannon, ice, magic }

class TowerConfig {
  final TowerType type;
  final String name;
  final int cost;
  final int damage;
  final double range;     // 格数
  final double fireRate;  // 次/秒
  final double splashRadius; // 溅射范围（0=单体）
  final double slowFactor;   // 减速系数（0=无减速）
  final bool pierce;     // 穿透

  const TowerConfig({
    required this.type,
    required this.name,
    required this.cost,
    required this.damage,
    required this.range,
    required this.fireRate,
    this.splashRadius = 0,
    this.slowFactor = 0,
    this.pierce = false,
  });
}

class TowerConfigs {
  static const arrow = TowerConfig(
    type: TowerType.arrow,
    name: 'Arrow',
    cost: 50,
    damage: 15,
    range: 3.0,
    fireRate: 2.0,
  );
  static const cannon = TowerConfig(
    type: TowerType.cannon,
    name: 'Cannon',
    cost: 100,
    damage: 50,
    range: 2.5,
    fireRate: 0.8,
    splashRadius: 1.5,
  );
  static const ice = TowerConfig(
    type: TowerType.ice,
    name: 'Ice',
    cost: 75,
    damage: 8,
    range: 3.0,
    fireRate: 1.5,
    slowFactor: 0.5,
  );
  static const magic = TowerConfig(
    type: TowerType.magic,
    name: 'Magic',
    cost: 125,
    damage: 30,
    range: 4.0,
    fireRate: 1.2,
    pierce: true,
  );

  static TowerConfig getConfig(TowerType type) => switch (type) {
    TowerType.arrow => arrow,
    TowerType.cannon => cannon,
    TowerType.ice => ice,
    TowerType.magic => magic,
  };
}

class Tower {
  final TowerType type;
  final GridPos pos;
  int level; // 1-3
  double cooldown;

  Tower({required this.type, required this.pos, this.level = 1, this.cooldown = 0});

  TowerConfig get config => TowerConfigs.getConfig(type);
  int get damage => (config.damage * (1 + (level - 1) * 0.5)).toInt();
  double get range => config.range + (level - 1) * 0.5;
  int get upgradeCost => (config.cost * level * 0.6).toInt();

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'x': pos.x,
    'y': pos.y,
    'level': level,
  };

  factory Tower.fromJson(Map<String, dynamic> json) => Tower(
    type: TowerType.values[json['type'] as int],
    pos: GridPos(json['x'] as int, json['y'] as int),
    level: json['level'] as int,
  );
}

// ==================== 敌人 ====================

enum EnemyType { goblin, orc, troll, boss }

class EnemyConfig {
  final EnemyType type;
  final String name;
  final int maxHp;
  final double speed;   // 格/秒
  final int reward;

  const EnemyConfig({
    required this.type,
    required this.name,
    required this.maxHp,
    required this.speed,
    required this.reward,
  });
}

class EnemyConfigs {
  static const goblin = EnemyConfig(
    type: EnemyType.goblin,
    name: 'Goblin',
    maxHp: 60,
    speed: 2.0,
    reward: 10,
  );
  static const orc = EnemyConfig(
    type: EnemyType.orc,
    name: 'Orc',
    maxHp: 150,
    speed: 1.2,
    reward: 20,
  );
  static const troll = EnemyConfig(
    type: EnemyType.troll,
    name: 'Troll',
    maxHp: 400,
    speed: 0.8,
    reward: 40,
  );
  static const boss = EnemyConfig(
    type: EnemyType.boss,
    name: 'Boss',
    maxHp: 1500,
    speed: 0.6,
    reward: 100,
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
  double pathProgress; // 0.0 ~ path.length-1
  bool alive;

  Enemy({required this.type, required this.pathProgress})
    : hp = EnemyConfigs.getConfig(type).maxHp,
      speedMultiplier = 1.0,
      alive = true;

  EnemyConfig get config => EnemyConfigs.getConfig(type);
  double get speed => config.speed * speedMultiplier;
  int get reward => config.reward;

  /// 当前所在路径索引
  int get pathIndex => pathProgress.floor();

  /// 在当前路径格子内的插值 (0.0~1.0)
  double get pathFraction => pathProgress - pathIndex;
}

// ==================== 波次 ====================

class WaveConfig {
  final List<(EnemyType, int)> groups; // (类型, 数量)
  final double spawnInterval; // 生成间隔（秒）

  const WaveConfig({required this.groups, this.spawnInterval = 0.8});
}

class WaveGenerator {
  static WaveConfig generate(int waveNumber) {
    final groups = <(EnemyType, int)>[];

    // 哥布林：每波都有
    groups.add((EnemyType.goblin, 3 + waveNumber));

    // 兽人：第3波起
    if (waveNumber >= 3) {
      groups.add((EnemyType.orc, 1 + (waveNumber - 3) ~/ 2));
    }

    // 巨魔：第6波起
    if (waveNumber >= 6) {
      groups.add((EnemyType.troll, 1 + (waveNumber - 6) ~/ 3));
    }

    // Boss：每5波
    if (waveNumber > 0 && waveNumber % 5 == 0) {
      groups.add((EnemyType.boss, 1));
    }

    return WaveConfig(
      groups: groups,
      spawnInterval: max(0.3, 0.8 - waveNumber * 0.02),
    );
  }

  /// 应用血量倍率到敌人
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
  final bool pierce;
  double progress; // 0.0~1.0

  Projectile({
    required this.from,
    required this.targetId,
    required this.damage,
    this.splashRadius = 0,
    this.slowFactor = 0,
    this.pierce = false,
    this.progress = 0,
  });
}

// ==================== 地图生成 ====================

class GameMapData {
  final int width;
  final int height;
  final List<List<CellType>> cells;
  final List<GridPos> path; // 路径坐标序列

  GameMapData({
    required this.width,
    required this.height,
    required this.cells,
    required this.path,
  });

  bool inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  bool canBuild(int x, int y) =>
      inBounds(x, y) && cells[y][x] == CellType.empty;

  factory GameMapData.generate({int width = 20, int height = 12, int? seed}) {
    final rand = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    final cells = List.generate(height, (_) => List.filled(width, CellType.empty));
    final path = <GridPos>[];

    // 从左侧随机起点开始生成路径
    int y = rand.nextInt(height - 4) + 2;
    int x = 0;
    cells[y][x] = CellType.path;
    path.add(GridPos(x, y));

    while (x < width - 1) {
      final r = rand.nextDouble();
      if (r < 0.55) {
        // 向右
        x++;
      } else if (r < 0.78 && y > 1 && cells[y - 1][x] != CellType.path) {
        // 向上
        y--;
      } else if (y < height - 2 && cells[y + 1][x] != CellType.path) {
        // 向下
        y++;
      } else {
        x++;
      }

      if (x >= width) break;
      if (cells[y][x] == CellType.path) continue; // 避免交叉

      cells[y][x] = CellType.path;
      path.add(GridPos(x, y));
    }

    return GameMapData(width: width, height: height, cells: cells, path: path);
  }
}

// ==================== 游戏状态 ====================

enum GameState { preparing, playing, won, lost }

// ==================== 颜色 ====================

class TowerColors {
  static const arrow = Color(0xFF8D6E63);
  static const cannon = Color(0xFFFF5722);
  static const ice = Color(0xFF03A9F4);
  static const magic = Color(0xFF9C27B0);

  static Color get(TowerType type) => switch (type) {
    TowerType.arrow => arrow,
    TowerType.cannon => cannon,
    TowerType.ice => ice,
    TowerType.magic => magic,
  };
}

String towerEmoji(TowerType type) => switch (type) {
  TowerType.arrow => '🏹',
  TowerType.cannon => '💣',
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
