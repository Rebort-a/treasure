import 'dart:math';
import 'base.dart';
import 'foundation_manager.dart';

class LocalManager extends FoundationalManager {
  static const int generateCount = 5;
  double _foodCheckAccumulator = 0.0;

  @override
  int get identity => 0;

  LocalManager() {
    initTicker();
    _initGame();
  }

  void _initGame() {
    addSnake(identity, FoundationalManager.initialLength);

    for (int i = 1; i <= generateCount; i++) {
      addSnake(identity + i, snakes[identity]!.length);
      addFood(randomSafePosition);
    }
  }

  @override
  void handleTickerCallback(double deltaTime) {
    _handleFoodSearch(deltaTime);
  }

  void _handleFoodSearch(double deltaTime) {
    _foodCheckAccumulator += deltaTime;
    if (_foodCheckAccumulator >= 0.4) {
      _adjustAllComputersAngle();
      _foodCheckAccumulator = 0;
    }
  }

  void _adjustAllComputersAngle() {
    for (final entry in snakes.entries) {
      if (entry.key != identity) {
        _turnToHappiness(entry.value);
      }
    }
  }

  void _turnToHappiness(Snake snake) {
    if (!isInSafeRange(snake.head)) {
      final dx = mapWidth / 2 - snake.head.dx;
      final dy = mapHeight / 2 - snake.head.dy;
      snake.updateAngle(atan2(dy, dx));
    } else {
      final nearest = getNearbyFoodPosition(
        snake.head,
        FoundationalManager.initialLength * 4,
      );
      if (nearest != null) {
        final dx = nearest.dx - snake.head.dx;
        final dy = nearest.dy - snake.head.dy;
        snake.updateAngle(atan2(dy, dx));
      }
    }
  }

  @override
  void handleRemoveSnakeCallback(int id) {
    if (id != identity) {
      addSnake(id, snakes[identity]!.length ~/ 2);
    }
  }

  @override
  void handleGameOverCallback() {}

  @override
  void updatePlayerAngle(double newAngle) {
    snakes[identity]!.updateAngle(newAngle);
  }

  @override
  void updatePlayerSpeed(bool isFaster) {
    snakes[identity]!.updateSpeed(isFaster);
  }
}
