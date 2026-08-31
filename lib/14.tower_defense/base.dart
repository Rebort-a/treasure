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
  final int projectileCount; // 弹道数（每次发射的飞弹数，多弹道各寻一目标）
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
    this.projectileCount = 1,
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
    cost: 100,
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
    cost: 100,
    maxHp: 75,
    range: 3,
    fireRate: 1,
    damage: 15,
    splashRadius: 0.5,
  );
  static const spear = TowerConfig(
    type: CellType.spear,
    name: 'Spear',
    cost: 100,
    maxHp: 100,
    range: 1.5,
    fireRate: 2,
    damage: 10,
    projectileCount: 3, // 三弹道：每次至多命中 3 个不同敌人
  );
  static const ice = TowerConfig(
    type: CellType.ice,
    name: 'Ice',
    cost: 75,
    maxHp: 40,
    range: 2,
    fireRate: 1,
    damage: 5,
    slowFactor: 0.5,
    upgrades: [CellType.magic],
  );
  static const magic = TowerConfig(
    type: CellType.magic,
    name: 'Magic',
    cost: 100,
    maxHp: 50,
    range: 3,
    fireRate: 1,
    damage: 5,
    splashRadius: 0.5,
    slowFactor: 0.75,
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

// ==================== 飞弹 ====================

class Bullet {
  final GridPos from;
  final int targetId;
  final int damage;
  final double splashRadius;
  final double slowFactor;
  final CellType type; // 弹道颜色来源（发射塔类型）
  double progress;
  Offset lastTargetPixel; // 目标最后像素位置（目标死亡后冻结，飞弹继续飞至此）
  Bullet({
    required this.from,
    required this.targetId,
    required this.damage,
    required this.type,
    required this.lastTargetPixel,
    this.splashRadius = 0,
    this.slowFactor = 0,
    this.progress = 0,
  });
}

/// 道具子弹专属颜色
class BulletColors {
  static const wall = Color(0xFF8D6E63);
  static const fortress = Color(0xFF4E342E);
  static const archer = Color(0xFF6D4C41);
  static const cannon = Color(0xFFFF5722);
  static const spear = Color(0xFFFFD700);
  static const ice = Color(0xFF01579B);
  static const magic = Color(0xFF9C27B0);

  static Color get(CellType type) => switch (type) {
    CellType.wall => wall,
    CellType.fortress => fortress,
    CellType.archer => archer,
    CellType.cannon => cannon,
    CellType.spear => spear,
    CellType.ice => ice,
    CellType.magic => magic,
    _ => Colors.white, // barrier/field 不发射，兜底
  };
}

// ==================== 击杀特效 ====================

/// 击杀飞溅特效（基于 animTime 播一次即逝）
class KillEffect {
  final Offset pos; // 像素坐标
  final double bornAt; // 出生时的 animTime
  KillEffect({required this.pos, required this.bornAt});
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
    maxHp: 25,
    speed: 0.25,
    attackDamage: 5,
    reward: 10,
  );
  static const goblin = EnemyConfig(
    type: EnemyType.goblin,
    name: 'Goblin',
    maxHp: 75,
    speed: 0.25,
    attackDamage: 10,
    reward: 20,
  );
  static const troll = EnemyConfig(
    type: EnemyType.troll,
    name: 'Troll',
    maxHp: 150,
    speed: 0.1,
    attackDamage: 15,
    reward: 50,
  );
  static const cyclops = EnemyConfig(
    type: EnemyType.cyclops,
    name: 'Cyclops',
    maxHp: 500,
    speed: 0.3,
    attackDamage: 20,
    reward: 150,
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
  double slowTimer; // 减速剩余时间（>0 时持续减速）
  double pathProgress; // 路径进程
  bool dying; // 死亡中（播死亡行帧后移除）
  double deathTime; // 进入 dying 时的 animTime

  List<GridPos> path; // 路径
  bool attacking; // 是否正在攻击Tower
  bool escaped; // 已逃到出口（定位到出口格并绘制一帧后再移除）
  double attackCooldown; // 攻击间隔

  Enemy({required this.id, required this.type, required this.path})
    : hp = EnemyConfigs.getConfig(type).maxHp,
      speedMultiplier = 1.0,
      slowTimer = 0,
      pathProgress = 0,
      dying = false,
      deathTime = 0,
      attacking = false,
      escaped = false,
      attackCooldown = 0;

  EnemyConfig get config => EnemyConfigs.getConfig(type);
  double get speed => config.speed * (slowTimer > 0 ? speedMultiplier : 1.0);
  int get reward => config.reward;

  int get pathIndex {
    if (path.isEmpty) return 0;
    return pathProgress.floor().clamp(0, path.length - 1);
  }

  double get pathFraction => pathProgress - pathIndex;
}

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

// ==================== 移动方向 ====================

/// 怪物当前移动方向（按路径段 dy 判定），供动画选行
enum MoveDir { right, up, down, none }

// ==================== 精灵动画配置 ====================

/// 单行动画：所在行 + 有效帧数
class SpriteAnim {
  final int row;
  final int frames;
  const SpriteAnim(this.row, this.frames);
}

/// 怪物精灵表配置：每行按动作/方向分配
class EnemySpriteDef {
  final String asset;
  final int columns;
  final int rows;
  final SpriteAnim moveRight; // 向右行走
  final SpriteAnim moveUp; // 向上奔跑
  final SpriteAnim moveDown; // 向下/待机
  final SpriteAnim attack; // 攻击
  final SpriteAnim? death; // 死亡（空=无死亡行，回退 slash 特效）
  final double fps;
  final bool flipX; // 精灵默认朝左时需水平翻转（敌人向右行进）
  final double displayScale; // 显示高度 = cellSize * displayScale

  const EnemySpriteDef({
    required this.asset,
    required this.columns,
    required this.rows,
    required this.moveRight,
    required this.moveUp,
    required this.moveDown,
    required this.attack,
    this.death,
    required this.fps,
    required this.flipX,
    required this.displayScale,
  });
}

class EnemySprites {
  static const String slimeAsset = 'assets/images/slime.png';
  static const String goblinAsset = 'assets/images/goblin.png';
  static const String trollAsset = 'assets/images/troll.png';
  static const String cyclopsAsset = 'assets/images/cyclops.png';

  static const Map<EnemyType, EnemySpriteDef> all = {
    EnemyType.slime: EnemySpriteDef(
      asset: slimeAsset,
      columns: 10,
      rows: 4,
      moveRight: SpriteAnim(1, 6), // 移动（向右）
      moveUp: SpriteAnim(0, 8), // 待机行复用作上下移动
      moveDown: SpriteAnim(0, 8),
      attack: SpriteAnim(2, 10), // 攻击/跳跃
      death: SpriteAnim(3, 7), // 受击→死亡
      fps: 8,
      flipX: false,
      displayScale: 1.0,
    ),
    EnemyType.goblin: EnemySpriteDef(
      asset: goblinAsset,
      columns: 14,
      rows: 6,
      moveRight: SpriteAnim(1, 8), // 行走（向右）
      moveUp: SpriteAnim(4, 8), // 奔跑（向上）
      moveDown: SpriteAnim(0, 6), // 待机（向下）
      attack: SpriteAnim(3, 14), // 攻击・挥砍（第四行）
      death: SpriteAnim(5, 3), // 受击
      fps: 8,
      flipX: false,
      displayScale: 1.0,
    ),
    EnemyType.troll: EnemySpriteDef(
      asset: trollAsset,
      columns: 4,
      rows: 4,
      moveRight: SpriteAnim(1, 4), // 行走（向右）
      moveUp: SpriteAnim(2, 4), // 攻击前摇行复用作向上
      moveDown: SpriteAnim(0, 4), // 待机（向下）
      attack: SpriteAnim(3, 4), // 攻击・挥砍
      death: null, // 无死亡行，回退 slash 特效
      fps: 4,
      flipX: false, // troll.png 默认朝右，无需镜像
      displayScale: 1.0,
    ),
    EnemyType.cyclops: EnemySpriteDef(
      asset: cyclopsAsset,
      columns: 20,
      rows: 6,
      moveRight: SpriteAnim(2, 8), // 行走（向右）
      moveUp: SpriteAnim(0, 4), // 待机（向上）
      moveDown: SpriteAnim(1, 4), // 眨眼（向下）
      attack: SpriteAnim(3, 20), // 攻击・能量
      death: SpriteAnim(5, 5), // 死亡
      fps: 4,
      flipX: false,
      displayScale: 1.0,
    ),
  };

  static EnemySpriteDef get(EnemyType type) => all[type]!;
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

// ==================== 地图 ====================

class GameMapData {
  final int width;
  final int height;
  late final List<List<CellType>> cells;

  GameMapData({required this.width, required this.height});

  bool inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  /// 玩家是否可交互（塔格可进化/重建）
  bool canBuild(int x, int y) => inBounds(x, y) && cells[y][x].isTower;

  /// 初始：最左/最右两列 road（enter/exit 候选），中间按密度随机部署 barrier；
  /// 每波再由 Manager 在最左列转 enter、最右列转 exit
  factory GameMapData.generate({
    int width = 20,
    int height = 12,
    Random? random,
    double barrierDensity = 0.65,
  }) {
    final map = GameMapData(width: width, height: height);
    final rand = random ?? Random();
    map.cells = List.generate(height, (_) => List.filled(width, CellType.road));
    for (int y = 0; y < height; y++) {
      for (int x = 1; x < width - 1; x++) {
        map.cells[y][x] = rand.nextDouble() < barrierDensity
            ? CellType.barrier
            : CellType.road;
      }
      map.cells[y][0] = CellType.road;
      map.cells[y][width - 1] = CellType.road;
    }
    return map;
  }

  /// 最左列 road → enter
  void toEnter(int y) {
    cells[y][0] = CellType.enter;
  }

  /// 最右列 road → exit
  void toExit(int y) {
    cells[y][width - 1] = CellType.exit;
  }

  /// 塔被摧毁→road
  void breakToField(int x, int y) {
    cells[y][x] = CellType.road;
  }
}

// ==================== 游戏状态 ====================

enum GameState { preparing, playing, paused, lost }

// ==================== 颜色 ====================

/// 战场统一蓝灰色（网格底色与道具卡片背景）
const Color kFieldColor = Color(0xFF607D8B);
