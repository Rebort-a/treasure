import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../00.common/tool/notifiers.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

abstract class FoundationalManager extends ChangeNotifier
    implements TickerProvider {
  static const int initialLength = 100;
  static const double simulationStep = 1 / 120;
  static const double maxFrameTime = 0.1;
  static const int maxCatchUpSteps = 12;
  final Random _random = Random();

  final Map<int, Snake> snakes = {};
  final SpatialGrid foodGrid = SpatialGrid();

  late final Ticker _ticker;
  double _lastElapsed = 0;
  double _accumulator = 0;

  final pageNavigator = AlwaysNotifier<void Function(BuildContext)>((_) {});
  final gameState = ValueNotifier<bool>(false);

  int get identity;

  void addSnake(int id, int length) {
    if (snakes.containsKey(id)) return;
    final snake = _createSnake(length);
    snakes[id] = snake;
  }

  Snake _createSnake(int length) => Snake(
    head: randomSafePosition,
    length: _random.nextInt(length) + 30,
    angle: _random.nextDouble() * 2 * pi,
    style: SnakeStyle.random(),
  );

  Offset get randomSafePosition => Offset(
    _random.nextDouble() * (mapWidth - initialLength * 2) + initialLength,
    _random.nextDouble() * (mapHeight - initialLength * 2) + initialLength,
  );

  bool isInSafeRange(Offset position) {
    final isXValid =
        position.dx >= initialLength &&
        position.dx < (mapWidth - initialLength);
    final isYValid =
        position.dy >= initialLength &&
        position.dy < (mapHeight - initialLength);
    return isXValid && isYValid;
  }

  void addFood(Offset position) {
    if (getNearbyFoodPosition(position, SpatialGrid.cellSize * 4) == null &&
        isInSafeRange(position)) {
      foodGrid.insert(GridEntry(position, SpatialGrid.cellSize));
    }
  }

  Offset? getNearbyFoodPosition(Offset position, double threshold) {
    return foodGrid.checkCollision(position, threshold);
  }

  void initTicker() {
    _ticker = createTicker(_gameLoop);
  }

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  void resumeGame() {
    gameState.value = true;
    if (!_ticker.isActive) {
      _lastElapsed = 0;
      _accumulator = 0;
      _ticker.start();
    }
  }

  void suspendGame() {
    gameState.value = false;
    if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void toggleState() {
    if (gameState.value) {
      suspendGame();
    } else {
      resumeGame();
    }
  }

  void _gameLoop(Duration elapsed) {
    if (!gameState.value) return;

    final currentElapsed =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final deltaTime = max(0.0, currentElapsed - _lastElapsed);
    _lastElapsed = currentElapsed;
    _accumulator += min(deltaTime, maxFrameTime);

    var steps = 0;
    while (_accumulator >= simulationStep &&
        steps < maxCatchUpSteps &&
        gameState.value) {
      _simulateStep(simulationStep);
      _accumulator -= simulationStep;
      steps++;
    }
    if (steps == maxCatchUpSteps) {
      _accumulator = min(_accumulator, simulationStep);
    }
    if (steps > 0) notifyListeners();
  }

  void _simulateStep(double deltaTime) {
    _updateSnakes(deltaTime);
    _checkDangerousCollisions();
    _checkFoodCollisions();
    handleTickerCallback(deltaTime);
  }

  void _updateSnakes(double deltaTime) {
    for (final entry in snakes.entries) {
      final snake = entry.value;
      final previousHead = snake.head;

      final moveDistance = snake.currentSpeed * deltaTime;
      snake.head = Offset(
        snake.head.dx + cos(snake.angle) * moveDistance,
        snake.head.dy + sin(snake.angle) * moveDistance,
      );

      snake.updateTrail(previousHead, moveDistance);
    }
  }

  void _checkDangerousCollisions() {
    final snakesToRemove = <int>[];
    final bodyGrids = <int, SpatialGrid>{};
    for (final entry in snakes.entries) {
      final grid = SpatialGrid();
      for (final point in entry.value.body) {
        grid.insert(GridEntry(point, entry.value.style.bodySize));
      }
      bodyGrids[entry.key] = grid;
    }

    for (final entry in snakes.entries) {
      final id = entry.key;
      final snake = entry.value;

      if (_checkWallCollision(snake)) {
        if (id == identity) {
          _handleGameOver(snake.length);
          return;
        } else {
          snakesToRemove.add(id);
          continue;
        }
      }

      final collided = bodyGrids.entries.any(
        (gridEntry) =>
            gridEntry.key != id &&
            gridEntry.value.checkCollision(snake.head, snake.style.headSize) !=
                null,
      );
      if (collided) {
        if (id == identity) {
          _handleGameOver(snake.length);
          return;
        } else {
          snakesToRemove.add(id);
        }
      }
    }

    for (final id in snakesToRemove) {
      final removedSnake = snakes[id];
      snakes.remove(id);
      if (removedSnake != null) {
        for (int i = 0; i < removedSnake.body.length; i += 12) {
          addFood(removedSnake.body[i]);
        }
      }
      handleRemoveSnakeCallback(id);
    }
  }

  static bool _checkWallCollision(Snake snake) {
    final head = snake.head;
    final radius = snake.style.headSize;
    return head.dx - radius < 0 ||
        head.dx + radius > mapWidth ||
        head.dy - radius < 0 ||
        head.dy + radius > mapHeight;
  }

  void _checkFoodCollisions() {
    for (final snake in snakes.values) {
      Offset? position = foodGrid.checkCollision(
        snake.head,
        snake.style.headSize,
      );
      if (position != null) {
        foodGrid.remove(position);
        snake.updateLength(SpatialGrid.cellSize ~/ 2);
      }
    }
  }

  void handleRemoveSnakeCallback(int index);

  void handleTickerCallback(double deltaTime);

  void updatePlayerAngle(double newAngle);
  void updatePlayerSpeed(bool isFaster);

  void _handleGameOver(int length) {
    suspendGame();
    handleGameOverCallback();
    if (!showGameOverDialog) {
      leavePage();
      return;
    }
    pageNavigator.value = (context) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.gameOver),
          content: Text('${S.finalLength}: $length'),
          actions: [
            TextButton(
              child: Text(S.ok),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ).then((_) => leavePage());
    };
  }

  void handleGameOverCallback();
  bool get showGameOverDialog => true;

  void leavePage() {
    _navigateBack();
  }

  void _navigateBack() {
    pageNavigator.value = (context) {
      Navigator.pop(context);
    };
  }

  @override
  void dispose() {
    _ticker.dispose();
    gameState.dispose();
    pageNavigator.dispose();
    super.dispose();
  }
}
