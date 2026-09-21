import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/tool/convert_utils.dart';

/// 坦克大战规则与尺寸配置。
///
/// 只存放跨模型、逻辑和渲染层共享的固定规则，避免各层散落魔法数字。
abstract final class TankGameConfig {
  static const int gridSize = 13;
  static const double tileSize = 40;
  static const double mapSize = gridSize * tileSize;

  static const List<Offset> enemySpawnPoints = [
    Offset(0.5 * tileSize, 0.5 * tileSize),
    Offset(6.5 * tileSize, 0.5 * tileSize),
    Offset(12.5 * tileSize, 0.5 * tileSize),
  ];

  static const List<Offset> playerSpawnPoints = [
    Offset(4.5 * tileSize, 12.5 * tileSize),
    Offset(10.5 * tileSize, 12.5 * tileSize),
    Offset(3.5 * tileSize, 12.5 * tileSize),
    Offset(9.5 * tileSize, 12.5 * tileSize),
  ];

  static const int playerLives = 3;
  static const int totalEnemyCount = 20;
  static const int maxEnemyOnField = 4;
  static const int maxPowerUps = 2;

  static const double simulationStep = 1 / 120;
  static const double maxFrameTime = 0.1;
  static const int maxCatchUpSteps = 12;
  static const double enemySpawnInterval = 1;
  static const double aiPlanMinDuration = 1.5;
  static const double aiPlanMaxDuration = 4;
  static const double aiDestinationReachedDistance = 6;
  static const double itemSpawnInterval = 25;
  static const double grassSpeedFactor = 0.5;
  static const double homingRange = tileSize * 4;
  static const double homingTurnRate = 5;

  static const double baseShieldDuration = 10;
  static const double fireBuffDuration = 8;
  static const double homingBuffDuration = 5;
  static const double playerShieldDuration = 10;
  static const double spawnInvincibleDuration = 2;
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

  // 基地配色（完好金鹰 / 被毁灰底）
  static const Color baseColor = Color(0xFFFFC107);
  static const Color baseDestroyedColor = Color(0xFF616161);

  // 颜色（空地透明由背景呈现，基地主色供完好态引用）
  Color get color => switch (this) {
    brick => const Color(0xFFB0682A),
    steel => const Color(0xFF9EA7B0),
    grass => const Color(0xFF4CAF50),
    water => const Color(0xFF2196F3),
    base => baseColor,
    empty => Colors.transparent,
  };

  /// 坦克是否阻挡（不可驶入）
  bool get blocksTank =>
      this == brick || this == steel || this == water || this == base;

  /// 子弹是否阻挡（命中即销毁子弹，砖墙随之受损）
  bool get blocksBullet => this == brick || this == steel || this == base;

  static TileType fromName(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => TileType.empty);
}

/// 值与默认值不同才写入 JSON，减少网络传输量。
/// 解析端统一用 `?? 默认值` 回填，两端约定一致。
void putIfNotDefault(
  Map<String, dynamic> json,
  String key,
  Object? value,
  Object? defaultValue,
) {
  if (value != defaultValue) json[key] = value;
}

/// 坦克序列化与玩家规格使用的默认值。
abstract final class TankDefaults {
  static const int health = 16;
  static const int damage = 8;
  static const double size = 32;
  static const double speed = 160;
  static const double fireInterval = 0.3;
  static const double respawnTime = 2;
  static const double invincibleTime = 2;
}

/// 一局游戏结束后的只读结果，由逻辑层发布、界面层展示。
class TankGameResult {
  final bool victory;
  final int score;

  const TankGameResult({required this.victory, required this.score});
}

/// AI 敌方坦克类型
enum EnemyType {
  basic,
  fast,
  power,
  armor;

  // 颜色
  Color get color => switch (this) {
    basic => const Color(0xFF8D6E63), // 灰褐
    fast => const Color(0xFFFF7043), // 橙
    power => const Color(0xFF8E24AA), // 紫
    armor => const Color(0xFFC62828), // 红
  };

  // 血量（basic 即标准规格）
  int get health => switch (this) {
    basic => TankDefaults.health,
    fast => 8,
    power => 12,
    armor => 60,
  };

  // 速度
  double get speed => switch (this) {
    basic => 80,
    fast => 160,
    power => 100,
    armor => 60,
  };

  /// 伤害（basic 即标准规格）
  int get damage => switch (this) {
    basic => TankDefaults.damage,
    fast => 4,
    power => 4,
    armor => 12,
  };

  /// 开火冷却（秒）
  double get fireInterval => switch (this) {
    basic => 0.8,
    fast => 0.6,
    power => 0.4,
    armor => 1.0,
  };

  /// 体型（basic 即标准规格）
  double get size => switch (this) {
    basic => TankDefaults.size,
    fast => 24,
    power => 28,
    armor => 40,
  };

  /// 满血参照（供渲染算装甲破损度）
  int get maxHealth => health;

  // 分数
  int get points => switch (this) {
    basic => 100,
    fast => 200,
    power => 300,
    armor => 400,
  };

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

  // 空地省略 type（解析端回填 empty），随机地图上大量空地格不参与传输
  Map<String, dynamic> toJson() =>
      type == TileType.empty ? {} : {'type': type.name};

  static Tile fromJson(Map<String, dynamic> json) =>
      Tile(TileType.fromName(json['type'] as String? ?? 'empty'));
}

/// 玩家类型（按序号区分多人配色）
enum PlayerType {
  p1, // 黄
  p2, // 绿
  p3, // 蓝
  p4 // 紫
  ;

  Color get color => switch (this) {
    p1 => const Color(0xFFFFD600),
    p2 => const Color(0xFF4CAF50),
    p3 => const Color(0xFF2196F3),
    p4 => const Color(0xFF9C27B0),
  };
}

/// 坦克
class Tank {
  Offset position; // 中心像素坐标
  double angle; // 车身朝向（弧度，0=右，顺时针为正）
  double turretAngle; // 炮塔朝向（弧度）

  int playerId; // >=0 为玩家序号，-1 为 AI
  Color color; // 颜色
  int health; // 血量
  int maxHealth; // 满血（重生恢复/渲染破损度参照）
  double size; // 体型
  double speed; // 移动速度（px/s）
  int damage; // 子弹伤害
  double fireInterval; // 开火冷却（秒）
  double respawnTime; // 被毁后重生延迟（秒）
  double invincibleTime; // 重生/出生后的无敌时长（秒）
  bool isAlive; // 是否存活
  double reloadTimer; // 开火冷却剩余
  double respawnTimer; // 重生倒计时（>0 表示待重生）
  double invincibleTimer; // 无敌剩余
  double fireBuffTimer; // 火焰子弹剩余（>0 期间伤害翻倍）
  double homingBuffTimer; // 自动跟踪剩余（>0 期间开火吸附）
  double playerShieldTimer; // 玩家护盾剩余（>0 抵消一次攻击）
  bool moving; // 是否正在移动（玩家松开停止，AI 持续）

  EnemyType? enemyType; // AI 专属
  Offset? aiDestination; // AI 当前移动目的地
  bool aiFiring; // AI 当前是否处于持续开火阶段
  double aiPlanTimer; // AI 当前行为计划剩余时间

  Tank({
    required this.position,
    required this.angle,
    required this.playerId,
    required this.color,
    this.turretAngle = -pi / 2,
    this.health = TankDefaults.health,
    this.maxHealth = TankDefaults.health,
    this.size = TankDefaults.size,
    this.speed = TankDefaults.speed,
    this.damage = TankDefaults.damage,
    this.fireInterval = TankDefaults.fireInterval,
    this.respawnTime = TankDefaults.respawnTime,
    this.invincibleTime = TankDefaults.invincibleTime,
    this.isAlive = true,
    this.reloadTimer = 0,
    this.respawnTimer = 0,
    this.invincibleTimer = 0,
    this.fireBuffTimer = 0,
    this.homingBuffTimer = 0,
    this.playerShieldTimer = 0,
    this.moving = true,
    this.enemyType,
    this.aiDestination,
    this.aiFiring = false,
    this.aiPlanTimer = 0,
  });

  factory Tank.player({
    required Offset position,
    required int playerId,
    required Color color,
  }) => Tank(
    position: position,
    angle: -pi / 2,
    turretAngle: -pi / 2,
    playerId: playerId,
    color: color,
    moving: false,
    invincibleTimer: TankGameConfig.spawnInvincibleDuration,
  );

  factory Tank.enemy({required Offset position, required EnemyType type}) =>
      Tank(
        position: position,
        angle: pi / 2,
        turretAngle: pi / 2,
        health: type.health,
        maxHealth: type.maxHealth,
        size: type.size,
        speed: type.speed,
        damage: type.damage,
        fireInterval: type.fireInterval,
        playerId: -1,
        color: type.color,
        enemyType: type,
        invincibleTimer: TankGameConfig.spawnInvincibleDuration,
      );

  bool get isPlayer => playerId >= 0;

  Rect get rect => Rect.fromCenter(center: position, width: size, height: size);

  bool get canFire => isAlive && reloadTimer <= 0;

  void updateTimers(double deltaTime) {
    reloadTimer = max(0, reloadTimer - deltaTime);
    invincibleTimer = max(0, invincibleTimer - deltaTime);
    fireBuffTimer = max(0, fireBuffTimer - deltaTime);
    homingBuffTimer = max(0, homingBuffTimer - deltaTime);
    playerShieldTimer = max(0, playerShieldTimer - deltaTime);
    aiPlanTimer = max(0, aiPlanTimer - deltaTime);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      // 必发字段（无合理默认值）
      'px': ConvertUtils.offsetToJson(position),
      'pid': playerId,
      'color': ConvertUtils.colorToJson(color),
    };
    final enemy = enemyType;
    if (enemy != null) json['enemy'] = enemy.name;
    // 与默认值相同的字段省略，减少网络传输；解析端按默认值回填
    putIfNotDefault(json, 'ang', angle, -pi / 2);
    putIfNotDefault(json, 'tAng', turretAngle, -pi / 2);
    putIfNotDefault(json, 'hp', health, TankDefaults.health);
    putIfNotDefault(json, 'mhp', maxHealth, TankDefaults.health);
    putIfNotDefault(json, 'sz', size, TankDefaults.size);
    putIfNotDefault(json, 'spd', speed, TankDefaults.speed);
    putIfNotDefault(json, 'dmg', damage, TankDefaults.damage);
    putIfNotDefault(json, 'fiv', fireInterval, TankDefaults.fireInterval);
    putIfNotDefault(json, 'rtm', respawnTime, TankDefaults.respawnTime);
    putIfNotDefault(json, 'ivt', invincibleTime, TankDefaults.invincibleTime);
    putIfNotDefault(json, 'reload', reloadTimer, 0.0);
    putIfNotDefault(json, 'alive', isAlive, true);
    putIfNotDefault(json, 'respawn', respawnTimer, 0.0);
    putIfNotDefault(json, 'invincible', invincibleTimer, 0.0);
    putIfNotDefault(json, 'fireBuff', fireBuffTimer, 0.0);
    putIfNotDefault(json, 'homingBuff', homingBuffTimer, 0.0);
    putIfNotDefault(json, 'playerShield', playerShieldTimer, 0.0);
    putIfNotDefault(json, 'moving', moving, true);
    if (aiDestination != null) {
      json['aiDest'] = ConvertUtils.offsetToJson(aiDestination!);
    }
    putIfNotDefault(json, 'aiFiring', aiFiring, false);
    putIfNotDefault(json, 'aiPlan', aiPlanTimer, 0.0);
    return json;
  }

  static Tank fromJson(Map<String, dynamic> json) => Tank(
    position: ConvertUtils.offsetFromJson(json['px'] as Map<String, dynamic>),
    angle: (json['ang'] as num?)?.toDouble() ?? -pi / 2,
    health: (json['hp'] as num?)?.toInt() ?? TankDefaults.health,
    maxHealth: (json['mhp'] as num?)?.toInt() ?? TankDefaults.health,
    size: (json['sz'] as num?)?.toDouble() ?? TankDefaults.size,
    speed: (json['spd'] as num?)?.toDouble() ?? TankDefaults.speed,
    damage: (json['dmg'] as num?)?.toInt() ?? TankDefaults.damage,
    fireInterval:
        (json['fiv'] as num?)?.toDouble() ?? TankDefaults.fireInterval,
    respawnTime: (json['rtm'] as num?)?.toDouble() ?? TankDefaults.respawnTime,
    invincibleTime:
        (json['ivt'] as num?)?.toDouble() ?? TankDefaults.invincibleTime,
    playerId: json['pid'] as int,
    color: ConvertUtils.colorFromJson(json['color'] as Map<String, dynamic>),
    turretAngle: (json['tAng'] as num?)?.toDouble() ?? -pi / 2,
    isAlive: json['alive'] as bool? ?? true,
    reloadTimer: (json['reload'] as num?)?.toDouble() ?? 0,
    respawnTimer: (json['respawn'] as num?)?.toDouble() ?? 0,
    invincibleTimer: (json['invincible'] as num?)?.toDouble() ?? 0,
    fireBuffTimer: (json['fireBuff'] as num?)?.toDouble() ?? 0,
    homingBuffTimer: (json['homingBuff'] as num?)?.toDouble() ?? 0,
    playerShieldTimer: (json['playerShield'] as num?)?.toDouble() ?? 0,
    moving: json['moving'] as bool? ?? true,
    enemyType: json['enemy'] == null
        ? null
        : EnemyType.fromName(json['enemy'] as String),
    aiDestination: json['aiDest'] == null
        ? null
        : ConvertUtils.offsetFromJson(json['aiDest'] as Map<String, dynamic>),
    aiFiring: json['aiFiring'] as bool? ?? false,
    aiPlanTimer: (json['aiPlan'] as num?)?.toDouble() ?? 0,
  );
}

/// 子弹
class Bullet {
  static const int baseDamage = 8; // 基础伤害
  static const Color playerColor = Color(0xFFFFEB3B); // 玩家子弹（黄）
  static const Color enemyColor = Color(0xFFFFFFFF); // 敌方子弹（白）

  Offset position;
  double angle; // 飞行方向（弧度）
  int ownerId; // 发射坦克的 key（玩家=identity，AI=负数）
  double size; // 直径
  int damage; // 伤害
  double speed; // 速度
  bool homing; // 跟踪弹：飞行中持续吸附范围内敌人
  int? targetKey; // 当前跟踪目标 tank key（null=暂未吸附）

  Bullet({
    required this.position,
    required this.angle,
    required this.ownerId,
    this.size = 8,
    this.damage = baseDamage,
    this.speed = 300,
    this.homing = false,
    this.targetKey,
  });

  Offset get velocity => Offset.fromDirection(angle) * speed;

  Rect get rect => Rect.fromCenter(center: position, width: size, height: size);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      // 必发字段（无合理默认值）
      'px': ConvertUtils.offsetToJson(position),
      'ang': angle,
      'owner': ownerId,
    };
    // 与默认值相同的字段省略；size/speed 补齐序列化（此前缺失会被丢弃）
    putIfNotDefault(json, 'sz', size, 8.0);
    putIfNotDefault(json, 'dmg', damage, baseDamage);
    putIfNotDefault(json, 'spd', speed, 300.0);
    putIfNotDefault(json, 'hmg', homing, false);
    putIfNotDefault(json, 'tgt', targetKey, null);
    return json;
  }

  static Bullet fromJson(Map<String, dynamic> json) => Bullet(
    position: ConvertUtils.offsetFromJson(json['px'] as Map<String, dynamic>),
    angle: (json['ang'] as num?)?.toDouble() ?? 0,
    ownerId: json['owner'] as int,
    size: (json['sz'] as num?)?.toDouble() ?? 8,
    damage: (json['dmg'] as num?)?.toInt() ?? baseDamage,
    speed: (json['spd'] as num?)?.toDouble() ?? 300,
    homing: json['hmg'] as bool? ?? false,
    targetKey: json['tgt'] as int?,
  );
}

/// 道具类型
enum PowerUpType {
  shield, // 基地护盾：基地一圈变 steel，10s 后变 brick
  fireBullet, // 火焰子弹：8s 内伤害翻倍
  homing, // 自动跟踪：5s 内子弹吸附敌人
  playerShield; // 玩家护盾：10s 内抵消一次攻击

  // 颜色
  Color get color => switch (this) {
    shield => const Color(0xFF29B6F6), // 蓝
    fireBullet => const Color(0xFFFF6E40), // 橙
    homing => const Color(0xFFAB47BC), // 紫
    playerShield => const Color(0xFF26A69A), // 青
  };

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
    width: TankGameConfig.tileSize * 0.7,
    height: TankGameConfig.tileSize * 0.7,
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
  double life;

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
          life: (random.nextDouble() * 0.5) + 0.33,
        ),
      );
    }
  }

  void update(double deltaTime) {
    alpha -= deltaTime * 2;
    for (var p in particles) {
      p.position += p.velocity * deltaTime * 60;
      p.life -= deltaTime;
    }
    particles.removeWhere((p) => p.life <= 0);
    finished = particles.isEmpty || alpha <= 0;
  }
}

/// 地图数据（13×13 网格）
class TankMap {
  final List<List<Tile>> tiles; // tiles[row][col]

  TankMap(this.tiles);

  int get rows => tiles.length;
  int get cols => tiles.isEmpty ? 0 : tiles.first.length;

  Rect get bounds =>
      const Rect.fromLTWH(0, 0, TankGameConfig.mapSize, TankGameConfig.mapSize);

  Rect get baseRect => Rect.fromCenter(
    center: baseCenter,
    width: TankGameConfig.tileSize,
    height: TankGameConfig.tileSize,
  );

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

  Tile tileAtPosition(Offset position) => tileAt(
    (position.dx / TankGameConfig.tileSize).floor(),
    (position.dy / TankGameConfig.tileSize).floor(),
  );

  bool containsRect(Rect rect) =>
      rect.left >= bounds.left &&
      rect.top >= bounds.top &&
      rect.right <= bounds.right &&
      rect.bottom <= bounds.bottom;

  bool blocksTank(Rect rect) {
    final firstCol = (rect.left / TankGameConfig.tileSize).floor();
    final lastCol = ((rect.right - 0.1) / TankGameConfig.tileSize).floor();
    final firstRow = (rect.top / TankGameConfig.tileSize).floor();
    final lastRow = ((rect.bottom - 0.1) / TankGameConfig.tileSize).floor();
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        if (tileAt(col, row).type.blocksTank) return true;
      }
    }
    return false;
  }

  void setBaseWall(TileType type) {
    final baseCol = (baseCenter.dx / TankGameConfig.tileSize).floor();
    final baseRow = (baseCenter.dy / TankGameConfig.tileSize).floor();
    for (var rowOffset = -1; rowOffset <= 1; rowOffset++) {
      for (var colOffset = -1; colOffset <= 1; colOffset++) {
        if (rowOffset == 0 && colOffset == 0) continue;
        final col = baseCol + colOffset;
        final row = baseRow + rowOffset;
        if (col < 0 || col >= cols || row < 0 || row >= rows) continue;
        if (tileAt(col, row).type != TileType.base) {
          setTileType(col, row, type);
        }
      }
    }
  }

  /// 基地中心（col=7, row=12）
  Offset get baseCenter => Offset(
    (7 + 0.5) * TankGameConfig.tileSize,
    (12 + 0.5) * TankGameConfig.tileSize,
  );

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

  static TankMap classic() => parse(_layout);

  /// 随机地图：基地+周围一圈砖墙与出生点固定，其余按概率散布
  static TankMap random(Random rng) {
    final tiles = List.generate(
      TankGameConfig.gridSize,
      (_) => List.generate(TankGameConfig.gridSize, (_) => Tile.empty()),
    );
    // 固定区：基地 + 周围一圈砖墙
    const baseCol = 7, baseRow = 12;
    for (final dc in <int>[-1, 0, 1]) {
      for (final dr in <int>[-1, 0, 1]) {
        final r = baseRow + dr, c = baseCol + dc;
        if (r < 0 ||
            r >= TankGameConfig.gridSize ||
            c < 0 ||
            c >= TankGameConfig.gridSize) {
          continue;
        }
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
    for (int r = 0; r < TankGameConfig.gridSize; r++) {
      for (int c = 0; c < TankGameConfig.gridSize; c++) {
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
    // 随机填充后开凿一组连通主干，确保所有出生点都能进入同一片战场。
    // 基地周围的砖墙仍保留，敌人需要正常击穿围墙才能攻击基地。
    const hub = (col: 6, row: 6);
    const requiredConnections = <({int col, int row})>[
      (col: 0, row: 0),
      (col: 6, row: 0),
      (col: 12, row: 0),
      (col: 3, row: 12),
      (col: 4, row: 12),
      (col: 9, row: 12),
      (col: 10, row: 12),
      (col: 7, row: 10),
    ];
    for (final point in requiredConnections) {
      _carvePath(tiles, point, hub);
    }
    return TankMap(tiles);
  }

  static void _carvePath(
    List<List<Tile>> tiles,
    ({int col, int row}) from,
    ({int col, int row}) to,
  ) {
    void clear(int col, int row) {
      final tile = tiles[row][col];
      if (tile.type != TileType.base) tile.type = TileType.empty;
    }

    var row = from.row;
    final rowStep = row <= to.row ? 1 : -1;
    while (row != to.row) {
      clear(from.col, row);
      row += rowStep;
    }
    clear(from.col, row);

    var col = from.col;
    final colStep = col <= to.col ? 1 : -1;
    while (col != to.col) {
      clear(col, to.row);
      col += colStep;
    }
    clear(col, to.row);
  }

  static TankMap parse(List<String> layout) {
    final tiles = <List<Tile>>[];
    for (final row in layout) {
      final line = <Tile>[];
      for (final ch in row.split('')) {
        final type = _charToType(ch);
        line.add(Tile(type));
      }
      tiles.add(line);
    }
    return TankMap(tiles);
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

  static TankMap fromJson(Map<String, dynamic> json) {
    final raw = (json['tiles'] as List).cast<List>();
    final tiles = raw.map((row) {
      final list = row.cast<Map<String, dynamic>>();
      return list.map((t) => Tile.fromJson(t)).toList();
    }).toList();
    return TankMap(tiles);
  }
}
