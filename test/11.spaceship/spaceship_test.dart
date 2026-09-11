import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/11.spaceship/base.dart';

void main() {
  test('GameObject.rect 使用位置和尺寸', () {
    final bullet = Bullet(
      position: const Offset(10, 20),
      angle: 0,
      config: BulletConfig(
        damage: 5,
        color: Colors.red,
        size: const Size(3, 7),
      ),
    );

    expect(bullet.rect, const Rect.fromLTWH(10, 20, 3, 7));
  });

  test('Enemy 分数固定为创建时生命值', () {
    final enemy = Enemy(
      position: Offset.zero,
      size: const Size(10, 10),
      type: EnemyType.heavy,
      color: Colors.grey,
      health: 80,
      speed: 1,
      dx: 0,
      probability: 0.2,
    );
    enemy.health = 10;

    expect(enemy.points, 80);
  });

  test('Player 道具 getter 由剩余时间驱动', () {
    final player = Player(
      position: Offset.zero,
      size: const Size(10, 10),
      color: Colors.blue,
      health: 3,
      speed: 100,
    );
    player
      ..invincibleTimer = 1
      ..bigBulletTimer = 1
      ..tripleShotTimer = 1
      ..flameBulletTimer = 1;

    expect(player.invincible, isTrue);
    expect(player.bigBullet, isTrue);
    expect(player.tripleShot, isTrue);
    expect(player.flameBullet, isTrue);
  });

  test('Explosion 按 deltaTime 衰减并最终结束', () {
    final explosion = Explosion(position: Offset.zero, size: 20);
    final before = explosion.alpha;

    explosion.update(0.1);
    expect(explosion.alpha, closeTo(before - 0.2, 1e-9));

    explosion.update(1);
    expect(explosion.finished, isTrue);
  });
}
