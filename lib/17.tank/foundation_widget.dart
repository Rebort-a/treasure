import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../00.common/widget/input/joystick.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import 'base.dart';
import 'draw_paint.dart';
import 'foundation_manager.dart';

class GameScreen extends StatefulWidget {
  final FoundationalTankManager manager;
  final bool showStateButton;

  const GameScreen({
    super.key,
    required this.manager,
    required this.showStateButton,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// 当前按下的方向（按按下顺序），用于多键同按时取最新方向
  final List<Direction> _pressed = [];

  FoundationalTankManager get manager => widget.manager;

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;
    if (!isDown && !isUp) return KeyEventResult.ignored;

    final dir = _keyToDirection(event.logicalKey);
    if (dir != null) {
      if (isDown) {
        if (!_pressed.contains(dir)) {
          _pressed.add(dir);
          _applyMove();
        }
      } else {
        _pressed.remove(dir);
        _applyMove();
      }
      return KeyEventResult.handled;
    }
    if (isDown && event.logicalKey == LogicalKeyboardKey.space) {
      manager.updatePlayerFire();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 依据按下的方向集合应用移动：空则停止，否则取最新按下方向（车身+炮塔同向）
  void _applyMove() {
    if (_pressed.isEmpty) {
      manager.updatePlayerStop();
    } else {
      manager.updatePlayerMove(_pressed.last.angle);
    }
  }

  Direction? _keyToDirection(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      return Direction.up;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      return Direction.down;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      return Direction.left;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      return Direction.right;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _handleKeyEvent(event),
      child: Stack(
        children: [
          const ColoredBox(color: Colors.black, child: SizedBox.expand()),
          NotifierNavigator(navigatorHandler: manager.pageNavigator),
          AnimatedBuilder(
            animation: manager,
            builder: (context, _) {
              return Stack(
                children: [
                  SizedBox.expand(
                    child: CustomPaint(painter: TankPainter(manager: manager)),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _buildIconButton(
                      icon: Icons.arrow_back,
                      onPressed: manager.leavePage,
                    ),
                  ),
                  if (widget.showStateButton)
                    ValueListenableBuilder(
                      valueListenable: manager.gameState,
                      builder: (context, state, child) {
                        return Positioned(
                          top: 16,
                          right: 16,
                          child: _buildIconButton(
                            icon: state ? Icons.pause : Icons.play_arrow,
                            onPressed: () => manager.toggleState(),
                          ),
                        );
                      },
                    ),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: _buildHud(),
                  ),
                ],
              );
            },
          ),
          // 左摇杆：移动（无极方向）
          Positioned(
            left: 24,
            bottom: 32,
            child: Joystick(
              onDrag: (radians) => manager.updatePlayerMove(radians),
              onRelease: () {
                if (_pressed.isEmpty) {
                  manager.updatePlayerStop();
                } else {
                  _applyMove();
                }
              },
            ),
          ),
          // 右摇杆：瞄准 + 按住持续开火（无极方向）
          Positioned(
            right: 24,
            bottom: 32,
            child: Joystick(
              icon: Icons.local_fire_department,
              color: Colors.deepOrange.withValues(alpha: 0.85),
              onDrag: (radians) => manager.updatePlayerAim(radians),
              onRelease: () => manager.updatePlayerAimStop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(22),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 22,
      ),
    );
  }

  Widget _buildHud() {
    final lives = manager.livesByPlayer[manager.identity] ?? 0;
    final enemiesLeft = manager.remainingEnemies + manager.enemiesOnField;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(
              '${manager.score}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.military_tech, color: Colors.redAccent, size: 18),
            const SizedBox(width: 4),
            Text(
              '$enemiesLeft',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.favorite, color: Colors.pinkAccent, size: 18),
            const SizedBox(width: 4),
            Text(
              '$lives',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
