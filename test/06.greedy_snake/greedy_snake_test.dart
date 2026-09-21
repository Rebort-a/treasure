import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/06.greedy_snake/base.dart';
import 'package:treasure/06.greedy_snake/local_page.dart';

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

      expect(original.toJson(), isNot(contains('body')));
      expect(original.toJson(), isNot(contains('currentLength')));
      expect(restored.head, original.head);
      expect(restored.length, 88);
      expect(restored.angle, 0.75);
      expect(restored.currentSpeed, Snake.fastSpeed);
      expect(restored.body, isEmpty);
      expect(restored.currentLength, 0);
      expect(restored.style.bodySize, style.bodySize);
      expect(restored.style.bodyColor.toARGB32(), style.bodyColor.toARGB32());
    });

    test('普通和加速状态下尾端都连续移动', () {
      for (final speed in [Snake.initialSpeed, Snake.fastSpeed]) {
        final snake = Snake(
          head: Offset.zero,
          length: 40,
          angle: 0,
          style: style,
        )..currentSpeed = speed;
        const deltaTime = 1 / 120;
        final moveDistance = speed * deltaTime;
        double? previousTailX;

        for (var i = 0; i < 120; i++) {
          final previousHead = snake.head;
          snake.head += Offset(moveDistance, 0);
          snake.updateTrail(previousHead, moveDistance);

          if (snake.currentLength == snake.length && snake.body.length > 2) {
            final tailX = snake.body.last.dx;
            if (previousTailX != null) {
              expect(
                tailX - previousTailX,
                closeTo(moveDistance, 1e-7),
                reason: 'speed=$speed 时尾端不应整段跳动',
              );
            }
            previousTailX = tailX;
          }
        }

        expect(snake.currentLength, snake.length);
        expect(previousTailX, isNotNull);
      }
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

  testWidgets('Stateless 页面移除后释放 manager 资源', (tester) async {
    final page = LocalGreedySnakePage();
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(() => page.manager.gameState.addListener(() {}), throwsFlutterError);
  });
}
