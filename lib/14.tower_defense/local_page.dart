import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';
import 'local_manager.dart';

class TowerDefensePage extends StatefulWidget {
  const TowerDefensePage({super.key});

  @override
  State<TowerDefensePage> createState() => _TowerDefensePageState();
}

class _TowerDefensePageState extends State<TowerDefensePage>
    with SingleTickerProviderStateMixin {
  late final LocalManager _manager;
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _manager = LocalManager();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() => _manager.update(1 / 60))
      ..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHud(),
          Expanded(child: _buildGameArea()),
          _buildShopPanel(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(S.towerDefense),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            _ticker.stop();
            setState(() => _manager.initGame());
            _ticker.repeat();
          },
        ),
      ],
    );
  }

  Widget _buildHud() {
    return ValueListenableBuilder4(
      _manager.gold,
      _manager.lives,
      _manager.waveNumber,
      _manager.state,
      builder: (context, gold, lives, wave, state, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black87,
          child: Row(
            children: [
              _hudItem(Icons.monetization_on, Colors.amber, '$gold'),
              const SizedBox(width: 16),
              _hudItem(Icons.favorite, Colors.red, '$lives'),
              const SizedBox(width: 16),
              _hudItem(Icons.waves, Colors.cyan, 'W$wave'),
              const Spacer(),
              if (state == GameState.playing)
                const Text('⚔️', style: TextStyle(fontSize: 18))
              else if (state == GameState.won)
                Text(S.victory, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))
              else if (state == GameState.lost)
                Text(S.defeat, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              else
                ElevatedButton(
                  onPressed: _manager.startNextWave,
                  child: Text(S.startWave),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _hudItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  Widget _buildGameArea() {
    return ValueListenableBuilder(
      valueListenable: _manager.towers,
      builder: (_, __, ___) {
        return ValueListenableBuilder(
          valueListenable: _manager.enemies,
          builder: (_, __, ___) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) => _handleTap(details, constraints),
                  child: CustomPaint(
                    size: Size(
                      _manager.map.width * FoundationManager.cellSize,
                      _manager.map.height * FoundationManager.cellSize,
                    ),
                    painter: _GamePainter(_manager),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final cellSize = FoundationManager.cellSize;
    final x = (details.localPosition.dx / cellSize).floor();
    final y = (details.localPosition.dy / cellSize).floor();

    if (!_manager.map.inBounds(x, y)) return;

    final selected = _manager.selectedTower.value;
    if (selected != null && _manager.map.canBuild(x, y)) {
      setState(() => _manager.placeTower(GridPos(x, y), selected));
    }
  }

  Widget _buildShopPanel() {
    return ValueListenableBuilder(
      valueListenable: _manager.selectedTower,
      builder: (_, selected, __) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.grey[900],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: TowerType.values.map((type) {
              final config = TowerConfigs.getConfig(type);
              final isSelected = selected == type;
              return GestureDetector(
                onTap: () => setState(() {
                  _manager.selectTowerType(isSelected ? null : type);
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? TowerColors.get(type).withValues(alpha: 0.3) : null,
                    border: Border.all(
                      color: isSelected ? TowerColors.get(type) : Colors.grey,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_towerEmoji(type), style: const TextStyle(fontSize: 24)),
                      Text(config.name, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      Text('${config.cost}g', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _towerEmoji(TowerType type) {
    return switch (type) {
      TowerType.arrow => '🏹',
      TowerType.cannon => '💣',
      TowerType.ice => '❄️',
      TowerType.magic => '🔮',
    };
  }
}

/// 游戏画面绘制
class _GamePainter extends CustomPainter {
  final FoundationManager manager;
  _GamePainter(this.manager);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = FoundationManager.cellSize;
    final map = manager.map;

    // 绘制背景网格
    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        final rect = Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        final cell = map.cells[y][x];
        final color = switch (cell) {
          CellType.path => const Color(0xFF8D6E63),
          CellType.tower => const Color(0xFF37474F),
          CellType.empty => const Color(0xFF4CAF50),
        };
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(rect, Paint()..color = Colors.black12..style = PaintingStyle.stroke..strokeWidth = 0.5);
      }
    }

    // 绘制路径箭头方向
    final path = map.path;
    for (int i = 0; i < path.length - 1; i++) {
      final cur = path[i];
      final next = path[i + 1];
      final cx = cur.x * cellSize + cellSize / 2;
      final cy = cur.y * cellSize + cellSize / 2;
      final nx = next.x * cellSize + cellSize / 2;
      final ny = next.y * cellSize + cellSize / 2;
      final mx = (cx + nx) / 2;
      final my = (cy + ny) / 2;
      canvas.drawCircle(Offset(mx, my), 2, Paint()..color = Colors.white38);
    }

    // 绘制起点/终点标记
    if (path.isNotEmpty) {
      final start = path.first;
      final end = path.last;
      _drawMarker(canvas, start.x, start.y, cellSize, Colors.green, 'S');
      _drawMarker(canvas, end.x, end.y, cellSize, Colors.red, 'E');
    }

    // 绘制防御塔
    for (final tower in manager.towers.value) {
      final rect = Rect.fromLTWH(
        tower.pos.x * cellSize + 2,
        tower.pos.y * cellSize + 2,
        cellSize - 4,
        cellSize - 4,
      );
      final color = TowerColors.get(tower.type);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = color,
      );

      // 等级指示
      if (tower.level > 1) {
        final starPaint = Paint()..color = Colors.amber;
        for (int i = 0; i < tower.level; i++) {
          canvas.drawCircle(
            Offset(rect.left + 6 + i * 8, rect.top + 6),
            2.5,
            starPaint,
          );
        }
      }

      // 范围指示（选中时）
      if (manager.selectedTower.value == tower.type) {
        canvas.drawCircle(
          Offset(rect.center.dx, rect.center.dy),
          tower.range * cellSize,
          Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.fill,
        );
      }
    }

    // 绘制敌人
    for (final enemy in manager.enemies.value) {
      if (!enemy.alive) continue;
      final pos = manager.getEnemyPixelPos(enemy);
      final color = EnemyColors.get(enemy.type);
      final radius = enemy.type == EnemyType.boss ? 10.0 : 7.0;

      canvas.drawCircle(pos, radius, Paint()..color = color);
      canvas.drawCircle(pos, radius, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 1);

      // 血条
      final hpRatio = enemy.hp / enemy.config.maxHp;
      if (hpRatio < 1.0) {
        final barWidth = radius * 2;
        final barRect = Rect.fromLTWH(pos.dx - radius, pos.dy - radius - 5, barWidth, 3);
        canvas.drawRect(barRect, Paint()..color = Colors.black54);
        canvas.drawRect(
          Rect.fromLTWH(barRect.left, barRect.top, barWidth * hpRatio, 3),
          Paint()..color = hpRatio > 0.5 ? Colors.green : (hpRatio > 0.25 ? Colors.orange : Colors.red),
        );
      }
    }
  }

  void _drawMarker(Canvas canvas, int x, int y, double cellSize, Color color, String label) {
    final rect = Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.3));
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 四值组合 ValueListenableBuilder
class ValueListenableBuilder4<A, B, C, D> extends StatelessWidget {
  final ValueListenable<A> a;
  final ValueListenable<B> b;
  final ValueListenable<C> c;
  final ValueListenable<D> d;
  final Widget Function(BuildContext, A, B, C, D, Widget?) builder;

  const ValueListenableBuilder4(this.a, this.b, this.c, this.d, {super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: a,
      builder: (_, va, __) => ValueListenableBuilder<B>(
        valueListenable: b,
        builder: (_, vb, __) => ValueListenableBuilder<C>(
          valueListenable: c,
          builder: (_, vc, __) => ValueListenableBuilder<D>(
            valueListenable: d,
            builder: (ctx, vd, ___) => builder(ctx, va, vb, vc, vd, null),
          ),
        ),
      ),
    );
  }
}
