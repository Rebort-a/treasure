import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../00.common/widget/banner/banner_template.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/tool/notifiers.dart';
import '../l10n/strings.dart';
import 'base.dart';
import 'constant.dart';

/// 游戏状态枚举
enum GameState { start, playing, paused, gameOver, levelUp }

/// 游戏管理类（核心逻辑）
class Manager with ChangeNotifier implements TickerProvider {
  final Random _random = Random();
  late Ticker _ticker;
  final FocusNode focusNode = FocusNode();

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {});

  final ValueNotifier<GameState> _state = ValueNotifier(GameState.start);

  Size _screenSize = Size.zero;
  double _sensitivity = 1.0; // 灵敏度

  final List<Enemy> _enemies = [];
  final List<Bullet> _bullets = [];
  final List<GameProp> _props = [];
  final List<Star> _stars = [];
  final List<Explosion> _explosions = [];
  final List<AchievementType> _unlockedAchievements = [];

  late Player _player;
  late Enemy? _boss;
  late int _score; // 分数
  late int _level; // 等级
  late int _enemiesKilled; // 击杀数
  late int _summonBoss; //召唤boss数量
  late double _lastElapsed; // 上次更新时间
  late double _enemySpawnTimer; // 敌人生成间隔
  late double _levelUpTimer; // 升级时间

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  Manager() {
    _resetState();
    _resetPlayer();
    _initFocusNode();
    _initTicker();
  }

  void _initFocusNode() {
    focusNode.requestFocus();
  }

  void _initTicker() {
    _ticker = createTicker(_update);
    _ticker.start();
  }

  // 游戏主更新方法
  void _update(Duration elapsed) {
    final currentTime = elapsed.inMilliseconds;

    final currentElapsed = currentTime / 1000.0;
    final deltaTime = currentElapsed - _lastElapsed;
    _lastElapsed = currentElapsed;

    final clampedDeltaTime = deltaTime.clamp(0.004, 0.02); // 限制帧率

    if (_state.value == GameState.playing) {
      _updateStars(clampedDeltaTime);
      _spawnEnemies(clampedDeltaTime);
      _updateEnemies(clampedDeltaTime);
      _updateBullets(clampedDeltaTime);
      _checkBulletEnemyCollisions();
      _checkPlayerEnemyCollisions();
      _updateExplosions(clampedDeltaTime);
      _updateProps(clampedDeltaTime);
      _updatePlayer(clampedDeltaTime);
      notifyListeners();
    } else if (_state.value == GameState.levelUp) {
      _handleLevelUp(clampedDeltaTime);
    }
  }

  // 创建星空背景
  void _initStars() {
    _stars.clear();
    final count = (_screenSize.width * _screenSize.height / 1000).toInt();
    for (int i = _stars.length; i < count; i++) {
      _stars.add(
        Star(
          position: Offset(
            _random.nextDouble() * _screenSize.width,
            _random.nextDouble() * _screenSize.height,
          ),
          size: Size.square(_random.nextDouble() * 1.5),
          opacity: _random.nextDouble(),
          speed:
              _random.nextDouble() *
                  (ParamConstants.maxStarSpeed - ParamConstants.minStarSpeed) +
              ParamConstants.minStarSpeed,
        ),
      );
    }
  }

  // 更新星星背景
  void _updateStars(double deltaTime) {
    for (var star in _stars) {
      star.position += Offset(0, star.speed * deltaTime);
      // 星星移出屏幕底部后重置到顶部
      if (star.position.dy > _screenSize.height) {
        star.position = Offset(
          _random.nextDouble() * _screenSize.width,
          -star.size.height,
        );
      }
    }
  }

  // 更新玩家状态
  void _updatePlayer(double deltaTime) {
    // 处理无敌状态
    if (_player.invincible) {
      _player.invincibleTimer -= deltaTime;
      _player.flashTimer += deltaTime;

      // 无敌闪烁效果
      if (_player.flashTimer >= ParamConstants.playerFlashIntervalSeconds) {
        _player.flash = !_player.flash;
        _player.flashTimer = 0;
      }

      if (_player.invincibleTimer <= 0) {
        _player.flash = false;
        _player.color = ColorConstants.playerColor;
      }
    }

    // 处理道具效果过期
    if (_player.tripleShot) {
      _player.tripleShotTimer -= deltaTime;
    }

    if (_player.flameBullet) {
      _player.flameBulletTimer -= deltaTime;
    }

    if (_player.bigBullet) {
      _player.bigBulletTimer -= deltaTime;
    }

    // 更新冷却时间
    if (_player.cooldown > 0) {
      _player.cooldown -= deltaTime;
    }
  }

  // 生成敌人
  void _spawnEnemies(double deltaTime) {
    final difficultyIncrease = _level * ParamConstants.difficultyIncrease;
    final spawnInterval =
        ParamConstants.enemySpawnInterval * (1 - difficultyIncrease);

    _enemySpawnTimer += deltaTime;

    if (_enemySpawnTimer >= spawnInterval) {
      _enemySpawnTimer = 0;
      Enemy newEnemy;

      if (hasBoss) {
        newEnemy = _createBossMissileEnemy(difficultyIncrease);
      } else {
        final enemyType = _determineEnemyType();
        newEnemy = _createRegularEnemy(enemyType, difficultyIncrease);
      }

      _enemies.add(newEnemy);
    }
  }

  // 确定常规敌人类型（基于概率）
  EnemyType _determineEnemyType() {
    final randomValue = _random.nextDouble();

    if (randomValue < ProbabilityConstants.enemyMissileSpawnRate) {
      return EnemyType.missile;
    } else if (randomValue <
        ProbabilityConstants.enemyMissileSpawnRate +
            ProbabilityConstants.enemyFastSpawnRate) {
      return EnemyType.fast;
    } else {
      return EnemyType.heavy;
    }
  }

  // 创建从Boss发射的导弹敌人
  Enemy _createBossMissileEnemy(double difficultyIncrease) {
    final baseSpeed = ParamConstants.enemyMissileSpeed;
    final baseHorizontalSpeed = ParamConstants.enemyMissileHorizontalSpeed;

    // 计算生成位置（Boss中心）
    final bossCenterX = _boss!.position.dx + _boss!.size.width / 2;
    final spawnX = bossCenterX - SizeConstants.enemyMissile.width / 2;
    final spawnY = _boss!.position.dy + _boss!.size.height / 2;

    return Enemy(
      position: Offset(spawnX, spawnY),
      size: SizeConstants.enemyMissile,
      type: EnemyType.missile,
      color: ColorConstants.enemyMissile,
      health: ParamConstants.enemyBaseHealth,
      speed: baseSpeed * (1 + difficultyIncrease),
      dx:
          (_random.nextDouble() - 0.5) *
          baseHorizontalSpeed *
          (1 + difficultyIncrease),
      probability: 0, // 导弹不掉落道具
    );
  }

  // 创建常规敌人
  Enemy _createRegularEnemy(EnemyType type, double difficultyIncrease) {
    late final Size size;
    late final Color color;
    late final int health;
    late final double baseSpeed;
    late final double baseDx;
    late final double dropRate;

    switch (type) {
      case EnemyType.missile:
        size = SizeConstants.enemyMissile;
        color = ColorConstants.enemyMissile;
        health = ParamConstants.enemyBaseHealth;
        baseSpeed = ParamConstants.enemyMissileSpeed;
        baseDx =
            (_random.nextDouble() - 0.5) *
            ParamConstants.enemyMissileHorizontalSpeed;
        dropRate = 0;
        break;
      case EnemyType.fast:
        size = SizeConstants.enemyFast;
        color = ColorConstants.enemyFast;
        health =
            ParamConstants.enemyBaseHealth +
            _random.nextInt(ParamConstants.bulletBaseDamage) +
            1;
        baseSpeed = ParamConstants.enemyFastSpeed;
        baseDx = 0;
        dropRate = ParamConstants.propDropRateBasic;
        break;
      case EnemyType.heavy:
      default:
        size = SizeConstants.enemyHeavy;
        color = ColorConstants.enemyHeavy;
        health = ParamConstants.enemyHeavyHealth;
        baseSpeed = ParamConstants.enemyHeavySpeed;
        baseDx = 0;
        dropRate = ParamConstants.propDropRateHeavy;
        break;
    }

    // 计算随机生成位置（确保在屏幕内）
    final spawnX = _random.nextDouble() * (_screenSize.width - size.width);

    return Enemy(
      position: Offset(spawnX, -size.height),
      size: size,
      type: type,
      color: color,
      health: health,
      speed: baseSpeed * (1 + difficultyIncrease),
      dx: baseDx * (1 + difficultyIncrease),
      probability: dropRate,
    );
  }

  // 更新敌人
  void _updateEnemies(double deltaTime) {
    for (var e in List.of(_enemies)) {
      double verticalDelta = e.speed * deltaTime;
      double horizontalDelta = e.dx * deltaTime;

      // boss只会纵向移动一段距离
      if (e.type == EnemyType.boss) {
        if (e.position.dy < _screenSize.height / 3) {
          horizontalDelta = 0;
        } else {
          verticalDelta = 0;
        }
      }

      // 移动敌人
      e.position += Offset(horizontalDelta, verticalDelta);
      if (e.position.dx <= 0 ||
          e.position.dx + e.size.width >= _screenSize.width) {
        e.dx = -e.dx; // 碰到边界反弹
      }

      // 敌人超出屏幕底部（逃脱）
      if (e.position.dy > _screenSize.height) {
        _enemies.remove(e);
        if (e.type.index > EnemyType.missile.index) {
          _enemiesKilled = 0;
          _score -= e.health;
          // 显示敌人逃脱信息
          pageNavigator.value = (context) {
            BannerTemplate.textBanner(
              context: context,
              text: S.enemyEscaped,
              duration: DurationConstants.text,
            );
          };
        }
      }
    }
  }

  // 更新子弹
  void _updateBullets(double deltaTime) {
    for (var bullet in List.of(_bullets)) {
      // 计算子弹角度对应的移动向量
      final radians = bullet.angle * pi / 180;
      final dx = sin(radians) * ParamConstants.bulletSpeed * deltaTime;
      final dy = -cos(radians) * ParamConstants.bulletSpeed * deltaTime;
      bullet.position += Offset(dx, dy);

      // 子弹超出屏幕范围则移除
      if (bullet.position.dy < -bullet.size.height ||
          bullet.position.dy > _screenSize.height ||
          bullet.position.dx < -bullet.size.width ||
          bullet.position.dx > _screenSize.width) {
        _bullets.remove(bullet);
      }
    }
  }

  // 检测子弹与敌人碰撞
  void _checkBulletEnemyCollisions() {
    for (var bullet in List.of(_bullets)) {
      for (var enemy in List.of(_enemies)) {
        if (_checkCollision(bullet.rect, enemy.rect)) {
          _bullets.remove(bullet);
          _deductEnemyHealth(enemy, bullet.config.damage);
          break;
        }
      }
    }
  }

  // 检测玩家与敌人碰撞
  void _checkPlayerEnemyCollisions() {
    if (_player.invincible) return;

    for (var enemy in List.of(_enemies)) {
      if (_checkCollision(_player.rect, enemy.rect)) {
        _enemiesKilled = 0;

        // 护盾效果处理
        if (_player.shield) {
          _player.shield = false;
          // 护盾碰敌人
          _deductEnemyHealth(enemy, ParamConstants.shieldOffsetDamage);
        } else {
          // 玩家碰敌人
          int enemyHealth = enemy.health;
          _deductEnemyHealth(enemy, _player.health);
          _deductPlayerHealth(enemyHealth);
        }

        break;
      }
    }
  }

  void _deductEnemyHealth(Enemy enemy, int damage) {
    enemy.health -= damage;

    // 敌人被消灭
    if (enemy.health <= 0) {
      _score += enemy.points;

      // 创建爆炸效果
      _explosions.add(
        Explosion(
          position:
              enemy.position +
              Offset(enemy.size.width / 2, enemy.size.height / 2),
          size: enemy.size.width,
        ),
      );

      // 生成道具
      _spawnGameProp(enemy.position, enemy.probability);

      // BOSS特殊处理
      if (enemy.type == EnemyType.boss) {
        _boss = null;
        _unlockAchievement(AchievementType.bossKill);
        _levelUp();
      } else if (enemy.type.index > EnemyType.missile.index) {
        _summonBoss++;
        _enemiesKilled++;

        // 检测是否需要生成BOSS
        int count =
            ParamConstants.enemyCountPerBoss +
            level * ParamConstants.enemyCountPerBossIncrement; // 难度提升

        if (_summonBoss >= count) {
          _summonBoss = 0;
          _spawnBoss();
        }

        // 解锁成就检测
        if (_enemiesKilled >= 8) {
          _unlockAchievement(AchievementType.eightKill);
        } else if (_enemiesKilled == 1) {
          _unlockAchievement(AchievementType.firstKill);
        }

        if (_score >= 1000) {
          _unlockAchievement(AchievementType.score1000);
        } else if (_score >= 500) {
          _unlockAchievement(AchievementType.score500);
        } else if (_score >= 100) {
          _unlockAchievement(AchievementType.score100);
        }
      }
      _enemies.remove(enemy);
    }
  }

  void _deductPlayerHealth(int damage) {
    _player.health -= damage;
    if (_player.health <= 0) {
      _gameOver();
    } else {
      _player.invincibleTimer = ParamConstants.invincibleDurationSeconds;
      _player.color = ColorConstants.invincibleColor;
      _player.flash = true;
    }
  }

  // 更新爆炸效果
  void _updateExplosions(double deltaTime) {
    for (var explosion in List.of(_explosions)) {
      explosion.update(deltaTime);
      if (explosion.finished) {
        _explosions.remove(explosion);
      }
    }
  }

  // 生成道具
  void _spawnGameProp(Offset position, double dropRate) {
    if (_random.nextDouble() > dropRate) return;

    PropType type;
    final random = _random.nextDouble();

    if (random < ProbabilityConstants.propTripleRate) {
      type = PropType.triple;
    } else if (random <
        ProbabilityConstants.propTripleRate +
            ProbabilityConstants.propBigRate) {
      type = PropType.big;
    } else if (random <
        ProbabilityConstants.propTripleRate +
            ProbabilityConstants.propBigRate +
            ProbabilityConstants.propFlameRate) {
      type = PropType.flame;
    } else {
      type = PropType.shield;
    }

    _props.add(
      GameProp(
        position: position,
        size: SizeConstants.prop,
        type: type,
        speed: ParamConstants.propSpeed,
      ),
    );
  }

  // 更新道具
  void _updateProps(double deltaTime) {
    for (var prop in List.of(_props)) {
      prop.position += Offset(0, prop.speed * deltaTime);
      // 道具超出屏幕则移除
      if (prop.position.dy > _screenSize.height) {
        _props.remove(prop);
      }

      // 玩家拾取道具
      if (_checkCollision(_player.rect, prop.rect)) {
        _props.remove(prop);
        switch (prop.type) {
          case PropType.triple:
            _player.tripleShotTimer = ParamConstants.propEffectDurationSeconds;
            break;
          case PropType.shield:
            _player.shield = true;
            break;
          case PropType.flame:
            _player.flameBulletTimer = ParamConstants.propEffectDurationSeconds;
            break;
          case PropType.big:
            _player.bigBulletTimer = ParamConstants.propEffectDurationSeconds;
            break;
        }
      }
    }
  }

  // 生成BOSS
  void _spawnBoss() {
    if (hasBoss) return;

    // 使用AlertBanner显示BOSS出现信息
    pageNavigator.value = (context) {
      BannerTemplate.alertBanner(
        context: context,
        text: S.bossAppear,
        duration: DurationConstants.alert,
      );
    };

    double speed = ParamConstants.enemyBossSpeed;
    double dx =
        ParamConstants.enemyBossHorizontalSpeed *
        (_random.nextBool()
            ? _random.nextDouble() + 1
            : _random.nextDouble() - 2); // boss横向速度随机但有最小值
    int health =
        ParamConstants.bossInitialHealth +
        ParamConstants.bossHealthIncrement * _level;

    final enemy = Enemy(
      position: Offset(
        _screenSize.width / 2 - SizeConstants.enemyBoss.width / 2,
        -SizeConstants.enemyBoss.height,
      ),
      size: SizeConstants.enemyBoss,
      type: EnemyType.boss,
      color: ColorConstants.enemyBoss,
      health: health,
      speed: speed * (1 + _level * ParamConstants.difficultyIncrease),
      dx: dx * (1 + _level * ParamConstants.difficultyIncrease),
      probability: ParamConstants.propDropRateBoss,
    );

    _enemies.add(enemy);
    _boss = enemy;
  }

  // 等级提升
  void _levelUp() {
    _level++;
    _state.value = GameState.levelUp;
    _levelUpTimer = 0;

    // 解锁等级成就
    if (_level >= 5) {
      _unlockAchievement(AchievementType.level5);
    }
    if (_level >= 10) {
      _unlockAchievement(AchievementType.level10);
    }
  }

  // 处理等级提升延迟
  void _handleLevelUp(double deltaTime) {
    _levelUpTimer += deltaTime;
    if (_levelUpTimer >= ParamConstants.levelUpDelaySeconds) {
      _state.value = GameState.playing;
    }
  }

  // 检测碰撞
  bool _checkCollision(Rect a, Rect b) => a.overlaps(b);

  // 解锁成就
  void _unlockAchievement(AchievementType type) {
    if (!_unlockedAchievements.contains(type)) {
      _unlockedAchievements.add(type);
      final achievement = Achievements.all.firstWhere((a) => a.type == type);

      pageNavigator.value = (context) {
        BannerTemplate.achieveBanner(
          context: context,
          title: achievement.title,
          description: achievement.description,
          duration: DurationConstants.achievement,
        );
      };
    }
  }

  // 初始化玩家
  void _resetPlayer() {
    _player = Player(
      position: Offset(
        _screenSize.width / 2 - SizeConstants.player.width / 2,
        _screenSize.height - SizeConstants.player.height - 20,
      ),
      size: SizeConstants.player,
      color: ColorConstants.playerColor,
      health: ParamConstants.playerInitialHealth,
      speed: ParamConstants.playerSpeed,
    );
  }

  /// 处理键盘事件
  void handleKeyEvent(KeyEvent event) {
    if (_state.value == GameState.playing) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowUp:
            handleDrag(Offset(0, -_player.speed));
            break;
          case LogicalKeyboardKey.arrowDown:
            handleDrag(Offset(0, _player.speed));
            break;
          case LogicalKeyboardKey.arrowLeft:
            handleDrag(Offset(-_player.speed, 0));
            break;
          case LogicalKeyboardKey.arrowRight:
            handleDrag(Offset(_player.speed, 0));
            break;
          case LogicalKeyboardKey.space:
            shoot();
            break;
        }
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyP) {
        toggleState();
      }
    } else if (_state.value == GameState.paused) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyP) {
        toggleState();
      }
    }
  }

  /// 处理拖动
  void handleDrag(Offset delta) {
    if (_state.value != GameState.playing) return;

    _player.position += Offset(
      delta.dx * _sensitivity,
      delta.dy * _sensitivity,
    );
    _keepPlayerInBounds();
  }

  /// 确保玩家在边界内
  void _keepPlayerInBounds() {
    double x = _player.position.dx;
    double y = _player.position.dy;

    x = x.clamp(0, _screenSize.width - _player.size.width);
    y = y.clamp(0, _screenSize.height - _player.size.height);

    _player.position = Offset(x, y);

    notifyListeners();
  }

  void _keepPlayerAtCenter() {
    _player.position = Offset(
      _screenSize.width / 2 - SizeConstants.player.width / 2,
      _screenSize.height - SizeConstants.player.height - 20,
    );

    notifyListeners();
  }

  // 开始游戏
  void startGame() {
    _resetState();
    _resetPlayer();
    _state.value = GameState.playing;
    notifyListeners();
  }

  void _resetState() {
    _enemies.clear();
    _bullets.clear();
    _props.clear();
    _explosions.clear();
    _unlockedAchievements.clear();

    _boss = null;
    _score = 0;
    _level = 0;
    _enemiesKilled = 0;
    _summonBoss = 0;
    _lastElapsed = 0;
    _enemySpawnTimer = 0;
    _levelUpTimer = 0;
  }

  void toggleState() {
    if (_state.value == GameState.playing) {
      _state.value = GameState.paused;
    } else if (_state.value == GameState.paused) {
      _state.value = GameState.playing;
    }
  }

  // 游戏结束
  void _gameOver() {
    _explosions.add(
      Explosion(
        position:
            _player.position +
            Offset(_player.size.width / 2, _player.size.height / 2),
        size: _player.size.width * 2,
      ),
    );
    _state.value = GameState.gameOver;
  }

  // 玩家射击
  void shoot() {
    if (_state.value != GameState.playing) return;

    if (_player.cooldown <= 0) {
      // 计算子弹配置
      int damage = ParamConstants.bulletBaseDamage;
      Color color = ColorConstants.bulletDefault;
      Size size = SizeConstants.bulletNormal;

      if (_player.bigBullet) {
        damage = (damage * ParamConstants.bulletBigMultiplier).round();
        size = SizeConstants.bulletBig;
      }

      if (_player.flameBullet) {
        damage = (damage * ParamConstants.bulletFlameMultiplier).round();
        color = PropTypeExtension.getColor(PropType.flame);
      }

      if (_player.tripleShot) {
        damage = (damage * ParamConstants.bulletTripleMultiplier).round();
      }

      final bulletConfig = BulletConfig(
        damage: damage,
        color: color,
        size: size,
      );

      // 三向射击逻辑
      if (_player.tripleShot) {
        _createBullet(
          angle: -ParamConstants.tripleShotAngle,
          config: bulletConfig,
        );
        _createBullet(angle: 0, config: bulletConfig);
        _createBullet(
          angle: ParamConstants.tripleShotAngle,
          config: bulletConfig,
        );
      } else {
        _createBullet(angle: 0, config: bulletConfig);
      }
      // 设置冷却时间
      _player.cooldown = _player.bigBullet
          ? ParamConstants.bigBulletCooldownSeconds
          : ParamConstants.bulletCooldownSeconds;
    }
  }

  // 创建子弹
  void _createBullet({required double angle, required BulletConfig config}) {
    // 计算子弹初始位置（玩家中心）
    final spawnX =
        _player.position.dx + _player.size.width / 2 - config.size.width / 2;
    final spawnY = _player.position.dy;

    _bullets.add(
      Bullet(position: Offset(spawnX, spawnY), angle: angle, config: config),
    );
  }

  /// 改变屏幕尺寸
  void changeSize(Size size) {
    if (_screenSize != size) {
      final wasZero = _screenSize == Size.zero;
      _screenSize = size;
      _initStars();
      wasZero ? _keepPlayerAtCenter() : _keepPlayerInBounds();
    }
  }

  void showSettingDialog() {
    pageNavigator.value = (context) => DialogTemplate.sliderDialog(
      context: context,
      title: S.sensitivitySetting,
      sliderData: SliderData(
        start: 0.1,
        end: 2.0,
        value: _sensitivity,
        step: 0.1,
      ),
      onConfirm: _changeSensitivity,
    );
  }

  void _changeSensitivity(double value) {
    _sensitivity = value;
  }

  // Getters（供UI层访问数据）
  ValueNotifier<GameState> get state => _state;
  Player get player => _player;
  int get lives => _player.health;
  int get score => _score;
  int get level => _level;
  List<Enemy> get enemies => _enemies;
  List<Bullet> get bullets => _bullets;
  List<GameProp> get props => _props;
  List<Star> get stars => _stars;
  List<Explosion> get explosions => _explosions;
  List<AchievementType> get unlockedAchievements => _unlockedAchievements;

  bool get hasBoss => _boss != null;
}
