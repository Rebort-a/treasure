import 'dart:math';
import 'package:flutter/material.dart';

import '../00.common/tool/notifiers.dart';
import 'base.dart';

/// 塔防游戏核心管理器
class FoundationManager {
  static const double cellSize = 40.0;
  static const int startGold = 200;
  static const int startLives = 20;

  // 游戏数据
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

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  final Random _rand = Random();
  int _nextEnemyId = 0;
  final Map<int, Enemy> _enemyMap = {};

  // 波次生成状态
  List<Enemy> _waveQueue = [];
  double _spawnTimer = 0;
  double _spawnInterval = 0.8;
  bool _waveActive = false;
  void initGame({int? seed}) {
    map = GameMapData.generate(seed: seed);
    towers.value = [];
    enemies.value = [];
    projectiles.value = [];
    gold.value = startGold;
    lives.value = startLives;
    waveNumber.value = 0;
    state.value = GameState.preparing;
    selectedTower.value = null;
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
    final wave = WaveGenerator.generate(waveNumber.value);
    _spawnInterval = wave.spawnInterval;
    _waveQueue = [];

    for (final (type, count) in wave.groups) {
      for (int i = 0; i < count; i++) {
        final enemy = Enemy(type: type, pathProgress: 0);
        enemy.hp = WaveGenerator.scaledHp(enemy.config.maxHp, waveNumber.value);
        _waveQueue.add(enemy);
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
      final enemy = _waveQueue.removeAt(0);
      final id = _nextEnemyId++;
      _enemyMap[id] = enemy;
      enemies.value = [...enemies.value, enemy];
    }
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

  // ==================== 敌人逻辑 ====================

  void _updateEnemies(double dt) {
    final path = map.path;
    for (final enemy in enemies.value) {
      if (!enemy.alive) continue;

      // 移动
      enemy.pathProgress += enemy.speed * dt;

      // 到达终点
      if (enemy.pathProgress >= path.length - 1) {
        enemy.alive = false;
        lives.value--;
        escaped.value++;
      }

      // 减速效果衰减
      if (enemy.speedMultiplier < 1.0) {
        enemy.speedMultiplier = min(1.0, enemy.speedMultiplier + dt * 0.3);
      }
    }

    // 移除死亡敌人
    final alive = enemies.value.where((e) => e.alive).toList();
    if (alive.length != enemies.value.length) {
      enemies.value = alive;
    }
  }

  // ==================== 塔逻辑 ====================

  void _updateTowers(double dt) {
    for (final tower in towers.value) {
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
      if (idx >= map.path.length) continue;

      final ePos = map.path[idx];
      final dist = sqrt(pow(ePos.x - towerX, 2) + pow(ePos.y - towerY, 2));
      if (dist > range) continue;

      // 优先攻击路径进度最远的
      if (enemy.pathProgress > bestProgress) {
        bestProgress = enemy.pathProgress;
        best = enemy;
      }
    }

    return best;
  }

  void _fire(Tower tower, Enemy target) {
    final targetIdx = target.pathIndex;
    if (targetIdx >= map.path.length) return;

    projectiles.value = [
      ...projectiles.value,
      Projectile(
        from: tower.pos,
        targetId: _enemyId(target),
        damage: tower.damage,
        splashRadius: tower.config.splashRadius,
        slowFactor: tower.config.slowFactor,
        pierce: tower.config.pierce,
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
      p.progress += dt * 8.0; // 飞行速度
      if (p.progress >= 1.0) {
        // 命中
        _applyDamage(p);
        changed = true;
      } else {
        active.add(p);
      }
    }

    if (changed) {
      projectiles.value = active;
    }
  }

  void _applyDamage(Projectile p) {
    final target = _enemyMap[p.targetId];
    if (target != null && target.alive) {
      target.hp -= p.damage;
      if (p.slowFactor > 0) {
        target.speedMultiplier = p.slowFactor;
      }
      if (target.hp <= 0) {
        target.alive = false;
        gold.value += target.reward;
        kills.value++;
      }

      if (p.splashRadius > 0) {
        final tIdx = target.pathIndex;
        if (tIdx < map.path.length) {
          final tPos = map.path[tIdx];
          for (final enemy in enemies.value) {
            if (identical(enemy, target) || !enemy.alive) continue;
            final eIdx = enemy.pathIndex;
            if (eIdx >= map.path.length) continue;
            final ePos = map.path[eIdx];
            final dist = sqrt(pow(ePos.x - tPos.x, 2) + pow(ePos.y - tPos.y, 2));
            if (dist <= p.splashRadius) {
              enemy.hp -= (p.damage * 0.5).toInt();
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
    final config = TowerConfigs.getConfig(type);
    if (gold.value < config.cost) return false;

    gold.value -= config.cost;
    map.cells[pos.y][pos.x] = CellType.tower;
    towers.value = [...towers.value, Tower(type: type, pos: pos)];
    return true;
  }

  bool upgradeTower(Tower tower) {
    if (tower.level >= 3) return false;
    if (gold.value < tower.upgradeCost) return false;

    gold.value -= tower.upgradeCost;
    tower.level++;
    towers.value = [...towers.value]; // 触发刷新
    return true;
  }

  void selectTowerType(TowerType? type) {
    selectedTower.value = type;
  }

  // ==================== 胜负判定 ====================

  void _checkGameOver() {
    if (lives.value <= 0) {
      state.value = GameState.lost;
    }
  }

  void checkWinCondition() {
    if (state.value != GameState.playing) return;
    if (!_waveActive && _waveQueue.isEmpty && enemies.value.isEmpty) {
      // 通关条件：完成 20 波
      if (waveNumber.value >= 20) {
        state.value = GameState.won;
      }
    }
  }

  // ==================== 辅助 ====================

  /// 获取敌人在地图上的像素位置
  Offset getEnemyPixelPos(Enemy enemy) {
    final path = map.path;
    final idx = enemy.pathIndex;
    if (idx >= path.length - 1) {
      final last = path.last;
      return Offset(last.x * cellSize + cellSize / 2, last.y * cellSize + cellSize / 2);
    }

    final frac = enemy.pathFraction;
    final cur = path[idx];
    final next = path[idx + 1];
    final x = (cur.x + (next.x - cur.x) * frac) * cellSize + cellSize / 2;
    final y = (cur.y + (next.y - cur.y) * frac) * cellSize + cellSize / 2;
    return Offset(x, y);
  }
}
