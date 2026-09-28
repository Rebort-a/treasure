import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../00.common/game/map.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/widget/input/joystick.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import 'base.dart';
import 'draw_paint.dart';
import 'foundation_manager.dart';

class TankGameScreen extends StatefulWidget {
  final TankGameManager manager;
  final bool showStateButton;
  final VoidCallback? onRestart;

  const TankGameScreen({
    super.key,
    required this.manager,
    required this.showStateButton,
    this.onRestart,
  });

  @override
  State<TankGameScreen> createState() => _TankGameScreenState();
}

class _TankGameScreenState extends State<TankGameScreen> {
  /// 当前按下的方向（按按下顺序），用于多键同按时取最新方向
  final List<Direction> _pressed = [];

  TankGameManager get manager => widget.manager;
  TankGameResult? _shownResult;

  @override
  void initState() {
    super.initState();
    manager.gameResult.addListener(_handleGameResult);
  }

  @override
  void didUpdateWidget(covariant TankGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager == manager) return;
    oldWidget.manager.gameResult.removeListener(_handleGameResult);
    manager.gameResult.addListener(_handleGameResult);
    _shownResult = null;
  }

  @override
  void dispose() {
    manager.gameResult.removeListener(_handleGameResult);
    super.dispose();
  }

  void _handleGameResult() {
    final result = manager.gameResult.value;
    if (result == null || identical(result, _shownResult)) return;
    _shownResult = result;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || manager.gameResult.value != result) return;
      _showGameResult(result);
    });
  }

  Future<void> _showGameResult(TankGameResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.gameOver),
        content: Text(
          '${result.victory ? S.victory : S.defeat}  ${result.score}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              manager.leavePage();
            },
            child: Text(S.exit),
          ),
          if (widget.onRestart != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onRestart!();
              },
              child: Text(S.restart),
            ),
        ],
      ),
    );
  }

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
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      return Direction.down;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
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
    return Material(
      color: Colors.black,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => _handleKeyEvent(event),
        onFocusChange: (hasFocus) {
          if (hasFocus || _pressed.isEmpty) return;
          _pressed.clear();
          manager.updatePlayerStop();
        },
        child: Stack(
          children: [
            NotifierNavigator(navigatorHandler: manager.pageNavigator),
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
                valueListenable: manager.isRunning,
                builder: (context, state, child) => Positioned(
                  top: 16,
                  right: 16,
                  child: _buildIconButton(
                    icon: state ? Icons.pause : Icons.play_arrow,
                    onPressed: manager.toggleState,
                  ),
                ),
              ),
            Positioned(
              top: 64,
              left: 12,
              child: AnimatedBuilder(
                animation: manager,
                builder: (_, _) => _buildHud(),
              ),
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
    final me = manager.tanks[manager.identity];

    // 每行一个信息项（图标 + 数值）
    final rows = <Widget>[
      _hudRow(Icons.star, Colors.amber, '${manager.score}'),
      _hudRow(Icons.military_tech, Colors.redAccent, '$enemiesLeft'),
      _hudRow(Icons.favorite, Colors.pinkAccent, '$lives'),
    ];
    if (manager.shieldTimer > 0) {
      rows.add(
        _hudRow(
          Icons.shield,
          Colors.lightBlue,
          manager.shieldTimer.toStringAsFixed(1),
        ),
      );
    }
    if (me != null) {
      if (me.fireBuffTimer > 0) {
        rows.add(
          _hudRow(
            Icons.local_fire_department,
            Colors.orange,
            me.fireBuffTimer.toStringAsFixed(1),
          ),
        );
      }
      if (me.homingBuffTimer > 0) {
        rows.add(
          _hudRow(
            Icons.gps_fixed,
            Colors.purpleAccent,
            me.homingBuffTimer.toStringAsFixed(1),
          ),
        );
      }
      if (me.playerShieldTimer > 0) {
        rows.add(
          _hudRow(
            Icons.security,
            Colors.tealAccent,
            me.playerShieldTimer.toStringAsFixed(1),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  /// 单行信息：小图标 + 数值。
  Widget _hudRow(IconData icon, Color color, String value) {
    const style = TextStyle(color: Colors.white, fontSize: 11, height: 1.3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(value, style: style.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
