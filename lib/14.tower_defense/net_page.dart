import 'package:flutter/material.dart';

import '../00.common/network/network_room.dart';
import '../00.common/game/step.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';
import 'net_manager.dart';
import 'local_page.dart';

class NetTowerDefensePage extends StatelessWidget {
  late final NetManager _manager;

  NetTowerDefensePage({
    super.key,
    required RoomInfo roomInfo,
    required String userName,
  }) {
    _manager = NetManager(roomInfo: roomInfo, userName: userName);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, Object? result) {
      _manager.leavePage();
    },
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.netTowerDefense),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _manager.engine.leavePage,
        ),
      ),
      body: ValueListenableBuilder<GameStep>(
        valueListenable: _manager.engine.gameStep,
        builder: (_, step, __) {
          if (step == GameStep.action) {
            return _buildGameBody();
          }
          return Column(
            children: [
              NotifierNavigator(navigatorHandler: _manager.pageNavigator),
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(step.getExplanation(), style: const TextStyle(fontSize: 16)),
                ],
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGameBody() {
    return Column(
      children: [
        _buildHud(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (details) {
                  final cellSize = FoundationManager.cellSize;
                  final x = (details.localPosition.dx / cellSize).floor();
                  final y = (details.localPosition.dy / cellSize).floor();
                  if (_manager.map.inBounds(x, y) &&
                      _manager.selectedTower.value != null &&
                      _manager.map.canBuild(x, y)) {
                    _manager.placeTower(GridPos(x, y), _manager.selectedTower.value!);
                  }
                },
                child: CustomPaint(
                  size: Size(
                    _manager.map.width * FoundationManager.cellSize,
                    _manager.map.height * FoundationManager.cellSize,
                  ),
                  painter: _NetGamePainter(_manager),
                ),
              );
            },
          ),
        ),
        _buildShopPanel(),
      ],
    );
  }

  Widget _buildHud() {
    return ValueListenableBuilder6(
      _manager.gold,
      _manager.lives,
      _manager.waveNumber,
      _manager.state,
      _manager.kills,
      _manager.escaped,
      builder: (_, gold, lives, wave, state, kills, escaped, __) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black87,
          child: Row(
            children: [
              _hudItem(Icons.monetization_on, Colors.amber, '$gold'),
              const SizedBox(width: 12),
              _hudItem(Icons.favorite, Colors.red, '$lives'),
              const SizedBox(width: 12),
              _hudItem(Icons.waves, Colors.cyan, 'W$wave'),
              const SizedBox(width: 12),
              _hudItem(Icons.whatshot, Colors.orange, '$kills'),
              const SizedBox(width: 12),
              _hudItem(Icons.directions_run, Colors.grey, '$escaped'),
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
                onTap: () => _manager.selectTowerType(isSelected ? null : type),
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
                      Text(towerEmoji(type), style: const TextStyle(fontSize: 24)),
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

}

class _NetGamePainter extends CustomPainter {
  final NetManager manager;
  _NetGamePainter(this.manager);

  @override
  void paint(Canvas canvas, Size size) {
    // 复用本地绘制逻辑
    _GamePainterHelper.paint(canvas, size, manager);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 绘制逻辑复用
class _GamePainterHelper {
  static void paint(Canvas canvas, Size size, FoundationManager manager) {
    final cellSize = FoundationManager.cellSize;
    final map = manager.map;

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
      }
    }

    for (final tower in manager.towers.value) {
      final rect = Rect.fromLTWH(
        tower.pos.x * cellSize + 2, tower.pos.y * cellSize + 2,
        cellSize - 4, cellSize - 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = TowerColors.get(tower.type),
      );
      final tp = TextPainter(
        text: TextSpan(text: towerEmoji(tower.type), style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
    }

    for (final enemy in manager.enemies.value) {
      if (!enemy.alive) continue;
      final pos = manager.getEnemyPixelPos(enemy);
      final radius = enemy.type == EnemyType.boss ? 10.0 : 7.0;
      canvas.drawCircle(pos, radius, Paint()..color = EnemyColors.get(enemy.type));
    }
  }
}
