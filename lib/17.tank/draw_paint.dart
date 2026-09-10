import 'dart:math';

import 'package:flutter/material.dart';

import 'base.dart';
import 'foundation_manager.dart';

/// 坦克大战渲染层。单 painter 分层绘制，跟随 manager 自动重绘。
class TankPainter extends CustomPainter {
  final FoundationalTankManager manager;

  TankPainter({required this.manager}) : super(repaint: manager);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width, size.height) / mapSize;
    final offsetX = (size.width - mapSize * scale) / 2;
    final offsetY = (size.height - mapSize * scale) / 2;
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    _drawBackground(canvas);
    _drawTerrain(canvas); // 墙/水/基地（不遮挡坦克）
    _drawTanks(canvas);
    _drawBullets(canvas);
    _drawGrass(canvas); // 草地遮挡坦克（经典视野）
    _drawExplosions(canvas);
  }

  @override
  bool shouldRepaint(covariant TankPainter oldDelegate) => false;

  // ---- 背景 ----
  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, mapSize, mapSize),
      Paint()..color = const Color(0xFF1A1A1A),
    );
  }

  // ---- 地形 ----
  void _drawTerrain(Canvas canvas) {
    for (int row = 0; row < manager.map.rows; row++) {
      for (int col = 0; col < manager.map.cols; col++) {
        final tile = manager.map.tileAt(col, row);
        final rect = Rect.fromLTWH(
          col * tileSize,
          row * tileSize,
          tileSize,
          tileSize,
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
    canvas.drawRect(rect, Paint()..color = brickColor);
    final line = Paint()
      ..color = const Color(0xFF6D3F18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // 砖纹：四小块分隔
    canvas.drawLine(rect.topCenter, rect.bottomCenter, line);
    canvas.drawLine(
      Offset(rect.left, rect.top + tileSize / 2),
      Offset(rect.right, rect.top + tileSize / 2),
      line,
    );
  }

  void _drawSteel(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = steelColor);
    canvas.drawRect(
      rect.deflate(2),
      Paint()
        ..color = const Color(0xFFCFD3D8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawWater(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = waterColor);
    final wave = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final mid = rect.top + tileSize / 2;
    canvas.drawLine(Offset(rect.left + 4, mid - 4), Offset(rect.right - 4, mid - 4), wave);
    canvas.drawLine(Offset(rect.left + 4, mid + 4), Offset(rect.right - 4, mid + 4), wave);
  }

  void _drawBase(Canvas canvas, Rect rect) {
    if (manager.baseDestroyed) {
      canvas.drawRect(rect, Paint()..color = baseDestroyedColor);
      return;
    }
    canvas.drawRect(rect, Paint()..color = const Color(0xFF263238));
    // 鹰形（简化：金圆 + 翅膀三角）
    final center = rect.center;
    canvas.drawCircle(center, tileSize * 0.28, Paint()..color = baseColor);
    final wing = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    final path = Path()
      ..addPolygon([
        Offset(center.dx - tileSize * 0.4, center.dy),
        Offset(center.dx, center.dy - tileSize * 0.3),
        Offset(center.dx, center.dy + tileSize * 0.1),
      ], true);
    canvas.drawPath(path, wing);
  }

  // ---- 草地（上层遮挡） ----
  void _drawGrass(Canvas canvas) {
    final paint = Paint()
      ..color = grassColor.withValues(alpha: 0.85);
    for (int row = 0; row < manager.map.rows; row++) {
      for (int col = 0; col < manager.map.cols; col++) {
        if (manager.map.tileAt(col, row).type == TileType.grass) {
          canvas.drawRect(
            Rect.fromLTWH(col * tileSize, row * tileSize, tileSize, tileSize),
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
    // 无敌时闪烁（半透明）
    final alpha = tank.invincibleTimer > 0 ? 0.5 : 1.0;
    final body = tank.color.withValues(alpha: alpha);
    final track = const Color(0xFF37474F).withValues(alpha: alpha);
    final turret = Color.lerp(tank.color, Colors.black, 0.3)!
        .withValues(alpha: alpha);
    final half = tankSize / 2;

    // 车身（朝移动方向 angle）
    canvas.save();
    canvas.translate(tank.position.dx, tank.position.dy);
    canvas.rotate(tank.angle + pi / 2);
    // 履带底
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: tankSize * 0.8, height: tankSize),
      Paint()..color = track,
    );
    // 左右履带
    canvas.drawRect(
      Rect.fromLTWH(-half, -half, tankSize * 0.18, tankSize),
      Paint()..color = body,
    );
    canvas.drawRect(
      Rect.fromLTWH(half - tankSize * 0.18, -half, tankSize * 0.18, tankSize),
      Paint()..color = body,
    );
    // 车身主体
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: tankSize * 0.62, height: tankSize * 0.7),
      Paint()..color = body,
    );
    // 车头标识方块（区分正反，与两侧履带保持间距）
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -tankSize * 0.2),
        width: tankSize * 0.24,
        height: tankSize * 0.16,
      ),
      Paint()..color = Colors.black,
    );
    canvas.restore();

    // 炮塔（朝瞄准方向 turretAngle）
    canvas.save();
    canvas.translate(tank.position.dx, tank.position.dy);
    canvas.rotate(tank.turretAngle + pi / 2);
    canvas.drawCircle(Offset.zero, tankSize * 0.2, Paint()..color = turret);
    // 炮管（朝上，随炮塔旋转）
    canvas.drawRect(
      Rect.fromLTWH(-tankSize * 0.06, -half, tankSize * 0.12, tankSize * 0.5),
      Paint()..color = track,
    );
    canvas.restore();
  }

  // ---- 子弹 ----
  void _drawBullets(Canvas canvas) {
    for (final b in manager.bullets) {
      final isPlayer = b.ownerId >= 0;
      canvas.drawCircle(
        b.position,
        bulletSize / 2,
        Paint()..color = isPlayer ? bulletColor : enemyBulletColor,
      );
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
