import 'dart:math';
import 'package:flutter/material.dart';

import '../00.common/tool/notifiers.dart';
import 'base.dart';

/// 塔防游戏核心管理器
class Manager {
  Manager() {
    initGame();
  }

  static const double cellSize = 40.0;
  static const int startGold = 200;
  static const int startLives = 20;

  late GameMapData map;
  final ListNotifier<Tower> towers = ListNotifier([]);
  final ListNotifier<Enemy> enemies = ListNotifier([]);
  final ListNotifier<Projectile> projectiles = ListNotifier([]);

  final AlwaysNotifier<int> gold = AlwaysNotifier(startGold);
  final AlwaysNotifier<int> lives = AlwaysNotifier(startLives);
  final AlwaysNotifier<int> waveNumber = AlwaysNotifier(0);
  final AlwaysNotifier<GameState> state = AlwaysNotifier(GameState.preparing);
  final AlwaysNotifier<TowerType?> selectedTower = AlwaysNotifier(null);
  final AlwaysNotifier<int> kills = AlwaysNotifier(0);
  final AlwaysNotifier<int> escaped = AlwaysNotifier(0);
  final AlwaysNotifier<GridPos?> selectedWall = AlwaysNotifier(null);
  final AlwaysNotifier<GridPos?> selectedFort = AlwaysNotifier(null);

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  final Random _rand = Random();
  int _nextEnemyId = 0;
  final Map<int, Enemy> _enemyMap = {};

  List<EnemyType> _waveQueue = [];
  double _spawnTimer = 0;
  double _spawnInterval = 0.8;
  bool _waveActive = false;

  void initGame({int? width, int? height, int? seed}) {
    map = GameMapData.generate(
      width: width ?? 20,
      height: height ?? 12,
      seed: seed,
    );
    towers.value = [];
    enemies.value = [];
    projectiles.value = [];
    gold.value = startGold;
    lives.value = startLives;
    waveNumber.value = 0;
    state.value = GameState.preparing;
    selectedTower.value = null;
    selectedWall.value = null;
    selectedFort.value = null;
    kills.value = 0;
    escaped.value = 0;
    _waveQueue = [];
    _waveActive = false;
    _enemyMap.clear();
    _nextEnemyId = 0;
  }

  // ==================== 游戏循环 ====================

  void update(double deltaTime) {
    if (state.value != GameState.playing) return;
    _updateWaveSpawning(deltaTime);
    _updateEnemies(deltaTime);
    _updateTowers(deltaTime);
    _updateProjectiles(deltaTime);
    _checkWaveComplete();
    _checkGameOver();
  }

  // ==================== 波次管理 ====================

  void startNextWave() {
    if (_waveActive) return;
    if (state.value == GameState.lost) return;
    if (state.value == GameState.preparing) {
      state.value = GameState.playing;
    }

    waveNumber.value++;
    // 每波只改变敌人数量，不增加 enter（初始已全列 enter/exit）

    final wave = WaveGenerator.generate(waveNumber.value);
    _spawnInterval = wave.spawnInterval;
    _waveQueue = [];
    for (final (type, count) in wave.groups) {
      for (int i = 0; i < count; i++) {
        _waveQueue.add(type);
      }
    }
    _waveQueue.shuffle(_rand);
    _spawnTimer = 0;
    _waveActive = true;
  }

  void _updateWaveSpawning(double dt) {
    if (_waveQueue.isEmpty) return;
    _spawnTimer += dt;
    while (_spawnTimer >= _spawnInterval && _waveQueue.isNotEmpty) {
      _spawnTimer -= _spawnInterval;
      final type = _waveQueue.removeAt(0);
      final enemy = _spawnEnemy(type);
      final id = _nextEnemyId++;
      _enemyMap[id] = enemy;
      enemies.value = [...enemies.value, enemy];
    }
  }

  /// 创建敌人：enter 起点，目标=右列格 or 堡垒，BFS 不向左穿墙
  Enemy _spawnEnemy(EnemyType type) {
    final leftGaps = map.leftGaps;
    final start = leftGaps.isEmpty
        ? GridPos(0, 0)
        : leftGaps[_rand.nextInt(leftGaps.length)];

    Tower? targetFort;
    GridPos goal;
    if (towers.value.isNotEmpty && _rand.nextDouble() < 0.3) {
      targetFort = towers.value[_rand.nextInt(towers.value.length)];
      goal = targetFort.pos;
    } else {
      goal = GridPos(map.width - 1, _rand.nextInt(map.height));
    }

    final pathList = _findPath(start, goal);
    final enemy = Enemy(type: type, path: pathList);
    enemy.targetFort = targetFort;
    enemy.hp = WaveGenerator.scaledHp(enemy.config.maxHp, waveNumber.value);
    return enemy;
  }

  void _checkWaveComplete() {
    if (!_waveActive) return;
    if (_waveQueue.isNotEmpty) return;
    if (enemies.value.any((e) => e.alive)) return;

    _waveActive = false;
    gold.value += 20 + waveNumber.value * 5;

    if (waveNumber.value >= 20) {
      state.value = GameState.won;
    } else {
      state.value = GameState.preparing;
    }
  }

  // ==================== 寻路（BFS 不向左，随机 dirs 增加多样性） ====================

  List<GridPos> _findPath(GridPos start, GridPos goal) {
    if (!map.inBounds(start.x, start.y) || !map.inBounds(goal.x, goal.y)) {
      return [start];
    }
    if (start == goal) return [start];

    final visited = List.generate(
      map.height,
      (_) => List<bool>.filled(map.width, false),
    );
    final prev = List.generate(
      map.height,
      (_) => List<GridPos?>.filled(map.width, null),
    );
    final queue = <GridPos>[start];
    visited[start.y][start.x] = true;
    bool found = false;

    // 不向左：右/下/上，随机顺序
    final dirs = <(int, int)>[(1, 0), (0, 1), (0, -1)];
    dirs.shuffle(_rand);

    while (queue.isNotEmpty && !found) {
      final cur = queue.removeAt(0);
      for (final (dx, dy) in dirs) {
        final nx = cur.x + dx, ny = cur.y + dy;
        if (!map.inBounds(nx, ny) || visited[ny][nx]) continue;
        visited[ny][nx] = true;
        prev[ny][nx] = cur;
        if (nx == goal.x && ny == goal.y) {
          found = true;
          break;
        }
        queue.add(GridPos(nx, ny));
      }
    }

    if (!found) return [start];
    final result = <GridPos>[goal];
    GridPos cur = goal;
    while (cur != start) {
      final p = prev[cur.y][cur.x];
      if (p == null) break;
      cur = p;
      result.add(cur);
    }
    return result.reversed.toList();
  }

  // ==================== 敌人逻辑（遇 tower 攻击，用自身 attackDamage） ====================

  void _updateEnemies(double dt) {
    for (final enemy in enemies.value) {
      if (!enemy.alive) continue;

      if (enemy.attacking) {
        enemy.attackCooldown -= dt;
        if (enemy.attackCooldown <= 0) {
          enemy.attackCooldown = 1.0;
          final targetIdx = (enemy.pathIndex + 1 < enemy.path.length)
              ? enemy.pathIndex + 1
              : enemy.pathIndex;
          _attackCell(enemy, enemy.path[targetIdx]);
        }
        continue;
      }

      enemy.pathProgress += enemy.speed * dt;
      final nextIdx = enemy.pathIndex + 1;
      if (nextIdx < enemy.path.length) {
        final next = enemy.path[nextIdx];
        if (map.cells[next.y][next.x] == CellType.tower) {
          enemy.pathProgress = enemy.pathIndex.toDouble();
          enemy.attacking = true;
          enemy.attackCooldown = 0;
        }
      } else {
        // 到达终点（右列格）
        enemy.pathProgress = (enemy.path.length - 1).toDouble();
        final end = enemy.path.last;
        if (map.cells[end.y][end.x] == CellType.tower) {
          enemy.attacking = true;
        } else {
          enemy.alive = false;
          lives.value--;
          escaped.value++;
        }
      }

      if (enemy.speedMultiplier < 1.0) {
        enemy.speedMultiplier = min(1.0, enemy.speedMultiplier + dt * 0.3);
      }
    }

    final alive = enemies.value.where((e) => e.alive).toList();
    if (alive.length != enemies.value.length) {
      enemies.value = alive;
    }
  }

  /// 敌人攻击 tower 格：堡垒→Tower.hp；空墙→wallHp；毁→breakToField
  void _attackCell(Enemy enemy, GridPos target) {
    if (map.cells[target.y][target.x] != CellType.tower) {
      enemy.attacking = false;
      return;
    }
    Tower? fort;
    for (final t in towers.value) {
      if (t.pos.x == target.x && t.pos.y == target.y) {
        fort = t;
        break;
      }
    }
    if (fort != null) {
      fort.hp -= enemy.config.attackDamage;
      if (fort.hp <= 0) {
        _destroyFort(fort);
        enemy.attacking = false;
      }
    } else {
      map.wallHp[target.y][target.x] -= enemy.config.attackDamage;
      if (map.wallHp[target.y][target.x] <= 0) {
        map.breakToField(target.x, target.y);
        enemy.attacking = false;
      }
    }
  }

  void _destroyFort(Tower fort) {
    map.breakToField(fort.pos.x, fort.pos.y);
    towers.value = towers.value.where((t) => !identical(t, fort)).toList();
  }

  // ==================== 塔逻辑（跳过 wall/fortress 不攻击） ====================

  void _updateTowers(double dt) {
    for (final tower in towers.value) {
      if (!tower.canAttack) continue; // wall/fortress 路障不攻击
      tower.cooldown -= dt;
      if (tower.cooldown > 0) continue;
      final target = _findTarget(tower);
      if (target == null) continue;
      tower.cooldown = 1.0 / tower.config.fireRate;
      _fire(tower, target);
    }
  }

  Enemy? _findTarget(Tower tower) {
    final towerX = tower.pos.x.toDouble();
    final towerY = tower.pos.y.toDouble();
    final range = tower.range;
    Enemy? best;
    double bestProgress = -1;
    for (final enemy in enemies.value) {
      if (!enemy.alive) continue;
      final idx = enemy.pathIndex;
      if (idx >= enemy.path.length) continue;
      final ePos = enemy.path[idx];
      final dist = sqrt(pow(ePos.x - towerX, 2) + pow(ePos.y - towerY, 2));
      if (dist > range) continue;
      if (enemy.pathProgress > bestProgress) {
        bestProgress = enemy.pathProgress;
        best = enemy;
      }
    }
    return best;
  }

  void _fire(Tower tower, Enemy target) {
    final targetIdx = target.pathIndex;
    if (targetIdx >= target.path.length) return;
    projectiles.value = [
      ...projectiles.value,
      Projectile(
        from: tower.pos,
        targetId: _enemyId(target),
        damage: tower.damage,
        splashRadius: tower.config.splashRadius,
        slowFactor: tower.config.slowFactor,
      ),
    ];
  }

  int _enemyId(Enemy enemy) {
    for (final entry in _enemyMap.entries) {
      if (identical(entry.value, enemy)) return entry.key;
    }
    return -1;
  }

  // ==================== 飞弹逻辑 ====================

  void _updateProjectiles(double dt) {
    bool changed = false;
    final active = <Projectile>[];
    for (final p in projectiles.value) {
      p.progress += dt * 8.0;
      if (p.progress >= 1.0) {
        _applyDamage(p);
        changed = true;
      } else {
        active.add(p);
      }
    }
    if (changed) projectiles.value = active;
  }

  void _applyDamage(Projectile p) {
    final target = _enemyMap[p.targetId];
    if (target != null && target.alive) {
      target.hp -= p.damage;
      if (p.slowFactor > 0) target.speedMultiplier = p.slowFactor;
      if (target.hp <= 0) {
        target.alive = false;
        gold.value += target.reward;
        kills.value++;
      }
      if (p.splashRadius > 0) {
        final tIdx = target.pathIndex;
        if (tIdx < target.path.length) {
          final tPos = target.path[tIdx];
          for (final enemy in enemies.value) {
            if (identical(enemy, target) || !enemy.alive) continue;
            final eIdx = enemy.pathIndex;
            if (eIdx >= enemy.path.length) continue;
            final ePos = enemy.path[eIdx];
            final dist = sqrt(
              pow(ePos.x - tPos.x, 2) + pow(ePos.y - tPos.y, 2),
            );
            if (dist <= p.splashRadius) {
              enemy.hp -= (p.damage * 0.5).toInt();
              if (p.slowFactor > 0) enemy.speedMultiplier = p.slowFactor;
              if (enemy.hp <= 0) {
                enemy.alive = false;
                gold.value += enemy.reward;
                kills.value++;
              }
            }
          }
        }
      }
    }
  }

  // ==================== 玩家操作 ====================

  bool placeTower(GridPos pos, TowerType type) {
    if (!map.canBuild(pos.x, pos.y)) return false;
    if (towers.value.any((t) => t.pos.x == pos.x && t.pos.y == pos.y)) {
      return false;
    }
    final config = TowerConfigs.getConfig(type);
    if (config.cost == 0) return false; // 不可直接建
    if (gold.value < config.cost) return false;
    gold.value -= config.cost;
    map.wallHp[pos.y][pos.x] = 0; // 有 Tower，空墙 hp 清零
    towers.value = [...towers.value, Tower(type: type, pos: pos)];
    return true;
  }

  /// 升级（进化）：wall→fortress / archer→cannon|spear / ice→magic（重建 Tower，满血）
  bool upgradeTower(Tower tower, TowerType toType) {
    if (!tower.upgrades.contains(toType)) return false;
    if (gold.value < tower.upgradeCost) return false;
    gold.value -= tower.upgradeCost;
    final newTower = Tower(type: toType, pos: tower.pos);
    towers.value = towers.value.where((t) => !identical(t, tower)).toList()
      ..add(newTower);
    return true;
  }

  void selectTowerType(TowerType? type) {
    selectedTower.value = type;
  }

  void selectWall(GridPos? pos) {
    selectedWall.value = pos;
  }

  void selectFort(GridPos? pos) {
    selectedFort.value = pos;
  }

  // ==================== 胜负判定 ====================

  void _checkGameOver() {
    if (lives.value <= 0) state.value = GameState.lost;
  }

  // ==================== 辅助 ====================

  Offset getEnemyPixelPos(Enemy enemy) {
    final path = enemy.path;
    if (path.isEmpty) return Offset.zero;
    final idx = enemy.pathIndex;
    if (idx >= path.length - 1) {
      final last = path.last;
      return Offset(
        last.x * cellSize + cellSize / 2,
        last.y * cellSize + cellSize / 2,
      );
    }
    final frac = enemy.pathFraction;
    final cur = path[idx];
    final next = path[idx + 1];
    final x = (cur.x + (next.x - cur.x) * frac) * cellSize + cellSize / 2;
    final y = (cur.y + (next.y - cur.y) * frac) * cellSize + cellSize / 2;
    return Offset(x, y);
  }
}
