import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../00.common/tool/notifiers.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';

abstract class FoundationalManager extends ChangeNotifier
    implements TickerProvider {
  static const int initialLength = 100;
  final Random _random = Random();

  final Map<int, Snake> snakes = {};
  final SpatialGrid foodGrid = SpatialGrid();

  late final Ticker _ticker;
  double _lastElapsed = 0;

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
    _ticker.start();
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

    final currentTime = elapsed.inMilliseconds;

    final currentElapsed = currentTime / 1000.0;
    final deltaTime = currentElapsed - _lastElapsed;
    _lastElapsed = currentElapsed;

    final clampedDeltaTime = deltaTime.clamp(0.004, 0.02);

    _updateSnakes(clampedDeltaTime);
    _checkDangerousCollisions();
    _checkFoodCollisions();
    handleTickerCallback(deltaTime);
    notifyListeners();
  }

  void _updateSnakes(double deltaTime) {
    for (final entry in snakes.entries) {
      final snake = entry.value;
      snake.body.insert(0, snake.head);

      final moveDistance = snake.currentSpeed * deltaTime;
      snake.head = Offset(
        snake.head.dx + cos(snake.angle) * moveDistance,
        snake.head.dy + sin(snake.angle) * moveDistance,
      );

      snake.currentLength += moveDistance;

      while (snake.body.length > 2 && snake.currentLength > snake.length) {
        final last = snake.body.removeLast();
        final secondLast = snake.body.last;
        final segmentLength = (last - secondLast).distance;
        if (segmentLength > 0) {
          snake.currentLength -= segmentLength;
        } else {
          break;
        }
      }
    }
  }

  void _checkDangerousCollisions() {
    final snakesToRemove = <int>[];
    for (final entry in snakes.entries) {
      final id = entry.key;
      final snake = entry.value;

      if (_checkWallCollision(snake.head)) {
        if (id == identity) {
          _handleGameOver(snake.length);
          return;
        } else {
          snakesToRemove.add(id);
          continue;
        }
      }

      SpatialGrid snakeGrid = SpatialGrid();
      for (final otherEntry in snakes.entries) {
        if (otherEntry.key != id) {
          final otherSnake = otherEntry.value;
          for (final point in otherSnake.body) {
            snakeGrid.insert(GridEntry(point, otherSnake.style.bodySize));
          }
        }
      }

      if (snakeGrid.checkCollision(snake.head, snake.style.headSize) != null) {
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

  static bool _checkWallCollision(Offset head) {
    return head.dx < 0 ||
        head.dx > mapWidth ||
        head.dy < 0 ||
        head.dy > mapHeight;
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
    super.dispose();
  }
}
