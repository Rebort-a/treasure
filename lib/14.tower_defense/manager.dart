import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../00.common/tool/notifiers.dart';
import 'base.dart';

/// 塔防游戏核心管理器（飞船范式：Manager 自持 Ticker + ChangeNotifier，
/// painter 通过 super(repaint: manager) 自动重绘，无需 page 级 setState）
class Manager with ChangeNotifier implements TickerProvider {
  Manager() {
    _initTicker();
  }

  static const double cellSize = 40.0;
  static const int startGold = 200;
  static const int startLives = 20;
  static const double _effectDuration = 0.4; // 击杀特效时长（秒）

  late GameMapData map;
  final ListNotifier<Tower> towers = ListNotifier([]);
  final ListNotifier<Enemy> enemies = ListNotifier([]);
  final ListNotifier<Projectile> projectiles = ListNotifier([]);
  final ListNotifier<KillEffect> effects = ListNotifier([]);

  final AlwaysNotifier<int> gold = AlwaysNotifier(startGold);
  final AlwaysNotifier<int> lives = AlwaysNotifier(startLives);
  final AlwaysNotifier<int> waveNumber = AlwaysNotifier(0);
  final AlwaysNotifier<GameState> state = AlwaysNotifier(GameState.preparing);
  final AlwaysNotifier<CellType?> selectedTower = AlwaysNotifier(null);
  final AlwaysNotifier<int> kills = AlwaysNotifier(0);
  final AlwaysNotifier<int> escaped = AlwaysNotifier(0);
  final AlwaysNotifier<GridPos?> selectedFort = AlwaysNotifier(null);

  late Ticker _ticker;
  double _lastElapsed = 0;
  final AlwaysNotifier<double> speed = AlwaysNotifier(1.0); // 倍速挡位（1/2/3）

  final Random _rand = Random();
  int _nextEnemyId = 0;
  final Map<int, Enemy> _enemyMap = {}; // 飞弹按 id 反查目标，死亡即移除

  List<EnemyType> _waveQueue = [];
  double _spawnTimer = 0;
  double _spawnInterval = 0.8;
  bool _waveActive = false;

  /// 全局动画时钟（秒），供精灵帧动画与击杀特效计时
  double animTime = 0;

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  void _initTicker() {
    _ticker = createTicker(_update);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void initGame({int? width, int? height}) {
    map = GameMapData.generate(
      width: width ?? 20,
      height: height ?? 12,
      random: _rand,
    );
    towers.value = [
      for (int y = 0; y < map.height; y++)
        for (int x = 0; x < map.width; x++)
          if (map.cells[y][x].isTower)
            Tower(type: CellType.barrier, pos: GridPos(x, y)),
    ];
    enemies.clear();
    projectiles.clear();
    effects.clear();
    gold.value = startGold;
    lives.value = startLives;
    waveNumber.value = 0;
    state.value = GameState.preparing;
    selectedTower.value = null;
    selectedFort.value = null;
    kills.value = 0;
    escaped.value = 0;
    _waveQueue = [];
    _waveActive = false;
    _enemyMap.clear();
    _nextEnemyId = 0;
    speed.value = 1.0;
    _lastElapsed = 0;
    animTime = 0;
    notifyListeners();
  }

  // ==================== 游戏循环（Ticker 驱动 + 真实 deltaTime + 倍速） ====================

  void _update(Duration elapsed) {
    final cur = elapsed.inMilliseconds / 1000.0;
    var dt = cur - _lastElapsed;
    _lastElapsed = cur;
    if (dt < 0) dt = 0;
    // 仅 playing 推进逻辑与动画；paused/won/lost/preparing 静止
    if (state.value != GameState.playing) return;
    final scaled = dt.clamp(0.004, 0.05) * speed.value;
    animTime += scaled;
    _updateWaveSpawning(scaled);
    _updateEnemies(scaled);
    _updateTowers(scaled);
    _updateProjectiles(scaled);
    _updateEffects();
    _checkWaveComplete();
    _checkGameOver();
    notifyListeners();
  }

  // ==================== 暂停 / 倍速 ====================

  bool get canPause =>
      state.value == GameState.playing || state.value == GameState.paused;

  void togglePause() {
    if (state.value == GameState.playing) {
      state.value = GameState.paused;
    } else if (state.value == GameState.paused) {
      state.value = GameState.playing;
    }
    notifyListeners();
  }

  void setSpeed(double s) {
    speed.value = s;
  }

  /// 倍速循环切换 1→2→4→1
  void cycleSpeed() {
    speed.value = speed.value >= 4.0
        ? 1.0
        : (speed.value == 1.0 ? 2.0 : 4.0);
  }

  // ==================== 波次管理 ====================

  void startNextWave() {
    if (_waveActive) return;
    final s = state.value;
    if (s == GameState.lost || s == GameState.won || s == GameState.paused) {
      return;
    }
    if (s == GameState.preparing) {
      state.value = GameState.playing;
    }

    waveNumber.value++;
    _addEnter(); // 每波在最左列随机新增一个 enter
    _addExit(); // 每波在最右列随机新增一个 exit

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
      _enemyMap[enemy.id] = enemy;
      enemies.add(enemy);
    }
  }

  /// 最左列随机一个 road 格转为 enter（全部已是 enter 时不再增加）
  void _addEnter() {
    final roads = <int>[];
    for (int y = 0; y < map.height; y++) {
      if (map.cells[y][0] == CellType.road) roads.add(y);
    }
    if (roads.isEmpty) return;
    map.toEnter(roads[_rand.nextInt(roads.length)]);
  }

  /// 最右列随机一个 road 格转为 exit（全部已是 exit 时不再增加）
  void _addExit() {
    final roads = <int>[];
    for (int y = 0; y < map.height; y++) {
      if (map.cells[y][map.width - 1] == CellType.road) roads.add(y);
    }
    if (roads.isEmpty) return;
    map.toExit(roads[_rand.nextInt(roads.length)]);
  }

  /// 创建敌人：从随机 enter 出生（战场左边界进入），终点=最右列随机 exit 格
  Enemy _spawnEnemy(EnemyType type) {
    final enters = <int>[];
    for (int y = 0; y < map.height; y++) {
      if (map.cells[y][0] == CellType.enter) enters.add(y);
    }
    final enter = GridPos(
      0,
      enters.isEmpty ? 0 : enters[_rand.nextInt(enters.length)],
    );

    final pathList = _planPath(enter);
    final enemy = Enemy(id: _nextEnemyId++, type: type, path: pathList);
    enemy.hp = WaveGenerator.scaledHp(enemy.config.maxHp, waveNumber.value);
    return enemy;
  }

  void _checkWaveComplete() {
    if (!_waveActive) return;
    if (_waveQueue.isNotEmpty) return;
    if (enemies.any((e) => !e.escaped)) return;

    _waveActive = false;
    gold.value += 20 + waveNumber.value * 5;
    // 无波次上限，玩家可一直玩（仅 lives 归零才 lost）
    state.value = GameState.preparing;
  }

  // ==================== 路径规划（随机出口 + 右/上/下 组合，禁止上下直接反转） ====================

  /// 怪物从最左列 enter 出生，从最右列随机挑一个 exit 作终点，
  /// 全程只向右/上/下移动（不向左），路径向右、向上、向下自由搭配而多样。
  /// 约束：上↔下不可直接反转（上→下、下→上 之间必须隔一步右移），
  /// 例如 上→上→右→下 合法，而上→下 非法。
  /// 实现上把路线拆成"垂直游走块"与"右移块"交替：每块纵移后必紧跟一段右移，
  /// 右移即作为上下换向的复位步，故天然不会出现直接上下反转。
  List<GridPos> _planPath(GridPos enter) {
    final w = map.width, h = map.height;
    // 终点=最右列已部署的 exit 格（让怪物在出口图标处消失）；无 exit 时回退随机格
    final exits = <int>[];
    for (int y = 0; y < h; y++) {
      if (map.cells[y][w - 1] == CellType.exit) exits.add(y);
    }
    final goalY = exits.isEmpty
        ? _rand.nextInt(h)
        : exits[_rand.nextInt(exits.length)];
    final goal = GridPos(w - 1, goalY);

    final path = <GridPos>[enter];
    int x = enter.x, y = enter.y;

    // 1) 向右推进到最右列，期间随机夹"垂直游走块"制造上/下绕路多样性；
    //    每块纵移后立刻跟一段右移，作为上下换向的复位步。
    while (x < goal.x) {
      if (_rand.nextDouble() < 0.6) {
        // 偏向出口方向的纵移为主，偶尔反向游走
        final toward = goal.y > y ? 1 : (goal.y < y ? -1 : 0);
        var dir =
            toward != 0 && _rand.nextDouble() < 0.6
            ? toward
            : (_rand.nextBool() ? 1 : -1);
        var room = dir > 0 ? h - 1 - y : y;
        // 边界行 dir 朝越界时翻转为可行方向，避免出生在最上/下行的怪物
        // 只能直走到头再末端归位（路径雷同）
        if (room == 0) {
          dir = -dir;
          room = dir > 0 ? h - 1 - y : y;
        }
        final cnt = 1 + _rand.nextInt(max(1, min(3, room + 1)));
        for (int i = 0; i < min(cnt, room); i++) {
          y += dir;
          path.add(GridPos(x, y));
        }
      }
      // 右移一块（推向最右列），也是换向复位步
      final stop = min(x + 1 + _rand.nextInt(max(1, goal.x - x)), goal.x);
      while (x < stop) {
        x += 1;
        path.add(GridPos(x, y));
      }
    }

    // 2) 到达最右列后纵移归位到出口（刚经过右移，方向可自由选择）
    while (y < goal.y) {
      y += 1;
      path.add(GridPos(x, y));
    }
    while (y > goal.y) {
      y -= 1;
      path.add(GridPos(x, y));
    }

    return path;
  }

  // ==================== 敌人逻辑（遇 tower 攻击，用自身 attackDamage） ====================

  void _updateEnemies(double dt) {
    // 上一帧已定位于出口并被绘制过的逃跑敌人，本次率先移除（避免在出口滞留）
    if (enemies.any((e) => e.escaped)) {
      enemies.removeWhere((e) => e.escaped);
    }
    for (final enemy in enemies.value) {
      if (enemy.dying || enemy.escaped) continue;

      if (enemy.slowTimer > 0) {
        enemy.slowTimer -= dt;
        if (enemy.slowTimer <= 0) enemy.speedMultiplier = 1.0;
      }

      if (enemy.attacking) {
        // 减速同时拖慢攻击：冷却衰减乘以 speedMultiplier，与移速同源
        enemy.attackCooldown -= dt * enemy.speedMultiplier;
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
      final nextIdx = enemy.pathIndex + 1;      if (nextIdx < enemy.path.length) {
        final next = enemy.path[nextIdx];
        // 仅图内塔格阻挡
        final blocked = map.cells[next.y][next.x].isTower;
        if (blocked) {
          // 抵近到格子边界（距道具 0.5 格）再攻击：平滑逼近 cap 再停，
          // 不直接 snap 到 0.5（snap 会造成前进瞬移）
          final cap = enemy.pathIndex + 0.5;
          if (enemy.pathProgress >= cap) {
            enemy.pathProgress = cap;
            if (!enemy.attacking) {
              enemy.attacking = true;
              enemy.attackCooldown = 0;
            }
          }
        }
      } else {
        // 到达终点（最右列 exit）：定位于出口格，存活一帧供绘制重合，
        // 下一帧 _updateEnemies 开头再移除
        enemy.pathProgress = (enemy.path.length - 1).toDouble();
        _enemyMap.remove(enemy.id);
        enemy.escaped = true;
        lives.value--;
        escaped.value++;
      }

      if (enemy.slowTimer > 0) {
        enemy.slowTimer -= dt;
        if (enemy.slowTimer <= 0) enemy.speedMultiplier = 1.0;
      }
    }

    // 死亡动画播完的敌人移除（无死亡行者 death==null 立即移除）
    if (enemies.any((e) => e.dying)) {
      enemies.removeWhere((e) {
        if (!e.dying) return false;
        final d = EnemySprites.get(e.type).death;
        return d == null ||
            (animTime - e.deathTime) * EnemySprites.get(e.type).fps >= d.frames;
      });
    }
  }

  /// 敌人攻击塔格：扣 Tower.hp；毁→breakToField
  void _attackCell(Enemy enemy, GridPos target) {
    if (!map.cells[target.y][target.x].isTower) {
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
    if (fort == null) {
      // 不应出现（tower 格必持 Tower）；防御性修复
      map.breakToField(target.x, target.y);
      enemy.attacking = false;
      return;
    }
    fort.hp -= enemy.config.attackDamage;
    if (fort.hp <= 0) {
      _destroyFort(fort);
      enemy.attacking = false;
    }
  }

  void _destroyFort(Tower fort) {
    map.breakToField(fort.pos.x, fort.pos.y);
    towers.remove(fort);
    // 被毁塔恰为当前选中格时收起面板，避免悬空引用
    if (selectedFort.value == fort.pos) {
      selectedFort.value = null;
    }
  }

  // ==================== 塔逻辑（跳过 wall/fortress 不攻击） ====================

  void _updateTowers(double dt) {
    for (final tower in towers.value) {
      if (!tower.canAttack) continue; // wall/fortress 路障不攻击
      tower.cooldown -= dt;
      if (tower.cooldown > 0) continue;
      final targets = _findTargets(tower, tower.config.projectileCount);
      if (targets.isEmpty) continue;
      tower.cooldown = 1.0 / tower.config.fireRate;
      for (final target in targets) {
        _fire(tower, target);
      }
    }
  }

  /// 射程内最近的至多 [count] 个敌人：单弹道取最近一个，
  /// 多弹道优先选不同目标（按距离升序去重取前 [count] 个）。
  /// 用插值浮点坐标算距离，避免整数格子误差
  List<Enemy> _findTargets(Tower tower, int count) {
    final tp = Offset(tower.pos.x.toDouble(), tower.pos.y.toDouble());
    final inRange = <MapEntry<double, Enemy>>[];
    for (final enemy in enemies.value) {
      if (enemy.dying || enemy.escaped) continue;
      final ep = _enemyGridPos(enemy);
      final dist = sqrt(pow(ep.dx - tp.dx, 2) + pow(ep.dy - tp.dy, 2));
      if (dist > tower.range) continue;
      inRange.add(MapEntry(dist, enemy));
    }
    inRange.sort((a, b) => a.key.compareTo(b.key)); // 近的优先
    final sorted = inRange.map((e) => e.value).toList();
    if (count <= 1) return sorted.isEmpty ? [] : [sorted.first];
    return sorted.take(count).toList();
  }

  void _fire(Tower tower, Enemy target) {
    projectiles.add(
      Projectile(
        from: tower.pos,
        targetId: target.id,
        damage: tower.damage,
        splashRadius: tower.config.splashRadius,
        slowFactor: tower.config.slowFactor,
        type: tower.type,
      ),
    );
  }

  // ==================== 飞弹逻辑 ====================

  void _updateProjectiles(double dt) {
    if (projectiles.isEmpty) return;
    for (final p in projectiles.value) {
      p.progress += dt * 4.0;
    }
    // 结算命中的飞弹并增量移除
    projectiles.removeWhere((p) {
      if (p.progress < 1.0) return false;
      _applyDamage(p);
      return true;
    });
  }

  void _applyDamage(Projectile p) {
    final target = _enemyMap[p.targetId];
    if (target == null || target.dying) return;
      target.hp -= p.damage;
      if (p.slowFactor > 0) {
        target.speedMultiplier = p.slowFactor;
        target.slowTimer = 2.0;
      }
    if (target.hp <= 0) {
      _killEnemy(target);
    }
    if (p.splashRadius > 0) {
      final tPos = _enemyGridPos(target);
      for (final enemy in enemies.value) {
        if (identical(enemy, target) || enemy.dying || enemy.escaped) {
          continue;
        }
        final ePos = _enemyGridPos(enemy);
        final dist = sqrt(
          pow(ePos.dx - tPos.dx, 2) + pow(ePos.dy - tPos.dy, 2),
        );
        if (dist <= p.splashRadius) {
          enemy.hp -= (p.damage * 0.5).toInt();
          if (p.slowFactor > 0) {
            enemy.speedMultiplier = p.slowFactor;
            enemy.slowTimer = 2.0;
          }
          if (enemy.hp <= 0) {
            _killEnemy(enemy);
          }
        }
      }
    }
  }

  /// 敌人死亡：标记、移出反查表、触发击杀特效、给奖励
  void _killEnemy(Enemy enemy) {
    _enemyMap.remove(enemy.id); // 飞弹不再锁定
    enemy.dying = true;
    enemy.deathTime = animTime;
    gold.value += enemy.reward;
    kills.value++;
    // 有死亡行→让动画自演；无死亡行（troll）→slash 飞溅特效
    if (EnemySprites.get(enemy.type).death == null) {
      effects.add(KillEffect(pos: getEnemyPixelPos(enemy), bornAt: animTime));
    }
  }

  // ==================== 击杀特效 ====================

  void _updateEffects() {
    if (effects.isEmpty) return;
    effects.removeWhere((e) => animTime - e.bornAt > _effectDuration);
  }

  // ==================== 玩家操作 ====================

  /// 进化/重建 Tower（含 barrier→wall|archer|ice）：toType==自身即重建（回满血），
  /// 花费目标形态自身价格
  bool upgradeTower(Tower tower, CellType toType) {
    // 面板打开期间塔可能已被摧毁移除——拒绝失效引用，避免在 road 上复活图标
    if (!towers.any((t) => identical(t, tower))) return false;
    final isRebuild = toType == tower.type;
    if (!isRebuild && !tower.upgrades.contains(toType)) return false;
    final cost = TowerConfigs.getConfig(toType).cost;
    if (gold.value < cost) return false;
    gold.value -= cost;
    final newTower = Tower(type: toType, pos: tower.pos);
    towers.remove(tower);
    towers.add(newTower);
    notifyListeners();
    return true;
  }

  void selectCellType(CellType? type) {
    selectedTower.value = type;
    notifyListeners();
  }

  void selectFort(GridPos? pos) {
    selectedFort.value = pos;
    notifyListeners();
  }

  // ==================== 胜负判定 ====================

  void _checkGameOver() {
    if (lives.value <= 0) state.value = GameState.lost;
  }

  // ==================== 辅助 ====================

  /// 怪物当前移动方向（按路径段 dy 判定），供动画选行；
  /// dying 或已到终点返回 none
  MoveDir enemyMoveDir(Enemy enemy) {
    if (enemy.dying) return MoveDir.none;
    final path = enemy.path;
    final idx = enemy.pathIndex;
    if (idx + 1 >= path.length) return MoveDir.none;
    final dy = path[idx + 1].y - path[idx].y;
    if (dy < 0) return MoveDir.up;
    if (dy > 0) return MoveDir.down;
    return MoveDir.right;
  }

  /// 敌人当前浮点格子坐标（插值），供射程/溅射判定，消除整数格子误差
  Offset _enemyGridPos(Enemy enemy) {
    final path = enemy.path;
    if (path.isEmpty) return Offset.zero;
    final idx = enemy.pathIndex;
    if (idx >= path.length - 1) {
      return Offset(path.last.x.toDouble(), path.last.y.toDouble());
    }
    final cur = path[idx];
    final next = path[idx + 1];
    return Offset(
      cur.x + (next.x - cur.x) * enemy.pathFraction,
      cur.y + (next.y - cur.y) * enemy.pathFraction,
    );
  }

  Offset getEnemyPixelPos(Enemy enemy) {
    final g = _enemyGridPos(enemy);
    return Offset(
      g.dx * cellSize + cellSize / 2,
      g.dy * cellSize + cellSize / 2,
    );
  }

  /// 飞弹当前像素位置（from → 目标敌人当前位置，按 progress 插值）
  Offset getProjectilePos(Projectile p) {
    final from = Offset(
      p.from.x * cellSize + cellSize / 2,
      p.from.y * cellSize + cellSize / 2,
    );
    final target = _enemyMap[p.targetId];
    if (target == null || target.dying) return from;
    final to = getEnemyPixelPos(target);
    return Offset(
      from.dx + (to.dx - from.dx) * p.progress,
      from.dy + (to.dy - from.dy) * p.progress,
    );
  }
}
