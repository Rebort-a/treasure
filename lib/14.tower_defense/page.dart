import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import '../00.common/widget/container/glass_container.dart';
import '../00.common/widget/button/cool_button.dart';
import 'base.dart';
import 'manager.dart';

class TowerDefensePage extends StatefulWidget {
  const TowerDefensePage({super.key});

  @override
  State<TowerDefensePage> createState() => _TowerDefensePageState();
}

class _TowerDefensePageState extends State<TowerDefensePage>
    with SingleTickerProviderStateMixin {
  late final Manager _manager;
  late final AnimationController _ticker;
  bool _mapInitialized = false;

  @override
  void initState() {
    super.initState();
    _manager = Manager();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_onTick)
          ..repeat();
  }

  void _onTick() {
    _manager.update(1 / 60);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.towerDefense),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _ticker.stop();
              setState(
                () => _manager.initGame(
                  width: _manager.map.width,
                  height: _manager.map.height,
                ),
              );
              _ticker.repeat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHud(),
          Expanded(child: _buildGameArea()),
        ],
      ),
    );
  }

  Widget _buildHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.black87,
      child: Row(
        children: [
          Expanded(
            child: _hudItem(Icons.monetization_on, Colors.amber, _manager.gold),
          ),
          Expanded(child: _hudItem(Icons.favorite, Colors.red, _manager.lives)),
          Expanded(
            child: _hudItem(
              Icons.waves,
              Colors.cyan,
              _manager.waveNumber,
              prefix: 'W',
            ),
          ),
          Expanded(
            child: _hudItem(Icons.whatshot, Colors.orange, _manager.kills),
          ),
          Expanded(
            child: _hudItem(
              Icons.directions_run,
              Colors.grey,
              _manager.escaped,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudItem(
    IconData icon,
    Color color,
    ValueListenable<int> listenable, {
    String prefix = '',
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: listenable,
      builder: (_, value, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$prefix$value',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ==================== 战场区 ====================

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cellSize = Manager.cellSize;
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        final w = (availW / cellSize).floor().clamp(1, 60);
        final h = ((availH - 56) / cellSize).floor().clamp(1, 60); // 预留底部面板区
        if (!_mapInitialized) {
          _mapInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _manager.initGame(width: w, height: h));
            }
          });
          return const SizedBox.shrink();
        }
        final mapW = _manager.map.width * cellSize;
        final mapH = _manager.map.height * cellSize;
        return Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTapUp: (details) => _handleTap(details),
                child: CustomPaint(
                  size: Size(mapW, mapH),
                  painter: _GamePainter(_manager),
                ),
              ),
            ),
            ValueListenableBuilder<GameState>(
              valueListenable: _manager.state,
              builder: (_, state, __) {
                if (state == GameState.preparing) return _buildStartFloat();
                if (state == GameState.won || state == GameState.lost) {
                  return _buildResultFloat(state == GameState.won);
                }
                return const SizedBox.shrink();
              },
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _buildBuildPanel()),
          ],
        );
      },
    );
  }

  Widget _buildStartFloat() {
    return Positioned.fill(
      child: Center(
        child: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.towerDefense,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${S.startWave} #${_manager.waveNumber.value + 1}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              CoolButton(
                text: S.startGame,
                icon: Icons.play_arrow,
                onTap: _manager.startNextWave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultFloat(bool won) {
    return Positioned.fill(
      child: Center(
        child: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? S.victory : S.defeat,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: won ? Colors.amber : Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _ticker.stop();
                  setState(
                    () => _manager.initGame(
                      width: _manager.map.width,
                      height: _manager.map.height,
                    ),
                  );
                  _ticker.repeat();
                },
                child: Text(S.startNewGame),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 点击交互 ====================

  void _handleTap(TapUpDetails details) {
    final cellSize = Manager.cellSize;
    final x = (details.localPosition.dx / cellSize).floor();
    final y = (details.localPosition.dy / cellSize).floor();
    if (!_manager.map.inBounds(x, y)) return;

    final cell = _manager.map.cells[y][x];
    if (cell == CellType.tower) {
      // 区分空墙 vs 堡垒
      Tower? t;
      for (final tw in _manager.towers.value) {
        if (tw.pos.x == x && tw.pos.y == y) {
          t = tw;
          break;
        }
      }
      if (t != null) {
        // 点堡垒→升级
        setState(() {
          _manager.selectFort(GridPos(x, y));
          _manager.selectWall(null);
        });
      } else {
        // 点空墙→建塔（默认 Archer）
        setState(() {
          _manager.selectWall(GridPos(x, y));
          _manager.selectFort(null);
          _manager.selectTowerType(TowerType.archer);
        });
      }
    } else {
      // enter/exit/road→收起
      setState(() {
        _manager.selectWall(null);
        _manager.selectFort(null);
      });
    }
  }

  // ==================== 底部面板（建塔/升级统一） ====================

  Widget _buildBuildPanel() {
    return ValueListenableBuilder<GridPos?>(
      valueListenable: _manager.selectedWall,
      builder: (_, wall, __) {
        return ValueListenableBuilder<GridPos?>(
          valueListenable: _manager.selectedFort,
          builder: (_, fort, __) {
            if (wall != null) return _buildBuildTowerPanel(wall);
            if (fort != null) return _buildUpgradePanel(fort);
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  /// 建塔面板：3 起点（wall/archer/ice）+ 确认
  Widget _buildBuildTowerPanel(GridPos wall) {
    return ValueListenableBuilder<TowerType?>(
      valueListenable: _manager.selectedTower,
      builder: (_, selected, __) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: Colors.grey[900],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...[
                TowerType.wall,
                TowerType.archer,
                TowerType.ice,
              ].map((t) => _buildTowerOption(t, selected)),
              ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () {
                        final ok = _manager.placeTower(wall, selected);
                        setState(() {
                          if (ok) _manager.selectWall(null);
                          _manager.selectTowerType(null);
                        });
                      },
                child: Text(S.confirm),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 升级面板：多分支（archer→cannon|spear 两按钮，wall→fortress，ice→magic）
  Widget _buildUpgradePanel(GridPos fortPos) {
    Tower? tower;
    for (final t in _manager.towers.value) {
      if (t.pos.x == fortPos.x && t.pos.y == fortPos.y) {
        tower = t;
        break;
      }
    }
    if (tower == null) return const SizedBox.shrink();
    final fort = tower;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            '${towerEmoji(fort.type)} ${fort.config.name}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          Text(
            'HP ${fort.hp}/${fort.maxHp}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          if (fort.canUpgrade)
            ...fort.upgrades.map(
              (toType) => ElevatedButton(
                onPressed: () =>
                    setState(() => _manager.upgradeTower(fort, toType)),
                child: Text(
                  '${towerEmoji(toType)} ${TowerConfigs.getConfig(toType).name}(${fort.upgradeCost}g)',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            )
          else
            const Text(
              '已满级',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          TextButton(
            onPressed: () => setState(() => _manager.selectFort(null)),
            child: Text(S.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildTowerOption(TowerType type, TowerType? selected) {
    final config = TowerConfigs.getConfig(type);
    final isSelected = selected == type;
    return GestureDetector(
      onTap: () =>
          setState(() => _manager.selectTowerType(isSelected ? null : type)),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: TowerColors.get(type),
          border: Border.all(
            color: isSelected ? TowerColors.get(type) : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(towerEmoji(type), style: const TextStyle(fontSize: 20)),
            Text(
              config.name,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              '${config.cost}g',
              style: const TextStyle(color: Colors.amber, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 游戏画面绘制 ====================

class _GamePainter extends CustomPainter {
  final Manager manager;
  _GamePainter(this.manager);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = Manager.cellSize;
    final map = manager.map;

    // 网格：tower/enter/exit/road + 空墙血条 + 网格线
    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );
        final cell = map.cells[y][x];
        final color = switch (cell) {
          CellType.tower => const Color(0xFF3E2723),
          CellType.enter => const Color(0xFF2E7D32),
          CellType.exit => const Color(0xFFC62828),
          CellType.road => const Color(0xFF8D6E63),
        };
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black26
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
        // 空墙血条（wallHp 0~100，<100 受损）
        if (cell == CellType.tower) {
          final hp = map.wallHp[y][x];
          if (hp > 0 && hp < 100) {
            final barRect = Rect.fromLTWH(
              rect.left,
              rect.bottom - 3,
              rect.width,
              3,
            );
            canvas.drawRect(barRect, Paint()..color = Colors.black54);
            canvas.drawRect(
              Rect.fromLTWH(
                barRect.left,
                barRect.top,
                barRect.width * hp / 100,
                3,
              ),
              Paint()
                ..color = hp > 50
                    ? Colors.green
                    : (hp > 25 ? Colors.orange : Colors.red),
            );
          }
        }
      }
    }

    // 选中堡垒攻击范围（非 wall/fortress）
    final selFort = manager.selectedFort.value;
    if (selFort != null) {
      for (final tower in manager.towers.value) {
        if (tower.pos.x == selFort.x && tower.pos.y == selFort.y) {
          if (tower.canAttack) {
            final center = Offset(
              (tower.pos.x + 0.5) * cellSize,
              (tower.pos.y + 0.5) * cellSize,
            );
            canvas.drawCircle(
              center,
              tower.range * cellSize,
              Paint()
                ..color = TowerColors.get(tower.type).withValues(alpha: 0.15)
                ..style = PaintingStyle.fill,
            );
            canvas.drawCircle(
              center,
              tower.range * cellSize,
              Paint()
                ..color = TowerColors.get(tower.type).withValues(alpha: 0.5)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
          break;
        }
      }
    }

    // 堡垒：图标+血条
    for (final tower in manager.towers.value) {
      final rect = Rect.fromLTWH(
        tower.pos.x * cellSize + 2,
        tower.pos.y * cellSize + 2,
        cellSize - 4,
        cellSize - 4,
      );
      // 确认后：道具本身背景色
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = TowerColors.get(tower.type),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: towerEmoji(tower.type),
          style: const TextStyle(fontSize: 20),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
      );
      tp.dispose();
      final hpRatio = (tower.hp / tower.maxHp).clamp(0.0, 1.0);
      final barRect = Rect.fromLTWH(rect.left, rect.bottom - 3, rect.width, 3);
      canvas.drawRect(barRect, Paint()..color = Colors.black54);
      canvas.drawRect(
        Rect.fromLTWH(barRect.left, barRect.top, barRect.width * hpRatio, 3),
        Paint()
          ..color = hpRatio > 0.5
              ? Colors.green
              : (hpRatio > 0.25 ? Colors.orange : Colors.red),
      );
    }

    // 预览（未确认建塔：道路色圆角矩形+图标+攻击范围）
    final selWall = manager.selectedWall.value;
    final selType = manager.selectedTower.value;
    if (selWall != null && selType != null) {
      final center = Offset(
        (selWall.x + 0.5) * cellSize,
        (selWall.y + 0.5) * cellSize,
      );
      final cfg = TowerConfigs.getConfig(selType);
      if (cfg.fireRate > 0) {
        canvas.drawCircle(
          center,
          cfg.range * cellSize,
          Paint()
            ..color = TowerColors.get(selType).withValues(alpha: 0.15)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          cfg.range * cellSize,
          Paint()
            ..color = TowerColors.get(selType).withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      final rect = Rect.fromLTWH(
        selWall.x * cellSize + 2,
        selWall.y * cellSize + 2,
        cellSize - 4,
        cellSize - 4,
      );
      // 预览：保持 tower 背景，只画图标（不换背景）
      final tp = TextPainter(
        text: TextSpan(
          text: towerEmoji(selType),
          style: const TextStyle(fontSize: 20),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
      );
      tp.dispose();
    }

    // 敌人
    for (final enemy in manager.enemies.value) {
      if (!enemy.alive) continue;
      final pos = manager.getEnemyPixelPos(enemy);
      final color = EnemyColors.get(enemy.type);
      final radius = enemy.type == EnemyType.boss ? 10.0 : 7.0;
      canvas.drawCircle(pos, radius, Paint()..color = color);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = Colors.black45
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final hpRatio = (enemy.hp / enemy.config.maxHp).clamp(0.0, 1.0);
      if (hpRatio < 1.0) {
        final barW = radius * 2;
        canvas.drawRect(
          Rect.fromLTWH(pos.dx - radius, pos.dy - radius - 5, barW, 3),
          Paint()..color = Colors.black54,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            pos.dx - radius,
            pos.dy - radius - 5,
            barW * hpRatio,
            3,
          ),
          Paint()
            ..color = hpRatio > 0.5
                ? Colors.green
                : (hpRatio > 0.25 ? Colors.orange : Colors.red),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
