import 'dart:math';
import 'package:flutter/material.dart';

import '../00.common/widget/button/cool_button.dart';
import '../00.common/widget/container/glass_container.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'constant.dart';
import 'manager.dart';

class SpaceShipPage extends StatelessWidget {
  final _manager = Manager();

  SpaceShipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildGameView(context));
  }

  Widget _buildGameView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _manager.changeSize(constraints.biggest);

        return AnimatedBuilder(
          animation: _manager,
          builder: (_, __) {
            return Stack(
              children: [
                // 游戏画布
                CustomPaint(
                  size: Size.infinite,
                  painter: GamePainter(_manager),
                ),

                // 手势控制
                GestureDetector(
                  onPanUpdate: (details) => _manager.handleDrag(details.delta),
                  onTapDown: (_) => _manager.shoot(),
                ),

                // 键盘监听
                KeyboardListener(
                  focusNode: _manager.focusNode,
                  onKeyEvent: _manager.handleKeyEvent,
                  child: const SizedBox.expand(),
                ),

                // 导航控制
                NotifierNavigator(navigatorHandler: _manager.pageNavigator),

                // 玩家信息
                _buildInfoArea(context),

                // 游戏状态UI
                _buildFloatArea(context),

                // 暂停/继续按钮
                _buildControlButton(context),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFloatArea(BuildContext context) {
    return ValueListenableBuilder<GameState>(
      valueListenable: _manager.state,
      builder: (context, value, _) {
        switch (value) {
          case GameState.start:
            return _buildStartFloat(context);
          case GameState.playing:
            return const SizedBox.shrink();
          case GameState.paused:
            return _buildPauseFloat(context);
          case GameState.gameOver:
            return _buildGameOverFloat(context);
          case GameState.levelUp:
            return _buildLevelUpFloat();
        }
      },
    );
  }

  Widget _buildInfoArea(BuildContext context) {
    return Positioned(
      top: 32,
      left: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.lives(_manager.lives / 10),
            style: TextStyleConstants.info.copyWith(
              color: ColorConstants.textCyan,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.score(_manager.score),
            style: TextStyleConstants.info.copyWith(
              color: ColorConstants.textYellow,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.level(_manager.level),
            style: TextStyleConstants.info.copyWith(
              color: ColorConstants.textGreen,
            ),
          ),
          const SizedBox(height: 4),
          _buildPropIndicators(),
        ],
      ),
    );
  }

  Widget _buildControlButton(BuildContext context) {
    return Positioned(
      top: 32,
      right: 10,
      child: ValueListenableBuilder<GameState>(
        valueListenable: _manager.state,
        builder: (context, value, _) {
          return _buildIconButton(
            icon: value == GameState.playing ? Icons.pause : Icons.play_arrow,
            onPressed: _manager.toggleState,
          );
        },
      ),
    );
  }

  Widget _buildStartFloat(BuildContext context) {
    return Center(
      child: GlassContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(S.spaceship, style: TextStyleConstants.title),
            const SizedBox(height: 40),
            CoolButton(
              text: S.startGame,
              icon: Icons.play_arrow,
              onTap: _manager.startGame,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseFloat(BuildContext context) {
    return Center(
      child: GlassContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(S.gamePaused, style: TextStyleConstants.title),
            const SizedBox(height: 30),
            _buildActionButton(
              text: S.continueGame,
              color: Colors.blue,
              onPressed: _manager.toggleState,
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              text: S.settings,
              color: Colors.green,
              onPressed: _manager.showSettingDialog,
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              text: S.restartGame,
              color: Colors.white,
              onPressed: _manager.startGame,
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              text: S.exitGame,
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelUpFloat() {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              S.levelUp,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.currentLevel(_manager.level),
              style: TextStyleConstants.info.copyWith(
                color: ColorConstants.textCyan,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.harderChallenge,
              style: TextStyle(color: ColorConstants.textYellow, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverFloat(BuildContext context) {
    return Center(
      child: GlassContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.gameOver,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: ColorConstants.textNeonPink,
              ),
            ),
            const SizedBox(height: 20),
            _buildScoreItem(S.finalScore, _manager.score.toString()),
            _buildScoreItem(S.reachedLevel, _manager.level.toString()),
            const SizedBox(height: 20),
            Text(
              S.unlockedAchievement,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 10),
            _buildAchievementsList(),
            const SizedBox(height: 20),
            _buildActionButton(
              text: S.playAgain,
              color: ColorConstants.playerColor,
              onPressed: _manager.startGame,
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              text: S.backToHome,
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: color),
        ),
      ),
      child: Text(text, style: TextStyle(fontSize: 18, color: color)),
    );
  }

  Widget _buildScoreItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 200,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(fontSize: 18, color: Colors.cyanAccent),
              ),
            ),
            const Spacer(flex: 1),
            Expanded(
              flex: 1,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsList() {
    final unlocked = _manager.unlockedAchievements;
    if (unlocked.isEmpty) {
      return Text(
        S.noAchievements,
        style: const TextStyle(color: Colors.white70),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var type in unlocked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              Achievements.all.firstWhere((a) => a.type == type).title,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPropIndicators() {
    final player = _manager.player;
    return Row(
      children: [
        if (player.tripleShot)
          _buildPropIndicator(
            type: PropType.triple,
            duration: player.tripleShotTimer,
          ),
        if (player.flameBullet)
          _buildPropIndicator(
            type: PropType.flame,
            duration: player.flameBulletTimer,
          ),
        if (player.bigBullet)
          _buildPropIndicator(
            type: PropType.big,
            duration: player.bigBulletTimer,
          ),
      ],
    );
  }

  Widget _buildPropIndicator({
    required PropType type,
    required double duration,
  }) {
    Color color = PropTypeExtension.getColor(type);
    IconData icon = PropTypeExtension.getIcon(type);

    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(child: Icon(icon, color: color, size: 20)),
          ),
          if (duration > 0)
            Container(
              height: 3,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: LinearProgressIndicator(
                value: duration / ParamConstants.propEffectDurationSeconds,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// 游戏绘制器
class GamePainter extends CustomPainter {
  final Manager manager;
  final Paint _paint = Paint();

  GamePainter(this.manager) : super(repaint: manager);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawStars(canvas);
    _drawBullets(canvas);
    _drawEnemies(canvas);
    _drawProps(canvas);
    _drawExplosions(canvas);

    _drawPlayer(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  /// 绘制背景
  void _drawBackground(Canvas canvas, Size size) {
    _paint.color = ColorConstants.backgroundColor;
    _paint.style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _paint);
  }

  /// 绘制星空
  void _drawStars(Canvas canvas) {
    for (var star in manager.stars) {
      _paint.color = Color.fromRGBO(255, 255, 255, star.opacity);
      _paint.style = PaintingStyle.fill;
      canvas.drawCircle(star.position, star.size.width, _paint);
    }
  }

  /// 绘制玩家
  void _drawPlayer(Canvas canvas) {
    final player = manager.player;

    // 无敌状态闪烁效果
    if (player.flash) return;

    // 绘制护盾
    if (player.shield) {
      _drawShield(canvas, player);
    }

    // 绘制玩家主体
    _drawPlayerBody(canvas, player);

    // 绘制引擎效果
    _drawEngineEffect(canvas, player);
  }

  void _drawShield(Canvas canvas, Player player) {
    final center =
        player.position + Offset(player.size.width / 2, player.size.height / 2);
    final radius = player.size.width * 0.7;

    _paint.color = PropTypeExtension.getColor(
      PropType.shield,
    ).withValues(alpha: 0.5);
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2;
    canvas.drawCircle(center, radius, _paint);

    _paint.color = PropTypeExtension.getColor(
      PropType.shield,
    ).withValues(alpha: 0.3);
    canvas.drawCircle(center, radius * 1.14, _paint);
  }

  void _drawPlayerBody(Canvas canvas, Player player) {
    _paint.color = player.color;
    _paint.style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(player.position.dx + player.size.width / 2, player.position.dy);
    path.lineTo(player.position.dx, player.position.dy + player.size.height);
    path.lineTo(
      player.position.dx + player.size.width,
      player.position.dy + player.size.height,
    );
    path.close();
    canvas.drawPath(path, _paint);

    // 发光效果
    _paint.color = player.color.withValues(alpha: 0.5);
    final glowPath = Path();
    glowPath.moveTo(
      player.position.dx + player.size.width / 2,
      player.position.dy,
    );
    glowPath.lineTo(
      player.position.dx + 5,
      player.position.dy + player.size.height - 10,
    );
    glowPath.lineTo(
      player.position.dx + player.size.width - 5,
      player.position.dy + player.size.height - 10,
    );
    glowPath.close();
    canvas.drawPath(glowPath, _paint);

    // 绘制细节
    _paint.color = const Color(0xFF1E293B);
    canvas.drawRect(
      Rect.fromLTWH(
        player.position.dx + player.size.width / 2 - 5,
        player.position.dy + player.size.height / 2,
        10,
        15,
      ),
      _paint,
    );
  }

  void _drawEngineEffect(Canvas canvas, Player player) {
    _paint.color = ColorConstants.textNeonPink.withValues(alpha: 0.8);
    final enginePath = Path();
    enginePath.moveTo(
      player.position.dx + player.size.width / 2 - 8,
      player.position.dy + player.size.height,
    );
    enginePath.lineTo(
      player.position.dx + player.size.width / 2,
      player.position.dy + player.size.height + 10,
    );
    enginePath.lineTo(
      player.position.dx + player.size.width / 2 + 8,
      player.position.dy + player.size.height,
    );
    enginePath.close();
    canvas.drawPath(enginePath, _paint);
  }

  /// 绘制子弹
  void _drawBullets(Canvas canvas) {
    for (var bullet in manager.bullets) {
      _paint.color = bullet.config.color;
      _paint.style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(
          bullet.position.dx,
          bullet.position.dy,
          bullet.config.size.width,
          bullet.config.size.height,
        ),
        _paint,
      );

      // 子弹发光效果
      _paint.color = bullet.config.color.withValues(alpha: 0.5);
      canvas.drawRect(
        Rect.fromLTWH(
          bullet.position.dx - 1,
          bullet.position.dy - 2,
          bullet.config.size.width + 2,
          bullet.config.size.height + 4,
        ),
        _paint,
      );
    }
  }

  /// 绘制敌人
  void _drawEnemies(Canvas canvas) {
    for (var enemy in manager.enemies) {
      final paint = Paint()
        ..color = enemy.color
        ..style = PaintingStyle.fill;

      switch (enemy.type) {
        case EnemyType.fast:
          _drawBasicEnemy(canvas, enemy, paint);
          break;
        case EnemyType.missile:
          _drawFastEnemy(canvas, enemy, paint);
          break;
        case EnemyType.heavy:
          _drawHeavyEnemy(canvas, enemy, paint);
          break;
        case EnemyType.boss:
          _drawBossEnemy(canvas, enemy, paint);
          break;
      }
    }
  }

  /// 绘制基础敌人
  void _drawBasicEnemy(Canvas canvas, Enemy enemy, Paint paint) {
    final path = Path();
    path.moveTo(enemy.rect.center.dx, enemy.rect.top);
    path.lineTo(enemy.rect.left, enemy.rect.bottom);
    path.lineTo(enemy.rect.right, enemy.rect.bottom);
    path.close();
    canvas.drawPath(path, paint);

    // 高于10点时绘制保护罩
    if (enemy.health > ParamConstants.bulletBaseDamage) {
      final glowPaint = Paint()
        ..color = enemy.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      final glowPath = Path();
      glowPath.moveTo(enemy.rect.center.dx, enemy.rect.top - 5);
      glowPath.lineTo(enemy.rect.left - 5, enemy.rect.bottom);
      glowPath.lineTo(enemy.rect.right + 5, enemy.rect.bottom);
      glowPath.close();
      canvas.drawPath(glowPath, glowPaint);
    }
  }

  /// 绘制快速敌人
  void _drawFastEnemy(Canvas canvas, Enemy enemy, Paint paint) {
    final path = Path();
    path.moveTo(enemy.rect.center.dx, enemy.rect.top);
    path.lineTo(enemy.rect.right, enemy.rect.center.dy);
    path.lineTo(enemy.rect.center.dx, enemy.rect.bottom);
    path.lineTo(enemy.rect.left, enemy.rect.center.dy);
    path.close();
    canvas.drawPath(path, paint);

    final glowPaint = Paint()
      ..color = enemy.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final glowPath = Path();
    glowPath.moveTo(enemy.rect.center.dx, enemy.rect.top - 3);
    glowPath.lineTo(enemy.rect.right + 3, enemy.rect.center.dy);
    glowPath.lineTo(enemy.rect.center.dx, enemy.rect.bottom + 3);
    glowPath.lineTo(enemy.rect.left - 3, enemy.rect.center.dy);
    glowPath.close();
    canvas.drawPath(glowPath, glowPaint);
  }

  /// 绘制重型敌人
  void _drawHeavyEnemy(Canvas canvas, Enemy enemy, Paint paint) {
    canvas.drawRect(enemy.rect, paint);

    final detailPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        enemy.rect.left + 5,
        enemy.rect.top + 5,
        enemy.rect.width - 10,
        enemy.rect.height - 10,
      ),
      detailPaint,
    );

    final glowPaint = Paint()
      ..color = enemy.color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        enemy.rect.left - 3,
        enemy.rect.top - 3,
        enemy.rect.width + 6,
        enemy.rect.height + 6,
      ),
      glowPaint,
    );
  }

  /// 绘制BOSS敌人
  void _drawBossEnemy(Canvas canvas, Enemy enemy, Paint paint) {
    final centerX = enemy.rect.center.dx;
    final centerY = enemy.rect.center.dy;
    final radius = enemy.size.width / 2;

    // 绘制六边形
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = 2 * pi * i / 6;
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    // 绘制BOSS中心核心
    final corePaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), radius / 3, corePaint);

    // 绘制BOSS护盾效果
    final shieldPaint = Paint()
      ..color = enemy.color.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(centerX, centerY), radius + 10, shieldPaint);

    // 绘制BOSS生命值条
    final healthBarWidth = enemy.size.width * 0.8;
    final maxHealth = enemy.points;
    final healthPercent = enemy.health / maxHealth;
    final healthBarPaint = Paint()
      ..color = Color.lerp(Colors.red, Colors.green, healthPercent)!
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        centerX - healthBarWidth / 2,
        enemy.rect.top - 15,
        healthBarWidth * healthPercent,
        8,
      ),
      healthBarPaint,
    );

    // 生命值条边框
    final borderPaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(
        centerX - healthBarWidth / 2,
        enemy.rect.top - 15,
        healthBarWidth,
        8,
      ),
      borderPaint,
    );
  }

  /// 绘制道具
  void _drawProps(Canvas canvas) {
    for (var prop in manager.props) {
      Color color = PropTypeExtension.getColor(prop.type);
      IconData icon = PropTypeExtension.getIcon(prop.type);

      // 绘制道具主体
      _paint.color = color;
      _paint.style = PaintingStyle.fill;
      final center =
          prop.position + Offset(prop.size.width / 2, prop.size.height / 2);
      canvas.drawCircle(center, prop.size.width / 2, _paint);

      // 发光效果
      _paint.color = color.withAlpha(204);
      _paint.style = PaintingStyle.stroke;
      _paint.strokeWidth = 2;
      canvas.drawCircle(center, prop.size.width / 2 + 3, _paint);

      // 绘制图标
      _drawIcon(canvas, icon, center, prop.size, Colors.white);
    }
  }

  /// 绘制图标
  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    Size size,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: size.width * 0.6,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final iconOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, iconOffset);
  }

  /// 绘制爆炸效果
  void _drawExplosions(Canvas canvas) {
    for (var explosion in manager.explosions) {
      for (var particle in explosion.particles) {
        _paint.color = particle.color.withValues(alpha: explosion.alpha);
        _paint.style = PaintingStyle.fill;
        canvas.drawCircle(particle.position, particle.radius, _paint);
      }
    }
  }
}
