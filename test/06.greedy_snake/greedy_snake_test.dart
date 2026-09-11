import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/06.greedy_snake/base.dart';

void main() {
  const style = SnakeStyle(
    headSize: 10,
    headColor: Colors.green,
    eyeColor: Colors.white,
    bodySize: 6,
    bodyColor: Colors.lightGreen,
  );

  group('Snake', () {
    test('速度、长度和视口偏移更新正确', () {
      final snake = Snake(
        head: const Offset(100, 80),
        length: 50,
        angle: 0,
        style: style,
      );

      expect(
        snake.calculateViewOffset(const Size(40, 20)),
        const Offset(80, 70),
      );
      snake.updateSpeed(true);
      snake.updateLength(10);
      snake.updateAngle(1.5);

      expect(snake.currentSpeed, Snake.fastSpeed);
      expect(snake.length, 60);
      expect(snake.angle, 1.5);
    });

    test('JSON 往返保留样式和加速状态', () {
      final original = Snake(
        head: const Offset(12.5, 30),
        length: 88,
        angle: 0.75,
        style: style,
      )..updateSpeed(true);

      final restored = Snake.fromJson(original.toJson());

      expect(restored.head, original.head);
      expect(restored.length, 88);
      expect(restored.angle, 0.75);
      expect(restored.currentSpeed, Snake.fastSpeed);
      expect(restored.style.bodySize, style.bodySize);
      expect(restored.style.bodyColor.toARGB32(), style.bodyColor.toARGB32());
    });
  });

  group('SpatialGrid', () {
    test('跨网格边界也能检测碰撞，移除后不再命中', () {
      final grid = SpatialGrid();
      const food = Offset(19, 20);
      grid.insert(GridEntry(food, 3));

      expect(grid.checkCollision(const Offset(22, 20), 2), food);
      grid.remove(food);
      expect(grid.checkCollision(const Offset(22, 20), 2), isNull);
    });

    test('JSON 往返保留所有条目', () {
      final grid = SpatialGrid()
        ..insert(GridEntry(const Offset(10, 20), 4))
        ..insert(GridEntry(const Offset(-5, 7), 2));
      final restored = SpatialGrid()..fromJson(grid.toJson());

      expect(restored.getGridEntries(), hasLength(2));
      expect(
        restored.checkCollision(const Offset(-5, 7), 0.1),
        const Offset(-5, 7),
      );
    });
  });
}
