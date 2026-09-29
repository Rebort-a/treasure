import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../00.common/game/map.dart';
import '../00.common/model/notifiers.dart';
import 'base.dart';

/// 坦克大战共享游戏内核。
///
/// 同步模型：
/// - 所有端统一跑移动/子弹飞行/砖墙销毁（确定性，不依赖网络）。
/// - AI 决策（转向/开火/生成）与命中判定只在【权威方】执行，
///   通过 action 消息广播给其他端应用，避免各端重复扣血或 AI 发散。
/// - local：自己是权威；net：host 为权威，client 非权威。
abstract class TankGameManager extends ChangeNotifier
    implements TickerProvider {
  final Random _random = Random();

  /// 玩家坦克 key = identity；AI 坦克 key 为负数递减
  final Map<int, Tank> tanks = {};
  final List<Bullet> bullets = [];
  final List<Explosion> explosions = [];

  TankMap map = TankMap.classic();
  final List<PowerUp> powerups = [];

  final pageNavigator = AlwaysNotifier<void Function(BuildContext)>((_) {});
  final isRunning = ValueNotifier<bool>(false);
  final gameResult = ValueNotifier<TankGameResult?>(null);

  /// 各玩家剩余命数（key = 玩家坦克 key = identity）
  final Map<int, int> livesByPlayer = {};

  /// 各玩家当前固定出生点索引（被障碍占用时切换，切换后固定）
  final Map<int, int> playerSpawnUsed = {};

  /// 对局进度
  int remainingEnemies = TankGameConfig.totalEnemyCount;
  int enemiesOnField = 0;
  bool baseDestroyed = false;
  int score = 0;
  bool _gameOver = false;
  bool playerAiming = false; // 右摇杆按住持续开火（子类可写）
  double shieldTimer = 0; // 基地护盾剩余（>0 一圈为 steel，归零变 brick）

  int _enemyIdSeq = 0; // AI key 递减序列
  double _spawnTimer = 0;
  double _itemSpawnTimer = 0;

  late final Ticker _ticker;
  double _lastElapsed = 0;
  double _accumulator = 0;

  int get identity;
  bool get isAuthority;

  /// 联机模式下，权威端只生成并广播世界事件，等服务器回环后再应用。
  bool get deferAuthorityActions => false;

  int get pendingEnemySpawnCount => 0;
  int get pendingPowerUpSpawnCount => 0;
  bool isAiPlanPending(int tankKey) => false;
  bool isAiFirePending(int tankKey) => false;
  bool isPowerUpSpawnPending(Offset position) => false;
  bool isPowerUpPickupPending(Offset position) => false;

  // ---- 生命周期 ----

  void initTicker() {
    _ticker = createTicker(_gameLoop);
  }

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  void resumeGame() {
    isRunning.value = true;
    if (!_ticker.isActive) {
      _lastElapsed = 0;
      _accumulator = 0;
      _ticker.start();
    }
  }

  void suspendGame() {
    isRunning.value = false;
    if (_ticker.isActive) _ticker.stop();
  }

  void toggleState() {
    isRunning.value ? suspendGame() : resumeGame();
  }

  // ---- 游戏循环 ----

  void _gameLoop(Duration elapsed) {
    if (!isRunning.value) return;

    final currentElapsed =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final deltaTime = max(0.0, currentElapsed - _lastElapsed);
    _lastElapsed = currentElapsed;
    _accumulator += min(deltaTime, TankGameConfig.maxFrameTime);

    var steps = 0;
    while (_accumulator >= TankGameConfig.simulationStep &&
        steps < TankGameConfig.maxCatchUpSteps &&
        isRunning.value) {
      _simulateStep(TankGameConfig.simulationStep);
      _accumulator -= TankGameConfig.simulationStep;
      steps++;
    }
    if (steps == TankGameConfig.maxCatchUpSteps) {
      // 避免长时间卡顿后无限追帧；保留不足一个逻辑步的余量即可。
      _accumulator = min(_accumulator, TankGameConfig.simulationStep);
    }
    if (steps > 0) notifyListeners();
  }

  void _simulateStep(double dt) {
    _updateTanks(dt);
    _handlePlayerAutoFire();
    _updateBullets(dt);
    _checkBulletWallCollisions();
    _checkTankBulletHits();
    _updateExplosions(dt);
    _checkPowerUpPickup();
    _updateShield(dt);

    _updateAuthoritySystems(dt);

    _checkGameOver();
  }

  // ---- 坦克移动 ----

  void _updateTanks(double dt) {
    for (final entry in tanks.entries) {
      final tank = entry.value;
      if (!tank.isAlive) {
        if (tank.respawnTimer > 0) {
          tank.respawnTimer -= dt;
          if (tank.respawnTimer <= 0) _respawn(entry.key, tank);
        }
        continue;
      }
      tank.updateTimers(dt);
      if (!tank.isPlayer) {
        _updateAiMovement(tank, dt);
        continue;
      }
      if (!tank.moving) continue;
      tank.position = _resolveMovePosition(tank, dt);
    }
  }

  void _updateAiMovement(Tank tank, double dt) {
    final destination = tank.aiDestination;
    if (destination == null) return;
    final delta = destination - tank.position;
    tank.turretAngle = tank.angle;
    if (delta.distance <= TankGameConfig.aiDestinationReachedDistance) {
      tank
        ..position = destination
        ..moving = false;
      return;
    }

    tank.moving = true;

    var speed = tank.speed;
    if (map.tileAtPosition(tank.position).type == TileType.grass) {
      speed *= TankGameConfig.grassSpeedFactor;
    }
    final moveDistance = min(speed * dt, delta.distance);
    final nextPosition =
        tank.position + Offset.fromDirection(tank.angle) * moveDistance;
    if (_canMoveTo(nextPosition, tank)) {
      tank.position = nextPosition;
    } else {
      // 保留当前计划周期，避免被阻挡时每帧重新规划。
      tank
        ..aiDestination = tank.position
        ..moving = false;
    }
  }

  Offset _resolveMovePosition(Tank tank, double dt) {
    var speed = tank.speed;
    if (map.tileAtPosition(tank.position).type == TileType.grass) {
      speed *= TankGameConfig.grassSpeedFactor;
    }
    final move = Offset.fromDirection(tank.angle) * speed * dt;
    // 自由移动：沿当前方向直线行进，撞墙即停（不做轨道吸附）
    final newPos = tank.position + move;
    if (_canMoveTo(newPos, tank)) return newPos;

    // 撞墙：轴分离贴墙滑行，单轴位移不超过 speed*dt，杜绝撞墙加速
    final moveX = Offset(move.dx, 0);
    final moveY = Offset(0, move.dy);
    // 先主方向后次方向，尽量保留玩家移动意图
    final primary = move.dx.abs() >= move.dy.abs() ? moveX : moveY;
    final secondary = primary == moveX ? moveY : moveX;
    if (_canMoveTo(tank.position + primary, tank)) {
      return tank.position + primary;
    }
    if (_canMoveTo(tank.position + secondary, tank)) {
      return tank.position + secondary;
    }
    return tank.position;
  }

  /// 右摇杆按住时持续开火（受冷却节流）
  void _handlePlayerAutoFire() {
    if (!playerAiming) return;
    final t = tanks[identity];
    if (t != null && t.canFire) updatePlayerFire();
  }

  bool _canMoveTo(Offset newPos, Tank self) {
    final r = Rect.fromCenter(
      center: newPos,
      width: self.size,
      height: self.size,
    );
    if (!map.containsRect(r) || map.blocksTank(r)) return false;
    for (final other in tanks.values) {
      if (identical(other, self) || !other.isAlive) continue;
      if (other.rect.overlaps(r)) {
        // 已重叠（如重生叠加）允许脱开，仅阻止新进入的重叠
        if (!other.rect.overlaps(self.rect)) return false;
      }
    }
    return true;
  }

  // ---- 子弹 ----

  void _updateBullets(double dt) {
    for (final b in bullets) {
      // 跟踪弹：未吸附时持续尝试锁定范围内敌人
      if (b.homing && b.targetKey == null) {
        b.targetKey = _pickHomingTargetFor(b.ownerId >= 0, b.position);
      }
      if (b.targetKey != null) _steerBullet(b, dt);
      b.position += b.velocity * dt;
    }
    bullets.removeWhere(
      (b) =>
          b.position.dx < 0 ||
          b.position.dy < 0 ||
          b.position.dx > TankGameConfig.mapSize ||
          b.position.dy > TankGameConfig.mapSize,
    );
  }

  /// 跟踪子弹：朝目标旋转固定角速率；目标失效则脱锁，下帧重新吸附
  void _steerBullet(Bullet b, double dt) {
    final target = tanks[b.targetKey!];
    if (target == null || !target.isAlive) {
      b.targetKey = null;
      return;
    }
    final desired = (target.position - b.position).direction;
    final diff = _angleDiff(desired, b.angle);
    const turnRate = TankGameConfig.homingTurnRate;
    if (diff.abs() <= turnRate * dt) {
      b.angle = desired;
    } else {
      b.angle += turnRate * dt * diff.sign;
    }
  }

  /// 角度差 a-b 归一到 [-pi, pi]
  double _angleDiff(double a, double b) {
    var d = (a - b) % (2 * pi);
    if (d > pi) d -= 2 * pi;
    if (d < -pi) d += 2 * pi;
    return d;
  }

  /// 子弹-墙：销毁砖墙/钢墙挡弹（所有端确定性执行）
  void _checkBulletWallCollisions() {
    bullets.removeWhere((b) {
      final col = (b.position.dx / TankGameConfig.tileSize).floor();
      final row = (b.position.dy / TankGameConfig.tileSize).floor();
      final tile = map.tileAt(col, row);
      switch (tile.type) {
        case TileType.brick:
          tile.type = TileType.empty;
          return true;
        case TileType.steel:
          // 强化子弹（满级/火焰）可毁钢墙
          if (b.damage > Bullet.baseDamage) tile.type = TileType.empty;
          return true;
        case TileType.base:
          // 基地碰撞由坦克/基地命中流程统一仲裁，不能在扣血前删弹。
          return false;
        default:
          return false;
      }
    });
  }

  /// 子弹-坦克/base 命中：所有端销毁子弹，仅权威方判定扣血并广播
  void _checkTankBulletHits() {
    final toRemove = <Bullet>{};
    for (final b in bullets) {
      int? hitKey;
      var hitBase = false;

      for (final entry in tanks.entries) {
        final tank = entry.value;
        if (!tank.isAlive || tank.invincibleTimer > 0) continue;
        if (!b.rect.overlaps(tank.rect)) continue;
        // 合作模式：玩家子弹只伤 AI，AI 子弹只伤玩家（无友伤）
        final sameSide = (b.ownerId >= 0) == (tank.playerId >= 0);
        if (sameSide) continue;
        hitKey = entry.key;
        break;
      }

      if (hitKey == null && !baseDestroyed) {
        hitBase = b.rect.overlaps(map.baseRect);
      }

      if (hitKey != null || hitBase) {
        toRemove.add(b);
        if (_isAuthorityForBullet(b)) {
          if (hitKey != null) {
            if (deferAuthorityActions) {
              broadcastHit(hitKey, false, b.damage, b.ownerId);
            } else {
              applyConfirmedHit(hitKey, b.damage);
            }
          } else {
            if (deferAuthorityActions) {
              broadcastHit(-1, true, b.damage, b.ownerId);
            } else {
              applyBaseHit();
            }
          }
        }
      }
    }
    if (toRemove.isNotEmpty) bullets.removeWhere(toRemove.contains);
  }

  /// 该子弹的命中是否由本端权威判定
  bool _isAuthorityForBullet(Bullet b) {
    if (b.ownerId >= 0) return b.ownerId == identity; // 玩家子弹：拥有者权威
    return isAuthority; // AI 子弹：host 权威
  }

  /// 应用命中（扣血/销毁/爆炸），返回是否致死；纯本地状态变更
  bool applyHit(int tankKey, [int damage = Bullet.baseDamage]) {
    final tank = tanks[tankKey];
    if (tank == null || !tank.isAlive) return false;
    // 玩家护盾抵消一次攻击
    if (tank.playerShieldTimer > 0) {
      tank.playerShieldTimer = 0;
      return false;
    }
    tank.health -= damage;
    if (tank.health <= 0) {
      tank.isAlive = false;
      _addExplosion(tank.position, tank.size);
      if (tank.isPlayer) {
        final lives = livesByPlayer[tankKey] ?? 0;
        final remainingLives = max(0, lives - 1);
        livesByPlayer[tankKey] = remainingLives;
        if (remainingLives > 0) {
          tank.respawnTimer = tank.respawnTime;
        }
      } else {
        enemiesOnField--;
        score += tank.enemyType?.points ?? 0;
      }
      return true;
    }
    return false;
  }

  /// 应用服务器确认后的坦克命中。仅当前权威端负责决定死亡掉落。
  bool applyConfirmedHit(int tankKey, [int damage = Bullet.baseDamage]) {
    final killed = applyHit(tankKey, damage);
    if (killed && tankKey < 0 && isAuthority) {
      final enemy = tanks[tankKey];
      if (enemy != null) _maybeDropPowerUp(enemy);
    }
    return killed;
  }

  /// AI 死亡掉落道具（仅权威端调用，避免各端重复生成）
  void _maybeDropPowerUp(Tank enemy) {
    final rate = enemy.enemyType?.dropRate ?? 0;
    if (_random.nextDouble() >= rate) return;
    final type = PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
    final p = PowerUp(position: enemy.position, type: type);
    if (deferAuthorityActions) {
      broadcastSpawnItem(p);
    } else {
      applySpawnItem(p);
    }
  }

  void applyBaseHit() {
    if (baseDestroyed) return;
    baseDestroyed = true;
    final col = (map.baseCenter.dx / TankGameConfig.tileSize).floor();
    final row = (map.baseCenter.dy / TankGameConfig.tileSize).floor();
    map.setTileType(col, row, TileType.empty);
    _addExplosion(map.baseCenter);
  }

  void _respawn(int key, Tank tank) {
    tank.position = _resolveSpawnPoint(key);
    tank.angle = -pi / 2;
    tank.turretAngle = -pi / 2;
    tank.health = tank.maxHealth;
    tank.isAlive = true;
    tank.invincibleTimer = tank.invincibleTime;
    tank.reloadTimer = 0;
    // 复活重置个人 buff（基地护盾属 base，不随玩家清除）
    tank.fireBuffTimer = 0;
    tank.homingBuffTimer = 0;
    tank.playerShieldTimer = 0;
  }

  // ---- 爆炸 ----

  void _addExplosion(Offset position, [double size = 32]) {
    explosions.add(Explosion(position: position, size: size));
  }

  void _updateExplosions(double dt) {
    for (final e in explosions) {
      e.update(dt);
    }
    explosions.removeWhere((e) => e.finished);
  }

  // ---- 玩家生成 helper ----

  /// 创建并加入玩家坦克（local/host 用；client 从快照反序列化）
  void addPlayerTank(int key) {
    final pid = key % PlayerType.values.length;
    final type = PlayerType.values[pid];
    tanks[key] = Tank.player(
      position: _resolveSpawnPoint(key),
      playerId: pid,
      color: type.color,
    );
    livesByPlayer[key] = TankGameConfig.playerLives;
  }

  /// 选可用出生点：当前固定点优先，被障碍占用则切换到另一可用点并固定
  Offset _resolveSpawnPoint(int playerKey) {
    var idx =
        playerSpawnUsed[playerKey] ??
        (playerKey % TankGameConfig.playerSpawnPoints.length);
    if (_isSpawnClear(TankGameConfig.playerSpawnPoints[idx])) {
      playerSpawnUsed[playerKey] = idx;
      return TankGameConfig.playerSpawnPoints[idx];
    }
    for (int i = 1; i < TankGameConfig.playerSpawnPoints.length; i++) {
      final ni = (idx + i) % TankGameConfig.playerSpawnPoints.length;
      if (_isSpawnClear(TankGameConfig.playerSpawnPoints[ni])) {
        playerSpawnUsed[playerKey] = ni;
        return TankGameConfig.playerSpawnPoints[ni];
      }
    }
    return TankGameConfig.playerSpawnPoints[idx];
  }

  /// 出生点是否空闲（不越界/不撞墙/不被其他坦克占用）
  bool _isSpawnClear(Offset pos, {Tank? ignore}) {
    final r = Rect.fromCenter(center: pos, width: 32, height: 32);
    if (!map.containsRect(r) || map.blocksTank(r)) return false;
    for (final other in tanks.values) {
      if (identical(other, ignore) || !other.isAlive) continue;
      if (other.rect.overlaps(r)) return false;
    }
    return true;
  }

  // ---- 开火 ----

  Bullet? buildBullet(int key, Tank tank) {
    if (!tank.canFire) return null;
    var damage = tank.damage;
    if (tank.fireBuffTimer > 0) damage *= 2;
    final homing = tank.homingBuffTimer > 0;
    return Bullet(
      position:
          tank.position +
          Offset.fromDirection(tank.turretAngle) * tank.size * 0.6,
      angle: tank.turretAngle,
      ownerId: key,
      damage: damage,
      homing: homing,
      targetKey: homing
          ? _pickHomingTargetFor(tank.isPlayer, tank.position)
          : null,
    );
  }

  void applyFire(int key, Bullet bullet) {
    final tank = tanks[key];
    if (tank == null || !tank.isAlive) return;
    tank.reloadTimer = tank.fireInterval;
    bullets.add(bullet);
  }

  Bullet? fire(int key, Tank tank) {
    final bullet = buildBullet(key, tank);
    if (bullet == null) return null;
    applyFire(key, bullet);
    return bullet;
  }

  /// 跟踪目标选择：范围内最近的异阵营坦克
  int? _pickHomingTargetFor(bool shooterIsPlayer, Offset from) {
    const range = TankGameConfig.homingRange;
    int? bestKey;
    var bestDist = range;
    for (final entry in tanks.entries) {
      final t = entry.value;
      if (!t.isAlive || t.isPlayer == shooterIsPlayer) continue;
      final d = (t.position - from).distance;
      if (d <= bestDist) {
        bestDist = d;
        bestKey = entry.key;
      }
    }
    return bestKey;
  }

  // ---- 权威方调度（local + host 执行；client 因 isAuthority=false 自动跳过） ----

  void _updateAuthoritySystems(double dt) {
    _updateSpawning(dt);
    _updateAiDecision();
    _updateItemSpawning(dt);
  }

  void _updateSpawning(double dt) {
    if (!isAuthority) return;
    _spawnTimer += dt;
    if (_spawnTimer >= TankGameConfig.enemySpawnInterval &&
        enemiesOnField + pendingEnemySpawnCount <
            TankGameConfig.maxEnemyOnField &&
        remainingEnemies - pendingEnemySpawnCount > 0) {
      _spawnTimer = 0;
      _spawnEnemy();
    }
  }

  void _spawnEnemy() {
    if (remainingEnemies <= 0) return;
    final types = EnemyType.values;
    final type = types[_random.nextInt(types.length)];
    // 随机找一个空闲出生点，全占满则放弃本次出生
    final order = List.of(TankGameConfig.enemySpawnPoints)..shuffle(_random);
    Offset? pos;
    for (final p in order) {
      if (_isSpawnClear(p)) {
        pos = p;
        break;
      }
    }
    if (pos == null) return;
    final tank = Tank.enemy(position: pos, type: type);
    final key = --_enemyIdSeq;
    if (deferAuthorityActions) {
      broadcastSpawn(key, tank);
    } else {
      applyEnemySpawn(key, tank);
    }
  }

  void applyEnemySpawn(int key, Tank tank) {
    if (tanks.containsKey(key) || tank.isPlayer || remainingEnemies <= 0) {
      return;
    }
    tanks[key] = tank;
    enemiesOnField++;
    remainingEnemies--;
  }

  void _updateAiDecision() {
    if (!isAuthority) return;
    for (final entry in tanks.entries) {
      final tank = entry.value;
      if (!tank.isAlive || tank.isPlayer) continue;
      if (tank.aiPlanTimer <= 0 && !isAiPlanPending(entry.key)) {
        _planAi(entry.key, tank);
      }
      if (tank.aiFiring &&
          tank.canFire &&
          !isAiPlanPending(entry.key) &&
          !isAiFirePending(entry.key)) {
        final bullet = buildBullet(entry.key, tank);
        if (bullet != null) {
          if (deferAuthorityActions) {
            broadcastAiFire(entry.key, bullet);
          } else {
            applyFire(entry.key, bullet);
          }
        }
      }
    }
  }

  void _planAi(int key, Tank tank) {
    final plan = _pickAiPlanDestination(tank);
    final firing = _random.nextDouble() < 0.55;
    final duration =
        TankGameConfig.aiPlanMinDuration +
        _random.nextDouble() *
            (TankGameConfig.aiPlanMaxDuration -
                TankGameConfig.aiPlanMinDuration);

    if (deferAuthorityActions) {
      broadcastAiPlan(key, plan.destination, plan.direction, firing, duration);
    } else {
      applyAiPlan(key, plan.destination, plan.direction, firing, duration);
    }
  }

  ({Offset destination, Direction direction}) _pickAiPlanDestination(
    Tank tank,
  ) {
    final directions = <Direction>[];
    final target = _pickAiTargetPosition(tank);
    if (target != null) {
      final delta = target - tank.position;
      if (delta.dx != 0 || delta.dy != 0) {
        final horizontal = delta.dx >= 0 ? Direction.right : Direction.left;
        final vertical = delta.dy >= 0 ? Direction.down : Direction.up;
        if (delta.dx.abs() >= delta.dy.abs()) {
          directions.addAll([horizontal, vertical]);
        } else {
          directions.addAll([vertical, horizontal]);
        }
      }
    }

    final remaining =
        Direction.values
            .where((direction) => !directions.contains(direction))
            .toList()
          ..shuffle(_random);
    directions.addAll(remaining);

    for (final direction in directions) {
      final desiredDistance =
          TankGameConfig.tileSize * (2 + _random.nextDouble() * 4);
      final destination = _furthestAiDestination(
        tank,
        direction,
        desiredDistance,
      );
      if ((destination - tank.position).distance >= TankGameConfig.tileSize) {
        return (destination: destination, direction: direction);
      }
    }

    return (
      destination: tank.position,
      direction: _nearestCardinalDirection(tank.angle),
    );
  }

  Offset _furthestAiDestination(
    Tank tank,
    Direction direction,
    double desiredDistance,
  ) {
    final step = max(8.0, tank.size * 0.5);
    var destination = tank.position;
    for (
      double traveled = step;
      traveled <= desiredDistance + step;
      traveled += step
    ) {
      final distance = min(traveled, desiredDistance);
      final candidate = tank.position + direction.vector * distance;
      if (!_canMoveTo(candidate, tank)) break;
      destination = candidate;
      if (distance >= desiredDistance) break;
    }
    return destination;
  }

  Direction _nearestCardinalDirection(double angle) {
    final vector = Offset.fromDirection(angle);
    if (vector.dx.abs() >= vector.dy.abs()) {
      return vector.dx >= 0 ? Direction.right : Direction.left;
    }
    return vector.dy >= 0 ? Direction.down : Direction.up;
  }

  Offset? _pickAiTargetPosition(Tank tank) {
    Offset? best;
    var bestDistance = double.infinity;
    for (final candidate in tanks.values) {
      if (!candidate.isAlive || !candidate.isPlayer) continue;
      final distance = (candidate.position - tank.position).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate.position;
      }
    }
    return best ?? map.baseCenter;
  }

  void applyAiPlan(
    int tankKey,
    Offset destination,
    Direction direction,
    bool firing,
    double duration,
  ) {
    final tank = tanks[tankKey];
    if (tank == null || tank.isPlayer || !tank.isAlive) return;
    final delta = destination - tank.position;
    final travel = max(
      0.0,
      delta.dx * direction.vector.dx + delta.dy * direction.vector.dy,
    );
    final alignedDestination = tank.position + direction.vector * travel;
    tank
      ..aiDestination = alignedDestination
      ..aiFiring = firing
      ..aiPlanTimer = duration
      ..angle = direction.angle
      ..turretAngle = direction.angle
      ..moving = alignedDestination != tank.position;
  }

  // ---- 道具 ----

  void _updateItemSpawning(double dt) {
    if (!isAuthority) return;
    _itemSpawnTimer += dt;
    if (_itemSpawnTimer >= TankGameConfig.itemSpawnInterval &&
        powerups.length + pendingPowerUpSpawnCount <
            TankGameConfig.maxPowerUps) {
      _itemSpawnTimer = 0;
      _spawnRandomItem();
    }
  }

  void _spawnRandomItem() {
    for (int i = 0; i < 50; i++) {
      final c = _random.nextInt(TankGameConfig.gridSize);
      final r = _random.nextInt(TankGameConfig.gridSize);
      if (map.tileAt(c, r).type != TileType.empty) continue;
      final pos = Offset(
        (c + 0.5) * TankGameConfig.tileSize,
        (r + 0.5) * TankGameConfig.tileSize,
      );
      if (!_isSpawnClear(pos)) continue;
      if (isPowerUpSpawnPending(pos)) continue;
      final type =
          PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
      final p = PowerUp(position: pos, type: type);
      if (deferAuthorityActions) {
        broadcastSpawnItem(p);
      } else {
        applySpawnItem(p);
      }
      return;
    }
  }

  void applySpawnItem(PowerUp powerUp) {
    final exists = powerups.any(
      (item) => item.type == powerUp.type && item.position == powerUp.position,
    );
    if (!exists) powerups.add(powerUp);
  }

  /// 仅权威方检测拾取并广播，各端收到 pickup 后应用效果
  void _checkPowerUpPickup() {
    if (!isAuthority) return;
    for (final p in powerups.toList()) {
      if (isPowerUpPickupPending(p.position)) continue;
      for (final entry in tanks.entries) {
        final t = entry.value;
        if (!t.isAlive || !t.isPlayer) continue;
        if (!t.rect.overlaps(p.rect)) continue;
        if (deferAuthorityActions) {
          broadcastPickup(entry.key, p.type, p.position);
        } else {
          applyConfirmedPickup(entry.key, p.type, p.position);
        }
        break;
      }
    }
  }

  void applyConfirmedPickup(int playerKey, PowerUpType type, Offset position) {
    powerups.removeWhere(
      (item) =>
          (item.position - position).distance < TankGameConfig.tileSize / 2,
    );
    applyPowerUp(playerKey, type);
  }

  void applyPowerUp(int playerKey, PowerUpType type) {
    final t = tanks[playerKey];
    switch (type) {
      case PowerUpType.shield:
        _activateShield();
        break;
      case PowerUpType.fireBullet:
        if (t != null) t.fireBuffTimer = TankGameConfig.fireBuffDuration;
        break;
      case PowerUpType.homing:
        if (t != null) t.homingBuffTimer = TankGameConfig.homingBuffDuration;
        break;
      case PowerUpType.playerShield:
        if (t != null) {
          t.playerShieldTimer = TankGameConfig.playerShieldDuration;
        }
        break;
    }
  }

  void _activateShield() {
    shieldTimer = TankGameConfig.baseShieldDuration;
    map.setBaseWall(TileType.steel);
  }

  void _updateShield(double dt) {
    if (shieldTimer <= 0) return;
    shieldTimer -= dt;
    if (shieldTimer > 0) return;
    shieldTimer = 0;
    map.setBaseWall(TileType.brick);
  }

  // ---- 胜负 ----

  void _checkGameOver() {
    if (_gameOver) return;
    var win = false;
    var lose = false;
    if (baseDestroyed) lose = true;
    if (remainingEnemies <= 0 && enemiesOnField <= 0) win = true;
    // 所有玩家坦克均已死亡且无人还有命数 → 失败
    if (livesByPlayer.isNotEmpty) {
      final players = tanks.values.where((t) => t.isPlayer);
      final anyAlive = players.any((t) => t.isAlive);
      final anyLives = livesByPlayer.values.any((l) => l > 0);
      if (!anyAlive && !anyLives) lose = true;
    }
    if (win || lose) _handleGameOver(win, score);
  }

  /// 重置全部状态（不含玩家重建与恢复运行）
  void resetState() {
    // NetTankManager 的 authority 身份由当前玩家坦克推导，必须在清空 tanks
    // 之前保存；否则联机 Host 重开时会被误判为非权威端。
    final shouldGenerateMap = isAuthority;
    _gameOver = false;
    gameResult.value = null;
    baseDestroyed = false;
    score = 0;
    remainingEnemies = TankGameConfig.totalEnemyCount;
    enemiesOnField = 0;
    _enemyIdSeq = 0;
    _spawnTimer = 0;
    _itemSpawnTimer = 0;
    shieldTimer = 0;
    tanks.clear();
    bullets.clear();
    explosions.clear();
    powerups.clear();
    livesByPlayer.clear();
    playerSpawnUsed.clear();
    map = shouldGenerateMap ? TankMap.random(_random) : TankMap.classic();
    _lastElapsed = 0;
    _accumulator = 0;
  }

  /// 单机重开：重置状态 + 重建玩家 + 恢复运行
  void resetGame() {
    resetState();
    addPlayerTank(identity);
    resumeGame();
  }

  void _handleGameOver(bool victory, int finalScore) {
    _gameOver = true;
    suspendGame();
    gameResult.value = TankGameResult(victory: victory, score: finalScore);
  }

  // ---- 序列化（resource 全量快照，加入时一次性同步） ----

  Map<String, dynamic> toJson() => {
    'map': map.toJson(),
    'tanks': tanks.map((k, v) => MapEntry(k.toString(), v.toJson())),
    'bullets': bullets.map((b) => b.toJson()).toList(),
    'powerups': powerups.map((p) => p.toJson()).toList(),
    'lives': livesByPlayer.map((k, v) => MapEntry(k.toString(), v)),
    'spawnUsed': playerSpawnUsed.map((k, v) => MapEntry(k.toString(), v)),
    'remaining': remainingEnemies,
    'onField': enemiesOnField,
    'baseDestroyed': baseDestroyed,
    'score': score,
    'enemySeq': _enemyIdSeq,
    'shieldTimer': shieldTimer,
    'itemSpawnTimer': _itemSpawnTimer,
  };

  void fromJson(Map<String, dynamic> json) {
    _gameOver = false;
    gameResult.value = null;
    playerAiming = false;
    explosions.clear();
    map = TankMap.fromJson(json['map'] as Map<String, dynamic>);
    tanks.clear();
    (json['tanks'] as Map<String, dynamic>).forEach((k, v) {
      tanks[int.parse(k)] = Tank.fromJson(v as Map<String, dynamic>);
    });
    bullets
      ..clear()
      ..addAll(
        (json['bullets'] as List)
            .map((b) => Bullet.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
    powerups
      ..clear()
      ..addAll(
        (json['powerups'] as List? ?? const [])
            .map((p) => PowerUp.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
    livesByPlayer.clear();
    (json['lives'] as Map<String, dynamic>).forEach((k, v) {
      livesByPlayer[int.parse(k)] = v as int;
    });
    playerSpawnUsed.clear();
    (json['spawnUsed'] as Map<String, dynamic>?)?.forEach((k, v) {
      playerSpawnUsed[int.parse(k)] = v as int;
    });
    remainingEnemies = json['remaining'] as int;
    enemiesOnField = json['onField'] as int;
    baseDestroyed = json['baseDestroyed'] as bool;
    score = json['score'] as int;
    _enemyIdSeq = json['enemySeq'] as int;
    shieldTimer = (json['shieldTimer'] as num?)?.toDouble() ?? 0;
    _itemSpawnTimer = (json['itemSpawnTimer'] as num?)?.toDouble() ?? 0;
  }

  // ---- 抽象钩子 ----

  /// 玩家移动方向输入（弧度）：local 直接改本地，net 发 action 转发。
  /// 右摇杆未使用时，炮塔跟随车身方向。
  void updatePlayerMove(double angle);

  /// 玩家瞄准（弧度）并持续开火（右摇杆按住）：local 改本地，net 转发
  void updatePlayerAim(double angle);

  /// 玩家停止瞄准（右摇杆松开）
  void updatePlayerAimStop();

  /// 玩家单次开火：local 直接 fire，net 发 action 转发
  void updatePlayerFire();

  /// 玩家停止移动：local 设 moving=false，net 发 action 转发
  void updatePlayerStop();

  void leavePage();

  // 广播钩子（local 全部空实现；net 发 action）
  void broadcastAiPlan(
    int tankKey,
    Offset destination,
    Direction direction,
    bool firing,
    double duration,
  ) {}
  void broadcastAiFire(int tankKey, Bullet bullet) {}
  void broadcastSpawn(int tankKey, Tank tank) {}
  void broadcastHit(int tankKey, bool isBase, int damage, int ownerId) {}
  void broadcastSpawnItem(PowerUp p) {}
  void broadcastPickup(int playerKey, PowerUpType type, Offset position) {}

  @override
  void dispose() {
    _ticker.dispose();
    isRunning.dispose();
    gameResult.dispose();
    pageNavigator.dispose();
    super.dispose();
  }
}
