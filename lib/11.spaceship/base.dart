import 'dart:math';
import 'package:flutter/material.dart';

/// 游戏对象基类
abstract class GameObject {
  Offset position;
  final Size size;

  GameObject({required this.position, required this.size});

  Rect get rect => position & size;
}

/// 星星背景类
class Star extends GameObject {
  final double opacity;
  final double speed;

  Star({
    required super.position,
    required super.size,
    required this.opacity,
    required this.speed,
  });
}

/// 子弹属性配置
class BulletConfig {
  final int damage;
  final Color color;
  final Size size;

  BulletConfig({required this.damage, required this.color, required this.size});
}

/// 子弹类
class Bullet extends GameObject {
  final double angle;
  final BulletConfig config;

  Bullet({required super.position, required this.angle, required this.config})
    : super(size: config.size);
}

/// 道具类型枚举
enum PropType { shield, triple, big, flame }

/// 道具类
class GameProp extends GameObject {
  final PropType type;
  final double speed;

  GameProp({
    required super.position,
    required super.size,
    required this.type,
    required this.speed,
  });
}

/// 敌人类型枚举
enum EnemyType { missile, fast, heavy, boss }

/// 敌人类
class Enemy extends GameObject {
  final EnemyType type;
  final Color color;
  int health;
  final double speed; // 纵向每秒速度
  double dx; // 横向每秒速度
  final double probability; // 道具掉落概率
  final int points; // 分数

  Enemy({
    required super.position,
    required super.size,
    required this.type,
    required this.color,
    required this.health,
    required this.speed,
    required this.dx,
    required this.probability,
  }) : points = health;
}

/// 玩家类
class Player extends GameObject {
  Color color;
  int health; // 生命值
  double speed; // 移动速度

  double invincibleTimer = 0; // 无敌剩余时间（秒）
  bool flash = false; // 无敌时闪烁
  double flashTimer = 0; // 闪烁计时器（秒）

  bool shield = false; // 护盾
  double bigBulletTimer = 0; // 大子弹剩余时间（秒）
  double tripleShotTimer = 0; // 三向射击剩余时间（秒）
  double flameBulletTimer = 0; // 火焰子弹剩余时间（秒）
  double cooldown = 0; // 冷却剩余时间（秒）

  bool get invincible => invincibleTimer > 0;
  bool get bigBullet => bigBulletTimer > 0;
  bool get tripleShot => tripleShotTimer > 0;
  bool get flameBullet => flameBulletTimer > 0;

  Player({
    required super.position,
    required super.size,
    required this.color,
    required this.health,
    required this.speed,
  });
}

/// 爆炸粒子类
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

/// 爆炸效果类
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

  /// 更新爆炸状态（基于时间）
  void update(double deltaTime) {
    alpha -= deltaTime * 2; // 每秒减少2点透明度
    for (var p in particles) {
      p.position += p.velocity * deltaTime * 60; // 基于时间调整粒子速度
      p.life--;
    }
    particles.removeWhere((p) => p.life <= 0);
    finished = particles.isEmpty || alpha <= 0;
  }
}

/// 成就类型枚举
enum AchievementType {
  firstKill,
  score100,
  score500,
  score1000,
  level5,
  level10,
  bossKill,
  eightKill,
}

/// 成就配置类
class Achievement {
  final AchievementType type;
  final String title;
  final String description;

  Achievement({
    required this.type,
    required this.title,
    required this.description,
  });
}
