import 'dart:math';

import 'package:flutter/material.dart';

import 'base.dart';
import 'foundation_manager.dart';

/// 坦克大战渲染层。单 painter 分层绘制，跟随 manager 自动重绘。
class TankPainter extends CustomPainter {
  final TankGameManager manager;

  TankPainter({required this.manager}) : super(repaint: manager);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width, size.height) / TankGameConfig.mapSize;
    final offsetX = (size.width - TankGameConfig.mapSize * scale) / 2;
    final offsetY = (size.height - TankGameConfig.mapSize * scale) / 2;
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    _drawBackground(canvas);
    _drawTerrain(canvas); // 墙/水/基地（不遮挡坦克）
    _drawTanks(canvas);
    _drawBullets(canvas);
    _drawGrass(canvas); // 草地遮挡坦克（经典视野）
    _drawPowerUps(canvas);
    _drawExplosions(canvas);
  }

  @override
  bool shouldRepaint(covariant TankPainter oldDelegate) => false;

  // ---- 背景 ----
  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, TankGameConfig.mapSize, TankGameConfig.mapSize),
      Paint()..color = const Color(0xFF1A1A1A),
    );
  }

  // ---- 地形 ----
  void _drawTerrain(Canvas canvas) {
    for (int row = 0; row < manager.map.rows; row++) {
      for (int col = 0; col < manager.map.cols; col++) {
        final tile = manager.map.tileAt(col, row);
        final rect = Rect.fromLTWH(
          col * TankGameConfig.tileSize,
          row * TankGameConfig.tileSize,
          TankGameConfig.tileSize,
          TankGameConfig.tileSize,
        );
        switch (tile.type) {
          case TileType.brick:
            _drawBrick(canvas, rect);
            break;
          case TileType.steel:
            _drawSteel(canvas, rect);
            break;
          case TileType.water:
            _drawWater(canvas, rect);
            break;
          case TileType.base:
            _drawBase(canvas, rect);
            break;
          default:
            break;
        }
      }
    }
  }

  void _drawBrick(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = TileType.brick.color);
    final line = Paint()
      ..color = const Color(0xFF6D3F18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // 错缝砖纹：一条水平缝 + 上下半层错开的竖缝，缝宽与墙间间隙一致
    final midY = rect.top + TankGameConfig.tileSize / 2;
    canvas.drawLine(Offset(rect.left, midY), Offset(rect.right, midY), line);
    canvas.drawLine(rect.topCenter, Offset(rect.center.dx, midY), line);
    final q1 = rect.left + TankGameConfig.tileSize * 0.25;
    final q3 = rect.left + TankGameConfig.tileSize * 0.75;
    canvas.drawLine(Offset(q1, midY), Offset(q1, rect.bottom), line);
    canvas.drawLine(Offset(q3, midY), Offset(q3, rect.bottom), line);
    // 外边框：让相邻土墙之间的间隙与内部砖缝同宽
    canvas.drawRect(rect, line);
  }

  void _drawSteel(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = TileType.steel.color);
    canvas.drawRect(
      rect.deflate(2),
      Paint()
        ..color = const Color(0xFFCFD3D8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawWater(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = TileType.water.color);
    final wave = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final mid = rect.top + TankGameConfig.tileSize / 2;
    canvas.drawLine(
      Offset(rect.left + 4, mid - 4),
      Offset(rect.right - 4, mid - 4),
      wave,
    );
    canvas.drawLine(
      Offset(rect.left + 4, mid + 4),
      Offset(rect.right - 4, mid + 4),
      wave,
    );
  }

  void _drawBase(Canvas canvas, Rect rect) {
    if (manager.baseDestroyed) {
      canvas.drawRect(rect, Paint()..color = TileType.baseDestroyedColor);
      return;
    }
    canvas.drawRect(rect, Paint()..color = const Color(0xFF263238));
    // 鹰形（简化：金圆 + 翅膀三角）
    final center = rect.center;
    canvas.drawCircle(
      center,
      TankGameConfig.tileSize * 0.28,
      Paint()..color = TileType.baseColor,
    );
    final wing = Paint()
      ..color = TileType.baseColor
      ..style = PaintingStyle.fill;
    final path = Path()
      ..addPolygon([
        Offset(center.dx - TankGameConfig.tileSize * 0.4, center.dy),
        Offset(center.dx, center.dy - TankGameConfig.tileSize * 0.3),
        Offset(center.dx, center.dy + TankGameConfig.tileSize * 0.1),
      ], true);
    canvas.drawPath(path, wing);
  }

  // ---- 草地（上层遮挡） ----
  void _drawGrass(Canvas canvas) {
    final paint = Paint()..color = TileType.grass.color.withValues(alpha: 0.85);
    for (int row = 0; row < manager.map.rows; row++) {
      for (int col = 0; col < manager.map.cols; col++) {
        if (manager.map.tileAt(col, row).type == TileType.grass) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * TankGameConfig.tileSize,
              row * TankGameConfig.tileSize,
              TankGameConfig.tileSize,
              TankGameConfig.tileSize,
            ),
            paint,
          );
        }
      }
    }
  }

  // ---- 坦克 ----
  void _drawTanks(Canvas canvas) {
    for (final tank in manager.tanks.values) {
      if (!tank.isAlive) continue;
      _drawTank(canvas, tank);
    }
  }

  void _drawTank(Canvas canvas, Tank tank) {
    // 无敌时不再变暗，仅以护盾环标识（与装甲受击黑化区分）
    final invincible = tank.invincibleTimer > 0;
    const alpha = 1.0;
    var body = tank.color.withValues(alpha: alpha);
    // 血量破损黑化（多血单位通用：敌方按类型满血，玩家按满血）
    final maxHp = tank.maxHealth;
    if (maxHp > 1) {
      final ratio = (tank.health / maxHp).clamp(0.0, 1.0);
      body = Color.lerp(
        body,
        Colors.black,
        (1 - ratio) * 0.45,
      )!.withValues(alpha: alpha);
    }
    final track = const Color(0xFF37474F).withValues(alpha: alpha);
    final turret = Color.lerp(
      body,
      Colors.black,
      0.3,
    )!.withValues(alpha: alpha);
    final size = tank.size; // 体型随敌方类型差异化
    final half = size / 2;

    // 无敌护盾环（白色，与玩家护盾的青色光环区分）
    if (invincible) {
      canvas.drawCircle(
        tank.position,
        size * 0.62,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // 玩家护盾光环（抵消一次攻击；火焰/跟踪子弹 buff 不显示光环）
    if (tank.isPlayer && tank.playerShieldTimer > 0) {
      canvas.drawCircle(
        tank.position,
        size * 0.62,
        Paint()
          ..color = const Color(0xFF26A69A).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // 车身（朝移动方向 angle）
    canvas.save();
    canvas.translate(tank.position.dx, tank.position.dy);
    canvas.rotate(tank.angle + pi / 2);
    // 履带底
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size * 0.8, height: size),
      Paint()..color = track,
    );
    // 左右履带
    canvas.drawRect(
      Rect.fromLTWH(-half, -half, size * 0.18, size),
      Paint()..color = body,
    );
    canvas.drawRect(
      Rect.fromLTWH(half - size * 0.18, -half, size * 0.18, size),
      Paint()..color = body,
    );
    // 车身主体
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: size * 0.62,
        height: size * 0.7,
      ),
      Paint()..color = body,
    );
    // 车头标识方块（区分正反，与两侧履带保持间距）
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -size * 0.2),
        width: size * 0.24,
        height: size * 0.16,
      ),
      Paint()..color = Colors.black,
    );
    canvas.restore();

    // 炮塔（朝瞄准方向 turretAngle）
    canvas.save();
    canvas.translate(tank.position.dx, tank.position.dy);
    canvas.rotate(tank.turretAngle + pi / 2);
    canvas.drawCircle(Offset.zero, size * 0.2, Paint()..color = turret);
    // 炮管（朝上，随炮塔旋转）
    canvas.drawRect(
      Rect.fromLTWH(-size * 0.06, -half, size * 0.12, size * 0.5),
      Paint()..color = track,
    );
    canvas.restore();
  }

  // ---- 子弹 ----
  void _drawBullets(Canvas canvas) {
    for (final b in manager.bullets) {
      final isPlayer = b.ownerId >= 0;
      final Color color;
      if (b.homing) {
        color = PowerUpType.homing.color; // 跟踪子弹紫
      } else if (b.damage > Bullet.baseDamage) {
        color = PowerUpType.fireBullet.color; // 强化子弹橙
      } else {
        color = isPlayer ? Bullet.playerColor : Bullet.enemyColor;
      }
      canvas.drawCircle(b.position, b.size / 2, Paint()..color = color);
    }
  }

  // ---- 道具 ----
  void _drawPowerUps(Canvas canvas) {
    for (final p in manager.powerups) {
      final c = p.rect.center;
      final r = TankGameConfig.tileSize * 0.32;
      canvas.drawCircle(
        c,
        r,
        Paint()..color = p.type.color.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final icon = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      switch (p.type) {
        case PowerUpType.shield:
          final path = Path()
            ..moveTo(c.dx, c.dy - r * 0.5)
            ..lineTo(c.dx + r * 0.4, c.dy)
            ..lineTo(c.dx + r * 0.3, c.dy + r * 0.4)
            ..lineTo(c.dx, c.dy + r * 0.6)
            ..lineTo(c.dx - r * 0.3, c.dy + r * 0.4)
            ..lineTo(c.dx - r * 0.4, c.dy)
            ..close();
          canvas.drawPath(path, icon);
          break;
        case PowerUpType.playerShield:
          // 玩家护盾：双层圆
          canvas.drawCircle(c, r * 0.55, icon);
          canvas.drawCircle(c, r * 0.3, icon);
          break;
        case PowerUpType.fireBullet:
          final path = Path()
            ..moveTo(c.dx, c.dy - r * 0.5)
            ..lineTo(c.dx + r * 0.4, c.dy + r * 0.4)
            ..lineTo(c.dx - r * 0.4, c.dy + r * 0.4)
            ..close();
          canvas.drawPath(path, icon);
          break;
        case PowerUpType.homing:
          canvas.drawLine(
            Offset(c.dx - r * 0.5, c.dy),
            Offset(c.dx + r * 0.5, c.dy),
            icon,
          );
          canvas.drawLine(
            Offset(c.dx, c.dy - r * 0.5),
            Offset(c.dx, c.dy + r * 0.5),
            icon,
          );
          canvas.drawCircle(c, r * 0.25, icon);
          break;
      }
    }
  }

  // ---- 爆炸 ----
  void _drawExplosions(Canvas canvas) {
    for (final e in manager.explosions) {
      final alpha = e.alpha.clamp(0.0, 1.0);
      for (final p in e.particles) {
        canvas.drawCircle(
          p.position,
          p.radius,
          Paint()..color = p.color.withValues(alpha: alpha),
        );
      }
    }
  }
}
