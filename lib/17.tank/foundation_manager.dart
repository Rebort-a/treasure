import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../00.common/l10n/strings.dart';
import '../00.common/tool/notifiers.dart';
import 'base.dart';

/// 坦克大战共享逻辑基类。
///
/// 同步模型（方案 B，贴合贪吃蛇）：
/// - 所有端统一跑移动/子弹飞行/砖墙销毁（确定性，不依赖网络）。
/// - AI 决策（转向/开火/生成）与命中判定只在【权威方】执行，
///   通过 action 消息广播给其他端应用，避免各端重复扣血或 AI 发散。
/// - local：自己是权威；net：host 为权威，client 非权威。
abstract class FoundationalTankManager extends ChangeNotifier
    implements TickerProvider {
  final Random _random = Random();

  /// 玩家坦克 key = identity；AI 坦克 key 为负数递减
  final Map<int, Tank> tanks = {};
  final List<Bullet> bullets = [];
  final List<Explosion> explosions = [];

  MapData map = MapData.classic();
  final List<PowerUp> powerups = [];

  final pageNavigator = AlwaysNotifier<void Function(BuildContext)>((_) {});
  final gameState = ValueNotifier<bool>(false);

  /// 各玩家剩余命数（key = 玩家坦克 key = identity）
  final Map<int, int> livesByPlayer = {};

  /// 各玩家当前固定出生点索引（被障碍占用时切换，切换后固定）
  final Map<int, int> playerSpawnUsed = {};

  /// 对局进度
  int remainingEnemies = totalEnemyCount;
  int enemiesOnField = 0;
  bool baseDestroyed = false;
  int score = 0;
  bool _gameOver = false;
  bool playerAiming = false; // 右摇杆按住持续开火（子类可写）
  double shieldTimer = 0; // 基地护盾剩余（>0 一圈为 steel，归零变 brick）

  int _enemyIdSeq = 0; // AI key 递减序列
  double _spawnTimer = 0;
  double _aiDecisionTimer = 0;
  double _itemSpawnTimer = 0;

  late final Ticker _ticker;
  double _lastElapsed = 0;

  int get identity;
  bool get isAuthority;

  // ---- 生命周期 ----

  void initTicker() {
    _ticker = createTicker(_gameLoop);
  }

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  void resumeGame() {
    gameState.value = true;
    _ticker.start();
  }

  void suspendGame() {
    gameState.value = false;
    if (_ticker.isActive) _ticker.stop();
  }

  void toggleState() {
    gameState.value ? suspendGame() : resumeGame();
  }

  // ---- 游戏循环 ----

  void _gameLoop(Duration elapsed) {
    if (!gameState.value) return;

    final currentElapsed = elapsed.inMilliseconds / 1000.0;
    final deltaTime = currentElapsed - _lastElapsed;
    _lastElapsed = currentElapsed;
    final dt = deltaTime.clamp(0.004, 0.02);

    _updateTanks(dt);
    _handlePlayerAutoFire();
    _updateBullets(dt);
    _checkBulletWallCollisions();
    _checkTankBulletHits();
    _updateExplosions(dt);
    _checkPowerUpPickup();
    _updateShield(dt);

    handleTickerCallback(dt); // 权威方：AI 决策 + 刷怪 + 道具刷新；client 空实现

    _checkGameOver();
    notifyListeners();
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
      if (tank.reloadTimer > 0) tank.reloadTimer -= dt;
      if (tank.invincibleTimer > 0) tank.invincibleTimer -= dt;
      if (tank.fireBuffTimer > 0) tank.fireBuffTimer -= dt;
      if (tank.homingBuffTimer > 0) tank.homingBuffTimer -= dt;
      if (tank.playerShieldTimer > 0) tank.playerShieldTimer -= dt;
      if (!tank.moving) continue;

      var speed = tank.isPlayer
          ? tankSpeed
          : (tank.enemyType?.speed ?? tankSpeed);
      // 草地减速 50%
      final cellCol = (tank.position.dx / tileSize).floor();
      final cellRow = (tank.position.dy / tileSize).floor();
      if (map.tileAt(cellCol, cellRow).type == TileType.grass) {
        speed *= 0.5;
      }
      final move = Offset.fromDirection(tank.angle) * speed * dt;
      // 自由移动：沿当前方向直线行进，撞墙即停（不做轨道吸附）
      final newPos = tank.position + move;
      if (_canMoveTo(newPos, tank)) {
        tank.position = newPos;
      } else {
        // 撞墙：轴分离贴墙滑行，单轴位移不超过 speed*dt，杜绝撞墙加速
        final moveX = Offset(move.dx, 0);
        final moveY = Offset(0, move.dy);
        // 先主方向后次方向，尽量保留玩家移动意图
        final primary = move.dx.abs() >= move.dy.abs() ? moveX : moveY;
        final secondary = primary == moveX ? moveY : moveX;
        if (_canMoveTo(tank.position + primary, tank)) {
          tank.position = tank.position + primary;
        } else if (_canMoveTo(tank.position + secondary, tank)) {
          tank.position = tank.position + secondary;
        }
      }
    }
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
    if (r.left < 0 || r.top < 0 || r.right > mapSize || r.bottom > mapSize) {
      return false;
    }
    if (_rectBlockedByMap(r)) return false;
    for (final other in tanks.values) {
      if (identical(other, self) || !other.isAlive) continue;
      if (other.rect.overlaps(r)) {
        // 已重叠（如重生叠加）允许脱开，仅阻止新进入的重叠
        if (!other.rect.overlaps(self.rect)) return false;
      }
    }
    return true;
  }

  bool _rectBlockedByMap(Rect r) {
    final c0 = (r.left / tileSize).floor();
    final c1 = ((r.right - 0.1) / tileSize).floor();
    final r0 = (r.top / tileSize).floor();
    final r1 = ((r.bottom - 0.1) / tileSize).floor();
    for (int row = r0; row <= r1; row++) {
      for (int col = c0; col <= c1; col++) {
        if (map.tileAt(col, row).type.blocksTank) return true;
      }
    }
    return false;
  }

  // ---- 子弹 ----

  void _updateBullets(double dt) {
    for (final b in bullets) {
      if (b.targetKey != null) _steerBullet(b, dt);
      b.position += b.velocity * dt;
    }
    bullets.removeWhere(
      (b) =>
          b.position.dx < 0 ||
          b.position.dy < 0 ||
          b.position.dx > mapSize ||
          b.position.dy > mapSize,
    );
  }

  /// 跟踪子弹：朝目标旋转固定角速率，目标失效则退化为直线
  void _steerBullet(Bullet b, double dt) {
    final target = tanks[b.targetKey!];
    if (target == null || !target.isAlive) {
      b.targetKey = null;
      return;
    }
    final desired = (target.position - b.position).direction;
    final diff = _angleDiff(desired, b.angle);
    const turnRate = 5.0; // rad/s
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
      final col = (b.position.dx / tileSize).floor();
      final row = (b.position.dy / tileSize).floor();
      final tile = map.tileAt(col, row);
      switch (tile.type) {
        case TileType.brick:
        tile.type = TileType.empty;
        return true;
        case TileType.steel:
          // 满级玩家子弹可毁钢墙
          if (b.damage >= 2) tile.type = TileType.empty;
          return true;
        case TileType.base:
          return true; // base 命中由 hit 流程处理，这里仅销毁子弹
        default:
          return false;
      }
    });
  }

  /// 子弹-坦克/base 命中：所有端销毁子弹，仅权威方判定扣血并广播
  void _checkTankBulletHits() {
    final toRemove = <Bullet>[];
    for (final b in bullets) {
      if (toRemove.contains(b)) continue;
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
        final baseRect = Rect.fromCenter(
          center: map.baseCenter,
          width: tileSize,
          height: tileSize,
        );
        if (b.rect.overlaps(baseRect)) hitBase = true;
      }

      if (hitKey != null || hitBase) {
        toRemove.add(b);
        if (_isAuthorityForBullet(b)) {
          if (hitKey != null) {
            final killed = applyHit(hitKey);
            broadcastHit(hitKey, false);
            if (killed && hitKey < 0) {
              _maybeDropPowerUp(tanks[hitKey]!);
            }
          } else {
            applyBaseHit();
            broadcastHit(-1, true);
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
  bool applyHit(int tankKey) {
    final tank = tanks[tankKey];
    if (tank == null || !tank.isAlive) return false;
    // 玩家护盾抵消一次攻击
    if (tank.playerShieldTimer > 0) {
      tank.playerShieldTimer = 0;
      return false;
    }
    tank.health--;
    if (tank.health <= 0) {
      tank.isAlive = false;
      _addExplosion(tank.position);
      if (tank.isPlayer) {
        final lives = livesByPlayer[tankKey] ?? 0;
        if (lives > 0) {
          livesByPlayer[tankKey] = lives - 1;
          tank.respawnTimer = respawnTime;
        }
      } else {
        enemiesOnField--;
        score += tank.enemyType?.points ?? 0;
      }
      handleRemoveTankCallback(tankKey);
      return true;
    }
    return false;
  }

  /// AI 死亡掉落道具（仅权威端调用，避免各端重复生成）
  void _maybeDropPowerUp(Tank enemy) {
    final rate = enemy.enemyType?.dropRate ?? 0;
    if (_random.nextDouble() >= rate) return;
    final type =
        PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
    final p = PowerUp(position: enemy.position, type: type);
    powerups.add(p);
    broadcastSpawnItem(p);
  }

  void applyBaseHit() {
    if (baseDestroyed) return;
    baseDestroyed = true;
    final col = (map.baseCenter.dx / tileSize).floor();
    final row = (map.baseCenter.dy / tileSize).floor();
    map.setTileType(col, row, TileType.empty);
    _addExplosion(map.baseCenter);
  }

  void _respawn(int key, Tank tank) {
    tank.position = _resolveSpawnPoint(key);
    tank.angle = -pi / 2;
    tank.turretAngle = -pi / 2;
    tank.health = 1;
    tank.isAlive = true;
    tank.invincibleTimer = invincibleTime;
    tank.reloadTimer = 0;
    // 复活重置个人 buff（基地护盾属 base，不随玩家清除）
    tank.fireBuffTimer = 0;
    tank.homingBuffTimer = 0;
    tank.playerShieldTimer = 0;
  }

  // ---- 爆炸 ----

  void _addExplosion(Offset position) {
    explosions.add(Explosion(position: position, size: tankSize));
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
    final pid = key % playerColors.length;
    tanks[key] = Tank(
      position: _resolveSpawnPoint(key),
      angle: -pi / 2,
      turretAngle: -pi / 2,
      health: 1,
      playerId: pid,
      color: playerColors[pid],
      invincibleTimer: invincibleTime,
      moving: false,
    );
    livesByPlayer[key] = playerLives;
  }

  /// 选可用出生点：当前固定点优先，被障碍占用则切换到另一可用点并固定
  Offset _resolveSpawnPoint(int playerKey) {
    var idx = playerSpawnUsed[playerKey] ??
        (playerKey % playerSpawnPoints.length);
    if (_isSpawnClear(playerSpawnPoints[idx])) return playerSpawnPoints[idx];
    for (int i = 1; i < playerSpawnPoints.length; i++) {
      final ni = (idx + i) % playerSpawnPoints.length;
      if (_isSpawnClear(playerSpawnPoints[ni])) {
        playerSpawnUsed[playerKey] = ni;
        return playerSpawnPoints[ni];
      }
    }
    return playerSpawnPoints[idx];
  }

  /// 出生点是否空闲（不越界/不撞墙/不被其他坦克占用）
  bool _isSpawnClear(Offset pos, {Tank? ignore}) {
    final r = Rect.fromCenter(center: pos, width: tankSize, height: tankSize);
    if (r.left < 0 || r.top < 0 || r.right > mapSize || r.bottom > mapSize) {
      return false;
    }
    if (_rectBlockedByMap(r)) return false;
    for (final other in tanks.values) {
      if (identical(other, ignore) || !other.isAlive) continue;
      if (other.rect.overlaps(r)) return false;
    }
    return true;
  }

  // ---- 开火 ----

  Bullet? fire(int key, Tank tank) {
    if (!tank.canFire) return null;
    tank.reloadTimer = tank.isPlayer ? playerReloadTime : reloadTime;
    var damage = tank.isPlayer ? (tank.starLevel >= 3 ? 2 : 1) : 1;
    if (tank.fireBuffTimer > 0) damage *= 2;
    int? target;
    if (tank.homingBuffTimer > 0) target = _pickHomingTarget(tank);
    final bullet = Bullet(
      position: tank.position +
          Offset.fromDirection(tank.turretAngle) * tank.size * 0.6,
      angle: tank.turretAngle,
      ownerId: key,
      damage: damage,
      targetKey: target,
    );
    bullets.add(bullet);
    return bullet;
  }

  /// 跟踪子弹目标：范围内最近的敌方
  int? _pickHomingTarget(Tank shooter) {
    final range = tileSize * 4;
    int? bestKey;
    var bestDist = range;
    for (final entry in tanks.entries) {
      final t = entry.value;
      if (!t.isAlive || t.isPlayer == shooter.isPlayer) continue;
      final d = (t.position - shooter.position).distance;
      if (d <= bestDist) {
        bestDist = d;
        bestKey = entry.key;
      }
    }
    return bestKey;
  }

  // ---- 权威方调度（local + host 执行；client 因 isAuthority=false 自动跳过） ----

  void handleTickerCallback(double dt) {
    _updateSpawning(dt);
    _updateAiDecision(dt);
    _updateItemSpawning(dt);
  }

  void _updateSpawning(double dt) {
    if (!isAuthority) return;
    _spawnTimer += dt;
    if (_spawnTimer >= 1.0 &&
        enemiesOnField < maxEnemyOnField &&
        remainingEnemies > 0) {
      _spawnTimer = 0;
      _spawnEnemy();
    }
  }

  void _spawnEnemy() {
    if (remainingEnemies <= 0) return;
    final types = EnemyType.values;
    final type = types[_random.nextInt(types.length)];
    // 随机找一个空闲出生点，全占满则放弃本次出生
    final order = List.of(enemySpawnPoints)..shuffle(_random);
    Offset? pos;
    for (final p in order) {
      if (_isSpawnClear(p)) {
        pos = p;
        break;
      }
    }
    if (pos == null) return;
    final tank = Tank(
      position: pos,
      angle: pi / 2,
      turretAngle: pi / 2,
      health: type.health,
      playerId: -1,
      color: type.color,
      enemyType: type,
      invincibleTimer: invincibleTime,
    );
    final key = --_enemyIdSeq;
    tanks[key] = tank;
    enemiesOnField++;
    remainingEnemies--;
    broadcastSpawn(key, tank);
  }

  void _updateAiDecision(double dt) {
    if (!isAuthority) return;
    _aiDecisionTimer += dt;
    if (_aiDecisionTimer < 0.4) return;
    _aiDecisionTimer = 0;
    for (final entry in tanks.entries) {
      final tank = entry.value;
      if (!tank.isAlive || tank.isPlayer) continue;
      _decideAi(entry.key, tank);
    }
  }

  void _decideAi(int key, Tank tank) {
    // 撞墙或随机概率转向（偏向朝下追击玩家/基地）
    final ahead = tank.position + Offset.fromDirection(tank.angle) * tank.size;
    final blocked = !_canMoveTo(ahead, tank);
    if (blocked || _random.nextDouble() < 0.3) {
      final dirs = Direction.values;
      var chosenAngle = tank.angle;
      Direction? chosenDir;
      // 偏向向下
      for (int i = 0; i < 4; i++) {
        final d = dirs[_random.nextInt(4)];
        final test = tank.position + d.vector * tank.size;
        if (_canMoveTo(test, tank)) {
          chosenAngle = d.angle;
          chosenDir = d;
          if (d == Direction.down || _random.nextDouble() < 0.5) break;
        }
      }
      if (chosenDir != null && (chosenAngle - tank.angle).abs() > 0.01) {
        tank.angle = chosenAngle;
        tank.turretAngle = chosenAngle;
        broadcastAiTurn(key, chosenDir);
      }
    }
    // 开火：冷却好则大概率射击
    if (tank.canFire && _random.nextDouble() < 0.5) {
      fire(key, tank);
      broadcastAiFire(key);
    }
  }

  // ---- 道具 ----

  void _updateItemSpawning(double dt) {
    if (!isAuthority) return;
    _itemSpawnTimer += dt;
    if (_itemSpawnTimer >= 25 && powerups.length < 2) {
      _itemSpawnTimer = 0;
      _spawnRandomItem();
    }
  }

  void _spawnRandomItem() {
    for (int i = 0; i < 50; i++) {
      final c = _random.nextInt(gridSize);
      final r = _random.nextInt(gridSize);
      if (map.tileAt(c, r).type != TileType.empty) continue;
      final pos = Offset((c + 0.5) * tileSize, (r + 0.5) * tileSize);
      if (!_isSpawnClear(pos)) continue;
      final type =
          PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
      final p = PowerUp(position: pos, type: type);
      powerups.add(p);
      broadcastSpawnItem(p);
      return;
    }
  }

  /// 仅权威方检测拾取并广播，各端收到 pickup 后应用效果
  void _checkPowerUpPickup() {
    if (!isAuthority) return;
    for (final p in powerups.toList()) {
      for (final entry in tanks.entries) {
        final t = entry.value;
        if (!t.isAlive || !t.isPlayer) continue;
        if (!t.rect.overlaps(p.rect)) continue;
        broadcastPickup(entry.key, p.type, p.position);
        applyPowerUp(entry.key, p.type);
        powerups.remove(p);
        break;
      }
    }
  }

  void applyPowerUp(int playerKey, PowerUpType type) {
    final t = tanks[playerKey];
    switch (type) {
      case PowerUpType.shield:
        _activateShield();
        break;
      case PowerUpType.fireBullet:
        if (t != null) t.fireBuffTimer = 8;
        break;
      case PowerUpType.homing:
        if (t != null) t.homingBuffTimer = 5;
        break;
      case PowerUpType.playerShield:
        if (t != null) t.playerShieldTimer = 10;
        break;
    }
  }

  void _activateShield() {
    shieldTimer = 10;
    final bc = (map.baseCenter.dx / tileSize).floor();
    final br = (map.baseCenter.dy / tileSize).floor();
    for (final dc in <int>[-1, 0, 1]) {
      for (final dr in <int>[-1, 0, 1]) {
        if (dc == 0 && dr == 0) continue; // base 本身不动
        final c = bc + dc, r = br + dr;
        if (c < 0 || c >= gridSize || r < 0 || r >= gridSize) continue;
        map.setTileType(c, r, TileType.steel);
      }
    }
  }

  void _updateShield(double dt) {
    if (shieldTimer <= 0) return;
    shieldTimer -= dt;
    if (shieldTimer > 0) return;
    shieldTimer = 0;
    // 一圈无条件变 brick（即便原本空地，最终出现一圈砖墙）
    final bc = (map.baseCenter.dx / tileSize).floor();
    final br = (map.baseCenter.dy / tileSize).floor();
    for (final dc in <int>[-1, 0, 1]) {
      for (final dr in <int>[-1, 0, 1]) {
        if (dc == 0 && dr == 0) continue;
        final c = bc + dc, r = br + dr;
        if (c < 0 || c >= gridSize || r < 0 || r >= gridSize) continue;
        if (map.tileAt(c, r).type != TileType.base) {
          map.setTileType(c, r, TileType.brick);
        }
      }
    }
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
    _gameOver = false;
    baseDestroyed = false;
    score = 0;
    remainingEnemies = totalEnemyCount;
    enemiesOnField = 0;
    _enemyIdSeq = 0;
    _spawnTimer = 0;
    _aiDecisionTimer = 0;
    _itemSpawnTimer = 0;
    shieldTimer = 0;
    tanks.clear();
    bullets.clear();
    explosions.clear();
    powerups.clear();
    livesByPlayer.clear();
    playerSpawnUsed.clear();
    map = isAuthority ? MapData.random(_random) : MapData.classic();
    _lastElapsed = 0;
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
    handleGameOverCallback();
    pageNavigator.value = (context) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(S.gameOver),
          content: Text('${victory ? S.victory : S.defeat}  $finalScore'),
          actions: [
            TextButton(
              child: Text(S.exit),
              onPressed: () {
                Navigator.pop(context);
                leavePage();
              },
            ),
            TextButton(
              child: Text(S.restart),
              onPressed: () {
                Navigator.pop(context);
                requestRestart();
              },
            ),
          ],
        ),
      );
    };
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
    map = MapData.fromJson(json['map'] as Map<String, dynamic>);
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

  void handleRemoveTankCallback(int tankKey);

  void handleGameOverCallback();

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

  /// 请求重开：local 直接重置，net 触发联机重握手
  void requestRestart();

  void leavePage();

  // 广播钩子（local 全部空实现；net 发 action）
  void broadcastAiTurn(int tankKey, Direction dir) {}
  void broadcastAiFire(int tankKey) {}
  void broadcastSpawn(int tankKey, Tank tank) {}
  void broadcastHit(int tankKey, bool isBase) {}
  void broadcastSpawnItem(PowerUp p) {}
  void broadcastPickup(int playerKey, PowerUpType type, Offset position) {}

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
