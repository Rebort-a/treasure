import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// spritesheet 切割工具（供 CustomPainter 用 canvas.drawImageRect 绘制）
///
/// 与 [image_manager.dart] 的 Widget 版 ImageSplitter 互补：
/// 这里直接产出 [ui.Image] 与源矩形，适合游戏循环里逐帧绘制。
class SpriteSheet {
  final ui.Image image;
  final int columns;
  final int rows;

  const SpriteSheet(this.image, this.columns, this.rows);

  double get cellWidth => image.width / columns;
  double get cellHeight => image.height / rows;

  /// 线性索引（row-major）对应的源矩形
  Rect frameRect(int index) {
    final row = index ~/ columns;
    final col = index % columns;
    return Rect.fromLTWH(
      col * cellWidth,
      row * cellHeight,
      cellWidth,
      cellHeight,
    );
  }

  /// 从 assets 加载并按行列切割
  static Future<SpriteSheet> load(String asset, int columns, int rows) async {
    final data = await rootBundle.load(asset);
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final codec = await ui.instantiateImageCodecFromBuffer(buffer);
    final frame = await codec.getNextFrame();
    return SpriteSheet(frame.image, columns, rows);
  }
}
