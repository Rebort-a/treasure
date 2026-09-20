import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/tool/convert_utils.dart';

// ---- 地图常量 ----
const int gridSize = 13;
const double tileSize = 40;
const double mapSize = gridSize * tileSize; // 520

// ---- 坦克/子弹常量 ----
const double tankSize = tileSize * 0.8;
const double bulletSize = tileSize * 0.2;
const double tankSpeed = 160; // px/s
const double bulletSpeed = 300;
const double reloadTime = 0.8; // AI 开火冷却（秒）
const double playerReloadTime = 0.3; // 玩家开火冷却（秒）
const double respawnTime = 2.0; // 重生延迟（秒）
const double invincibleTime = 2.0; // 重生后无敌时间（秒）

// ---- 对局常量 ----
const int playerLives = 3; // 玩家命数
const int totalEnemyCount = 20; // 一局敌方总数
const int maxEnemyOnField = 4; // 同屏最多敌方
const List<Offset> enemySpawnPoints = [
  // 顶部三个出生点（col, row 网格坐标 -> 像素中心）
  Offset(0.5 * tileSize, 0.5 * tileSize),
  Offset(6.5 * tileSize, 0.5 * tileSize),
  Offset(12.5 * tileSize, 0.5 * tileSize),
];
const List<Offset> playerSpawnPoints = [
  // 底部出生点（中心坐标，避开基地周围一圈砖墙 col 6/7/8 row 12）
  Offset(4.5 * tileSize, 12.5 * tileSize),
  Offset(10.5 * tileSize, 12.5 * tileSize),
  Offset(3.5 * tileSize, 12.5 * tileSize),
  Offset(9.5 * tileSize, 12.5 * tileSize),
];

// ---- 颜色 ----
const Color brickColor = Color(0xFFB0682A);
const Color steelColor = Color(0xFF9EA7B0);
const Color grassColor = Color(0xFF4CAF50);
const Color waterColor = Color(0xFF2196F3);
const Color baseColor = Color(0xFFFFC107);
const Color baseDestroyedColor = Color(0xFF616161);
const Color bulletColor = Color(0xFFFFEB3B); // 玩家子弹
const Color enemyBulletColor = Color(0xFFFFFFFF); // 敌方子弹（白）
const List<Color> playerColors = [
  Color(0xFFFFD600), // P1 黄
  Color(0xFF4CAF50), // P2 绿
  Color(0xFF2196F3), // P3 蓝
  Color(0xFF9C27B0), // P4 紫
];

/// 方向枚举（4 向网格移动）
enum Direction {
  up,
  down,
  left,
  right;

  /// 单位向量（屏幕坐标，y 向下）
  Offset get vector => switch (this) {
    up => const Offset(0, -1),
    down => const Offset(0, 1),
    left => const Offset(-1, 0),
    right => const Offset(1, 0),
  };

  /// 渲染旋转角度（弧度），默认坦克朝上绘制
  double get angle => switch (this) {
    up => -pi / 2,
    right => 0.0,
    down => pi / 2,
    left => pi,
  };

  static Direction fromName(String name) =>
      values.firstWhere((d) => d.name == name, orElse: () => Direction.up);
}

/// 地形类型
enum TileType {
  empty, // 空地
  brick, // 砖墙（可毁）
  steel, // 钢墙（不可毁）
  grass, // 草地（坦克与子弹均可过，渲染在上层）
  water, // 水（坦克不可过，子弹可过）
  base // 基地（被毁即败）
  ;

  /// 坦克是否阻挡（不可驶入）
  bool get blocksTank =>
      this == brick || this == steel || this == water || this == base;

  /// 子弹是否阻挡（命中即销毁子弹，砖墙随之受损）
  bool get blocksBullet => this == brick || this == steel || this == base;

  static TileType fromName(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => TileType.empty);
}

/// AI 敌方坦克类型
enum EnemyType {
  basic, // 普通
  fast, // 高速
  power, // 快速子弹
  armor // 装甲（多血）
  ;

  double get speed => switch (this) {
    basic => 80,
    fast => 160,
    power => 100,
    armor => 60,
  };

  int get health => switch (this) {
    basic => 1,
    fast => 1,
    power => 1,
    armor => 4,
  };

  int get points => switch (this) {
    basic => 100,
    fast => 200,
    power => 300,
    armor => 400,
  };

  /// 体型系数（相对标准 tankSize）：fast 小巧，armor 庞大
  double get sizeFactor => switch (this) {
    basic => 1.0,
    fast => 0.8,
    power => 1.0,
    armor => 1.25,
  };

  /// 外观配色（按种类区分）
  Color get color => switch (this) {
    basic => const Color(0xFF8D6E63), // 灰褐
    fast => const Color(0xFFFF7043), // 橙
    power => const Color(0xFF8E24AA), // 紫
    armor => const Color(0xFFC62828), // 红
  };

  /// 满血参照（供渲染算装甲破损度）
  int get maxHealth => health;

  /// 道具掉落概率
  double get dropRate => switch (this) {
    basic => 0.06,
    fast => 0.09,
    power => 0.12,
    armor => 0.18,
  };

  static EnemyType fromName(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => EnemyType.basic);
}

/// 地图单元
class Tile {
  TileType type;

  Tile(this.type);

  static Tile empty() => Tile(TileType.empty);

  Map<String, dynamic> toJson() => {'type': type.name};

  static Tile fromJson(Map<String, dynamic> json) =>
      Tile(TileType.fromName(json['type'] as String));
}

/// 坦克
class Tank {
  Offset position; // 中心像素坐标
  double angle; // 车身朝向（弧度，0=右，顺时针为正）
  double turretAngle; // 炮塔朝向（弧度）
  int health;
  double reloadTimer; // 开火冷却剩余
  int starLevel; // 玩家星级 0-3
  int playerId; // >=0 为玩家序号，-1 为 AI
  bool isAlive;
  bool moving; // 是否正在移动（玩家松开停止，AI 持续）
  double respawnTimer; // 重生倒计时（>0 表示待重生）
  double invincibleTimer; // 无敌剩余
  double fireBuffTimer; // 火焰子弹剩余（>0 期间伤害翻倍）
  double homingBuffTimer; // 自动跟踪剩余（>0 期间开火吸附）
  double playerShieldTimer; // 玩家护盾剩余（>0 抵消一次攻击）
  Color color;
  EnemyType? enemyType; // AI 专属

  Tank({
    required this.position,
    required this.angle,
    required this.health,
    required this.playerId,
    required this.color,
    this.turretAngle = -pi / 2,
    this.starLevel = 0,
    this.isAlive = true,
    this.reloadTimer = 0,
    this.respawnTimer = 0,
    this.invincibleTimer = 0,
    this.fireBuffTimer = 0,
    this.homingBuffTimer = 0,
    this.playerShieldTimer = 0,
    this.moving = true,
    this.enemyType,
  });

  bool get isPlayer => playerId >= 0;

  /// 实际体型（敌方按类型差异化，玩家为标准体型）
  double get size => tankSize * (enemyType?.sizeFactor ?? 1.0);

  Rect get rect =>
      Rect.fromCenter(center: position, width: size, height: size);

  bool get canFire => isAlive && reloadTimer <= 0;

  Map<String, dynamic> toJson() => {
    'px': ConvertUtils.offsetToJson(position),
    'ang': angle,
    'tAng': turretAngle,
    'hp': health,
    'reload': reloadTimer,
    'star': starLevel,
    'pid': playerId,
    'alive': isAlive,
    'respawn': respawnTimer,
    'invincible': invincibleTimer,
    'fireBuff': fireBuffTimer,
    'homingBuff': homingBuffTimer,
    'playerShield': playerShieldTimer,
    'moving': moving,
    'color': ConvertUtils.colorToJson(color),
    'enemy': enemyType?.name,
  };

  static Tank fromJson(Map<String, dynamic> json) => Tank(
    position: ConvertUtils.offsetFromJson(json['px'] as Map<String, dynamic>),
    angle: (json['ang'] as num).toDouble(),
    health: json['hp'] as int,
    playerId: json['pid'] as int,
    color: ConvertUtils.colorFromJson(json['color'] as Map<String, dynamic>),
    turretAngle: (json['tAng'] as num?)?.toDouble() ?? -pi / 2,
    starLevel: json['star'] as int,
    isAlive: json['alive'] as bool,
    reloadTimer: (json['reload'] as num).toDouble(),
    respawnTimer: (json['respawn'] as num).toDouble(),
    invincibleTimer: (json['invincible'] as num).toDouble(),
    fireBuffTimer: (json['fireBuff'] as num?)?.toDouble() ?? 0,
    homingBuffTimer: (json['homingBuff'] as num?)?.toDouble() ?? 0,
    playerShieldTimer: (json['playerShield'] as num?)?.toDouble() ?? 0,
    moving: json['moving'] as bool? ?? true,
    enemyType: json['enemy'] == null
        ? null
        : EnemyType.fromName(json['enemy'] as String),
  );
}

/// 子弹
class Bullet {
  Offset position;
  double angle; // 飞行方向（弧度）
  int ownerId; // 发射坦克的 key（玩家=identity，AI=负数）
  int damage;
  int? targetKey; // 跟踪目标 tank key（null=直线飞行）

  Bullet({
    required this.position,
    required this.angle,
    required this.ownerId,
    this.damage = 1,
    this.targetKey,
  });

  Offset get velocity => Offset.fromDirection(angle) * bulletSpeed;

  Rect get rect =>
      Rect.fromCenter(center: position, width: bulletSize, height: bulletSize);

  Map<String, dynamic> toJson() => {
    'px': ConvertUtils.offsetToJson(position),
    'ang': angle,
    'owner': ownerId,
    'dmg': damage,
    'tgt': targetKey,
  };

  static Bullet fromJson(Map<String, dynamic> json) => Bullet(
    position: ConvertUtils.offsetFromJson(json['px'] as Map<String, dynamic>),
    angle: (json['ang'] as num).toDouble(),
    ownerId: json['owner'] as int,
    damage: (json['dmg'] as num?)?.toInt() ?? 1,
    targetKey: json['tgt'] as int?,
  );
}

/// 道具类型
enum PowerUpType {
  shield, // 基地护盾：基地一圈变 steel，10s 后变 brick
  fireBullet, // 火焰子弹：8s 内伤害翻倍
  homing, // 自动跟踪：5s 内子弹吸附敌人
  playerShield; // 玩家护盾：10s 内抵消一次攻击

  static PowerUpType fromName(String name) => values.firstWhere(
    (t) => t.name == name,
    orElse: () => PowerUpType.shield,
  );
}

/// 道具
class PowerUp {
  final Offset position;
  final PowerUpType type;

  const PowerUp({required this.position, required this.type});

  Rect get rect => Rect.fromCenter(
    center: position,
    width: tileSize * 0.7,
    height: tileSize * 0.7,
  );

  Map<String, dynamic> toJson() => {
    'px': ConvertUtils.offsetToJson(position),
    'type': type.name,
  };

  static PowerUp fromJson(Map<String, dynamic> json) => PowerUp(
    position: ConvertUtils.offsetFromJson(json['px'] as Map<String, dynamic>),
    type: PowerUpType.fromName(json['type'] as String),
  );
}

/// 爆炸粒子
class ExplosionParticle {
  Offset position;
  final double radius;
  final Color color;
  final Offset velocity;
  int life;

  ExplosionParticle({
    required this.position,
    required this.radius,
    required this.color,
    required this.velocity,
    required this.life,
  });
}

/// 爆炸效果
class Explosion {
  Offset position;
  double size;
  double alpha = 1.0;
  List<ExplosionParticle> particles = [];
  bool finished = false;

  Explosion({required this.position, required this.size}) {
    final random = Random();
    for (int i = 0; i < 20; i++) {
      particles.add(
        ExplosionParticle(
          position: position,
          radius: random.nextDouble() * 3 + 1,
          color: Color.fromRGBO(
            255,
            (random.nextDouble() * 100).toInt() + 100,
            0,
            1,
          ),
          velocity: Offset(
            (random.nextDouble() - 0.5) * 6,
            (random.nextDouble() - 0.5) * 6,
          ),
          life: (random.nextDouble() * 30 + 20).toInt(),
        ),
      );
    }
  }

  void update(double deltaTime) {
    alpha -= deltaTime * 2;
    for (var p in particles) {
      p.position += p.velocity * deltaTime * 60;
      p.life--;
    }
    particles.removeWhere((p) => p.life <= 0);
    finished = particles.isEmpty || alpha <= 0;
  }
}

/// 地图数据（13×13 网格）
class MapData {
  final List<List<Tile>> tiles; // tiles[row][col]

  MapData(this.tiles);

  int get rows => tiles.length;
  int get cols => tiles.isEmpty ? 0 : tiles.first.length;

  Tile tileAt(int col, int row) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) {
      return Tile(TileType.steel); // 越界视作钢墙（不可逾越）
    }
    return tiles[row][col];
  }

  void setTileType(int col, int row, TileType type) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) return;
    tiles[row][col].type = type;
  }

  /// 基地中心（col=7, row=12）
  Offset get baseCenter => Offset((7 + 0.5) * tileSize, (12 + 0.5) * tileSize);

  /// 经典布局（13×13）
  static const _layout = <String>[
    '.............',
    '.BB.SS.BB.SS.',
    '.BB.SS.BB.SS.',
    '.............',
    'BBB.......BBB',
    '...GGGGGGG...',
    '...WW...WW...',
    '.BB.......BB.',
    '.............',
    '.SS.BB.SS.BB.',
    '.SS.BB.SS.BB.',
    '......BBB....',
    '......BEB....',
  ];

  static MapData classic() => parse(_layout);

  /// 随机地图：基地+周围一圈砖墙与出生点固定，其余按概率散布
  static MapData random(Random rng) {
    final tiles = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => Tile.empty()),
    );
    // 固定区：基地 + 周围一圈砖墙
    const baseCol = 7, baseRow = 12;
    for (final dc in <int>[-1, 0, 1]) {
      for (final dr in <int>[-1, 0, 1]) {
        final r = baseRow + dr, c = baseCol + dc;
        if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) continue;
        tiles[r][c] = Tile(dc == 0 && dr == 0 ? TileType.base : TileType.brick);
      }
    }
    // 固定出生点格（保持空地）：敌方 row0 col 0/6/12，己方 row12 col 3/4/9/10
    const spawnCells = <List<int>>[
      [0, 0],
      [0, 6],
      [0, 12],
      [12, 3],
      [12, 4],
      [12, 9],
      [12, 10],
    ];
    // 其余格随机散布
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (tiles[r][c].type != TileType.empty) continue;
        if (spawnCells.any((sc) => sc[0] == r && sc[1] == c)) continue;
        final v = rng.nextDouble();
        TileType type;
        if (v < 0.40) {
          type = TileType.brick;
        } else if (v < 0.50) {
          type = TileType.steel;
        } else if (v < 0.62) {
          type = TileType.grass;
        } else if (v < 0.70) {
          type = TileType.water;
        } else {
          type = TileType.empty;
        }
        tiles[r][c] = Tile(type);
      }
    }
    return MapData(tiles);
  }

  static MapData parse(List<String> layout) {
    final tiles = <List<Tile>>[];
    for (final row in layout) {
      final line = <Tile>[];
      for (final ch in row.split('')) {
        final type = _charToType(ch);
        line.add(Tile(type));
      }
      tiles.add(line);
    }
    return MapData(tiles);
  }

  static TileType _charToType(String ch) => switch (ch) {
    'B' => TileType.brick,
    'S' => TileType.steel,
    'G' => TileType.grass,
    'W' => TileType.water,
    'E' => TileType.base,
    _ => TileType.empty,
  };

  Map<String, dynamic> toJson() => {
    'tiles': tiles.map((row) => row.map((t) => t.toJson()).toList()).toList(),
  };

  static MapData fromJson(Map<String, dynamic> json) {
    final raw = (json['tiles'] as List).cast<List>();
    final tiles = raw.map((row) {
      final list = row.cast<Map<String, dynamic>>();
      return list.map((t) => Tile.fromJson(t)).toList();
    }).toList();
    return MapData(tiles);
  }
}
