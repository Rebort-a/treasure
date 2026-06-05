import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/tool/convert_utils.dart';

const double mapWidth = 2000;
const double mapHeight = 2000;

class SnakeStyle {
  final double headSize;
  final Color headColor;
  final Color eyeColor;
  final double bodySize;
  final Color bodyColor;

  const SnakeStyle({
    required this.headSize,
    required this.headColor,
    required this.eyeColor,
    required this.bodySize,
    required this.bodyColor,
  });

  static SnakeStyle random() {
    final random = Random();
    // 1. 扩展基础色相
    final baseHues = [
      120, // 绿色
      240, // 蓝色
      0, // 红色
      300, // 紫色
      60, // 黄色
      30, // 橙色
      330, // 粉色
      180, // 青色
      30, // 棕色（橙色偏暗）
      210, // 靛蓝色
      0, // 深红色（红色偏暗）
    ];

    final eyeColors = [Colors.white, Colors.yellow, Colors.pinkAccent];

    // 随机选择一个基础色相
    final hue = baseHues[random.nextInt(baseHues.length)];

    // 2. 随机调整饱和度（0.5-1.0，确保颜色鲜艳但不过度）
    final saturation = 0.5 + random.nextDouble() * 0.5;

    // 3. 随机调整亮度（头部稍暗，身体稍亮，形成对比）
    final headLightness = 0.3 + random.nextDouble() * 0.2; // 0.3-0.5（偏暗）
    final bodyLightness = 0.6 + random.nextDouble() * 0.2; // 0.6-0.8（偏亮）

    // 4. 从HSL转换为RGB颜色
    final headHsl = HSLColor.fromAHSL(
      1.0,
      hue.toDouble(),
      saturation,
      headLightness,
    );
    final bodyHsl = HSLColor.fromAHSL(
      1.0,
      hue.toDouble(),
      saturation,
      bodyLightness,
    );

    return SnakeStyle(
      headSize: 8 + random.nextDouble() * 8.0,
      headColor: headHsl.toColor(),
      eyeColor: eyeColors[random.nextInt(eyeColors.length)],
      bodySize: 4 + random.nextDouble() * 4.0,
      bodyColor: bodyHsl.toColor(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'headSize': headSize,
      'headColor': ConvertUtils.colorToJson(headColor),
      'eyeColor': ConvertUtils.colorToJson(eyeColor),
      'bodySize': bodySize,
      'bodyColor': ConvertUtils.colorToJson(bodyColor),
    };
  }

  static SnakeStyle fromJson(Map<String, dynamic> json) {
    return SnakeStyle(
      headSize: json['headSize'],
      headColor: ConvertUtils.colorFromJson(json['headColor']),
      eyeColor: ConvertUtils.colorFromJson(json['eyeColor']),
      bodySize: json['bodySize'],
      bodyColor: ConvertUtils.colorFromJson(json['bodyColor']),
    );
  }
}

class Snake {
  static const double initialSpeed = 200;
  static const double fastSpeed = 400;

  List<Offset> body = [];
  double currentSpeed = initialSpeed;
  double currentLength = 0.0;

  Offset head;
  int length;
  double angle;
  SnakeStyle style;

  Snake({
    required this.head,
    required this.length,
    required this.angle,
    required this.style,
  });

  Offset calculateViewOffset(Size viewSize) {
    return Offset(head.dx - viewSize.width / 2, head.dy - viewSize.height / 2);
  }

  void updateAngle(double newAngle) => angle = newAngle;
  void updateSpeed(bool isFaster) =>
      currentSpeed = isFaster ? fastSpeed : initialSpeed;
  void updateLength(int step) => length += step;

  Map<String, dynamic> toJson() {
    return {
      'head': ConvertUtils.offsetToJson(head),
      'length': length,
      'angle': angle,
      'style': style.toJson(),
      'isFaster': currentSpeed == fastSpeed,
    };
  }

  static Snake fromJson(Map<String, dynamic> json) {
    return Snake(
      head: ConvertUtils.offsetFromJson(json['head']),
      length: json['length'],
      angle: json['angle'],
      style: SnakeStyle.fromJson(json['style']),
    )..currentSpeed = json['isFaster'] as bool ? fastSpeed : initialSpeed;
  }
}

class GridEntry {
  final Offset position;
  final double radius;

  GridEntry(this.position, this.radius);
}

class SpatialGrid {
  static const double cellSize = 20;

  final Map<Point<int>, List<GridEntry>> grid = {};

  void clear() => grid.clear();

  List<GridEntry> getGridEntries() {
    return grid.values.expand((entries) => entries).toList();
  }

  void insert(GridEntry entry) {
    final cell = Point(
      (entry.position.dx / cellSize).floor(),
      (entry.position.dy / cellSize).floor(),
    );
    grid.putIfAbsent(cell, () => []).add(entry);
  }

  void remove(Offset position) {
    final cell = Point(
      (position.dx / cellSize).floor(),
      (position.dy / cellSize).floor(),
    );

    final entries = grid[cell];
    if (entries == null) return;

    // 查找并移除匹配的条目（位置和大小都相同）
    entries.removeWhere((entry) => entry.position == position);
  }

  Offset? checkCollision(Offset position, double radius) {
    final centerCell = Point(
      (position.dx / cellSize).floor(),
      (position.dy / cellSize).floor(),
    );

    int around = radius ~/ cellSize + 1;

    for (int x = -around; x <= around; x++) {
      for (int y = -around; y <= around; y++) {
        final cell = Point(centerCell.x + x, centerCell.y + y);
        final entries = grid[cell];
        if (entries != null) {
          for (final entry in entries) {
            final threshold = radius + entry.radius;
            if ((position - entry.position).distance < threshold) {
              return entry.position;
            }
          }
        }
      }
    }
    return null;
  }

  // 使用ConvertUtils的JSON序列化方法
  Map<String, dynamic> toJson() {
    return {
      'entries': getGridEntries()
          .map(
            (entry) => {
              'position': ConvertUtils.offsetToJson(entry.position),
              'radius': entry.radius,
            },
          )
          .toList(),
    };
  }

  // 使用ConvertUtils的JSON反序列化方法
  void fromJson(Map<String, dynamic> json) {
    for (var entryData in (json['entries'] as List)) {
      final position = ConvertUtils.offsetFromJson(entryData['position']);
      final radius = entryData['radius'] as double;
      insert(GridEntry(position, radius));
    }
  }
}
