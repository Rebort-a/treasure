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

  final pageNavigator = AlwaysNotifier<void Function(BuildContext)>((_) {});
  final gameState = ValueNotifier<bool>(false);

  /// 各玩家剩余命数（key = 玩家坦克 key = identity）
  final Map<int, int> livesByPlayer = {};

  /// 对局进度
  int remainingEnemies = totalEnemyCount;
  int enemiesOnField = 0;
  bool baseDestroyed = false;
  int score = 0;
  bool _gameOver = false;

  int _enemyIdSeq = 0; // AI key 递减序列
  int _spawnCursor = 0; // 出生点轮换
  double _spawnTimer = 0;
  double _aiDecisionTimer = 0;

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
    _updateBullets(dt);
    _checkBulletWallCollisions();
    _checkTankBulletHits();
    _updateExplosions(dt);

    handleTickerCallback(dt); // 权威方：AI 决策 + 刷怪；client 空实现

    _checkGameOver();
    notifyListeners();
  }

  // ---- 坦克移动 ----

  void _updateTanks(double dt) {
    for (final tank in tanks.values) {
      if (!tank.isAlive) {
        if (tank.respawnTimer > 0) {
          tank.respawnTimer -= dt;
          if (tank.respawnTimer <= 0) _respawn(tank);
        }
        continue;
      }
      if (tank.reloadTimer > 0) tank.reloadTimer -= dt;
      if (tank.invincibleTimer > 0) tank.invincibleTimer -= dt;
      if (!tank.moving) continue;

      final speed = tank.isPlayer
          ? tankSpeed
          : (tank.enemyType?.speed ?? tankSpeed);
      final move = tank.direction.vector * speed * dt;
      // 先在垂直轴对齐到格子中心（转向后能沿走廊，撞墙时也不会贴墙卡死）
      final aligned = _alignAxis(tank.position, tank.direction);
      if (_canMoveTo(aligned, tank)) tank.position = aligned;
      // 再沿当前方向前进
      final newPos = tank.position + move;
      if (_canMoveTo(newPos, tank)) tank.position = newPos;
    }
  }

  /// 格子中心坐标（坦克轨道对齐用）
  double _snapCenter(double v) =>
      (((v - tileSize / 2) / tileSize).round()) * tileSize + tileSize / 2;

  /// 将坦克在移动方向的垂直轴对齐到最近格子中心，
  /// 便于转向后沿走廊行进（经典坦克吸附手感）
  Offset _alignAxis(Offset pos, Direction dir) {
    if (dir == Direction.left || dir == Direction.right) {
      return Offset(pos.dx, _snapCenter(pos.dy));
    } else {
      return Offset(_snapCenter(pos.dx), pos.dy);
    }
  }

  bool _canMoveTo(Offset newPos, Tank self) {
    final r = Rect.fromCenter(
      center: newPos,
      width: tankSize,
      height: tankSize,
    );
    if (r.left < 0 || r.top < 0 || r.right > mapSize || r.bottom > mapSize) {
      return false;
    }
    if (_rectBlockedByMap(r)) return false;
    for (final other in tanks.values) {
      if (identical(other, self) || !other.isAlive) continue;
      if (other.rect.overlaps(r)) return false;
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
            applyHit(hitKey);
            broadcastHit(hitKey, false);
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

  /// 应用命中（扣血/销毁/爆炸），纯本地状态变更
  void applyHit(int tankKey) {
    final tank = tanks[tankKey];
    if (tank == null || !tank.isAlive) return;
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
    }
  }

  void applyBaseHit() {
    if (baseDestroyed) return;
    baseDestroyed = true;
    final col = (map.baseCenter.dx / tileSize).floor();
    final row = (map.baseCenter.dy / tileSize).floor();
    map.setTileType(col, row, TileType.empty);
    _addExplosion(map.baseCenter);
  }

  void _respawn(Tank tank) {
    final spawn = playerSpawnPoints[tank.playerId % playerSpawnPoints.length];
    tank.position = spawn;
    tank.direction = Direction.up;
    tank.turretDirection = Direction.up;
    tank.health = 1;
    tank.isAlive = true;
    tank.invincibleTimer = invincibleTime;
    tank.reloadTimer = 0;
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
      position: playerSpawnPoints[pid],
      direction: Direction.up,
      turretDirection: Direction.up,
      health: 1,
      playerId: pid,
      color: playerColors[pid],
      invincibleTimer: invincibleTime,
      moving: false,
    );
    livesByPlayer[key] = playerLives;
  }

  // ---- 开火 ----

  void fire(Tank tank) {
    if (!tank.canFire) return;
    tank.reloadTimer = tank.isPlayer ? playerReloadTime : reloadTime;
    final bullet = Bullet(
      position: tank.position + tank.turretDirection.vector * tankSize * 0.6,
      direction: tank.turretDirection,
      ownerId: tank.playerId,
      damage: tank.isPlayer ? (tank.starLevel >= 3 ? 2 : 1) : 1,
    );
    bullets.add(bullet);
  }

  // ---- 权威方调度（local + host 执行；client 因 isAuthority=false 自动跳过） ----

  void handleTickerCallback(double dt) {
    _updateSpawning(dt);
    _updateAiDecision(dt);
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
    final pos = enemySpawnPoints[_spawnCursor % enemySpawnPoints.length];
    _spawnCursor++;
    final tank = Tank(
      position: pos,
      direction: Direction.down,
      turretDirection: Direction.down,
      health: type.health,
      playerId: -1,
      color: aiColor,
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
    final ahead = tank.position + tank.direction.vector * tankSize;
    final blocked = !_canMoveTo(ahead, tank);
    if (blocked || _random.nextDouble() < 0.3) {
      final dirs = Direction.values;
      Direction chosen = tank.direction;
      // 偏向向下
      for (int i = 0; i < 4; i++) {
        final d = dirs[_random.nextInt(4)];
        final test = tank.position + d.vector * tankSize;
        if (_canMoveTo(test, tank)) {
          chosen = d;
          if (d == Direction.down || _random.nextDouble() < 0.5) break;
        }
      }
      if (chosen != tank.direction) {
        tank.direction = chosen;
        tank.turretDirection = chosen;
        broadcastAiTurn(key, chosen);
      }
    }
    // 开火：冷却好则大概率射击
    if (tank.canFire && _random.nextDouble() < 0.5) {
      fire(tank);
      broadcastAiFire(key, tank.turretDirection);
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
    _spawnCursor = 0;
    _spawnTimer = 0;
    _aiDecisionTimer = 0;
    tanks.clear();
    bullets.clear();
    explosions.clear();
    livesByPlayer.clear();
    map = MapData.classic();
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
    'lives': livesByPlayer.map((k, v) => MapEntry(k.toString(), v)),
    'remaining': remainingEnemies,
    'onField': enemiesOnField,
    'baseDestroyed': baseDestroyed,
    'score': score,
    'enemySeq': _enemyIdSeq,
    'spawnCursor': _spawnCursor,
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
    livesByPlayer.clear();
    (json['lives'] as Map<String, dynamic>).forEach((k, v) {
      livesByPlayer[int.parse(k)] = v as int;
    });
    remainingEnemies = json['remaining'] as int;
    enemiesOnField = json['onField'] as int;
    baseDestroyed = json['baseDestroyed'] as bool;
    score = json['score'] as int;
    _enemyIdSeq = json['enemySeq'] as int;
    _spawnCursor = json['spawnCursor'] as int;
  }

  // ---- 抽象钩子 ----

  void handleRemoveTankCallback(int tankKey);

  void handleGameOverCallback();

  /// 玩家车身/炮塔方向输入：local 直接改本地，net 发 action 转发
  void updatePlayerDirection(Direction dir);

  /// 玩家开火：local 直接 fire，net 发 action 转发
  void updatePlayerFire();

  /// 玩家停止移动：local 设 moving=false，net 发 action 转发
  void updatePlayerStop();

  /// 请求重开：local 直接重置，net 触发联机重握手
  void requestRestart();

  void leavePage();

  // 广播钩子（local 全部空实现；net 发 action）
  void broadcastAiTurn(int tankKey, Direction dir) {}
  void broadcastAiFire(int tankKey, Direction dir) {}
  void broadcastSpawn(int tankKey, Tank tank) {}
  void broadcastHit(int tankKey, bool isBase) {}

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
