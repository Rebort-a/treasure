import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// BlurHash — 纯 Dart 实现，零外部依赖
///
/// 将图片编码为紧凑的 base83 字符串，可解码为低分辨率模糊占位图。
/// 用于聊天图片加载时的渐进式展示。
class BlurHash {
  BlurHash._();

  // ==================== base83 编解码 ====================

  static const _chars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#\$%*+,-.:;=?@[]^_{|}~';

  static String _encodeBase83(int value, int length) {
    final result = StringBuffer();
    for (int i = 1; i <= length; i++) {
      result.write(_chars[(value ~/ pow(83, length - i)) % 83]);
    }
    return result.toString();
  }

  static int _decodeBase83(String str) {
    int value = 0;
    for (int i = 0; i < str.length; i++) {
      value = value * 83 + _chars.indexOf(str[i]);
    }
    return value;
  }

  // ==================== 颜色空间转换 ====================

  static double _srgbToLinear(int value) {
    final v = value / 255.0;
    if (v <= 0.04045) return v / 12.92;
    return pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _linearToSrgb(double value) {
    final v = value.clamp(0.0, 1.0);
    final c = v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1.0 / 2.4) - 0.055;
    return (c * 255.0 + 0.5).floor();
  }

  static int _signPow(double value, double exp) {
    return (pow(value.abs(), exp) * value.sign + 0.5).floor();
  }

  // ==================== 编码 ====================

  /// 从 RGBA 像素数据计算 BlurHash
  ///
  /// [pixels] — RGBA 格式的 Uint8List（每 4 字节一个像素）
  /// [width], [height] — 图像尺寸
  /// [componentX], [componentY] — DCT 分量数（4x3 为标准，9~12 字符）
  static String encode(
    Uint8List pixels,
    int width,
    int height, {
    int componentX = 4,
    int componentY = 3,
  }) {
    // 采样：缩小到最多 64 像素宽，加速计算
    final int sampleW = max(1, width ~/ max(1, (width / 64).round()));
    final int sampleH = max(1, height ~/ max(1, (height / 64).round()));

    // 计算每个分量的 DCT 系数
    final factors = <List<double>>[];
    for (int cy = 0; cy < componentY; cy++) {
      for (int cx = 0; cx < componentX; cx++) {
        double r = 0, g = 0, b = 0;
        double normFactor = (cx == 0 && cy == 0) ? 1.0 : 2.0;

        for (int y = 0; y < sampleH; y++) {
          for (int x = 0; x < sampleW; x++) {
            final px = (x * width / sampleW).floor();
            final py = (y * height / sampleH).floor();
            final idx = (py * width + px) * 4;

            final basis = normFactor *
                cos(pi * cx * x / sampleW) *
                cos(pi * cy * y / sampleH);

            r += basis * _srgbToLinear(pixels[idx]);
            g += basis * _srgbToLinear(pixels[idx + 1]);
            b += basis * _srgbToLinear(pixels[idx + 2]);
          }
        }

        final scale = 1.0 / (sampleW * sampleH);
        factors.add([r * scale, g * scale, b * scale]);
      }
    }

    // 编码
    final buf = StringBuffer();
    final sizeFlag = componentX - 1 + (componentY - 1) * 9;
    buf.write(_encodeBase83(sizeFlag, 1));

    // 量化最大值
    final maxVal = _findMaxVal(factors);
    final quantMaxVal = max(0, min(82, (maxVal > 0 ? (63.0 * maxVal / 1.0).floor() : 0)));
    buf.write(_encodeBase83(quantMaxVal, 1));

    final realMaxVal = quantMaxVal > 0 ? quantMaxVal / 16.0 + 1.0 / 16.0 : 1.0 / 16.0;

    for (final factor in factors) {
      buf.write(_encodeBase83(
        _signPow(factor[0] / realMaxVal, 0.5) * 19 * 19 +
            _signPow(factor[1] / realMaxVal, 0.5) * 19 +
            _signPow(factor[2] / realMaxVal, 0.5),
        2,
      ));
    }

    return buf.toString();
  }

  static double _findMaxVal(List<List<double>> factors) {
    double maxVal = 0;
    for (final f in factors) {
      maxVal = max(maxVal, f[0].abs());
      maxVal = max(maxVal, f[1].abs());
      maxVal = max(maxVal, f[2].abs());
    }
    return maxVal;
  }

  // ==================== 解码 ====================

  /// 从 BlurHash 解码为 RGBA 像素数据
  ///
  /// 返回 [width] x [height] 的 RGBA 像素（默认 32x32）
  static Uint8List decode(String hash, int width, int height, {double punch = 1.0}) {
    if (hash.length < 6) throw const FormatException('Invalid BlurHash');

    final sizeFlag = _decodeBase83(hash.substring(0, 1));
    final sizeX = (sizeFlag % 9) + 1;
    final sizeY = (sizeFlag ~/ 9) + 1;

    final quantMaxVal = _decodeBase83(hash.substring(1, 2));
    final realMaxVal = (quantMaxVal + 1) / 16.0 * punch;

    if (hash.length != 4 + 2 * sizeX * sizeY) {
      throw const FormatException('Invalid BlurHash length');
    }

    // 解析 DCT 系数
    final colors = <List<double>>[];
    for (int i = 0; i < sizeX * sizeY; i++) {
      final val = _decodeBase83(hash.substring(4 + i * 2, 4 + i * 2 + 2));
      colors.add([
        realMaxVal * _signSrgb((val / (19 * 19)).floor() - 9) / 16.0,
        realMaxVal * _signSrgb(((val ~/ 19) % 19) - 9) / 16.0,
        realMaxVal * _signSrgb((val % 19) - 9) / 16.0,
      ]);
    }

    // 逆 DCT 渲染
    final pixels = Uint8List(width * height * 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double r = 0, g = 0, b = 0;
        for (int cy = 0; cy < sizeY; cy++) {
          for (int cx = 0; cx < sizeX; cx++) {
            final basis = cos(pi * cx * x / width) * cos(pi * cy * y / height);
            final idx = cy * sizeX + cx;
            r += colors[idx][0] * basis;
            g += colors[idx][1] * basis;
            b += colors[idx][2] * basis;
          }
        }
        final idx = (y * width + x) * 4;
        pixels[idx] = _linearToSrgb(r);
        pixels[idx + 1] = _linearToSrgb(g);
        pixels[idx + 2] = _linearToSrgb(b);
        pixels[idx + 3] = 255;
      }
    }
    return pixels;
  }

  static double _signSrgb(int value) {
    final v = value / 16.0;
    return v * v * v * 16.0;
  }

  // ==================== 辅助：从图片字节提取像素 ====================

  /// 用 Flutter 内置 codec 从图片字节提取 RGBA 像素
  ///
  /// 返回 (pixels, width, height)。[maxSize] — 缩放到此尺寸以内（保持比例）。
  static Future<(Uint8List, int, int)> pixelsFromBytes(
    Uint8List bytes, {
    int maxSize = 64,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // 缩放以加速计算
    final int w, h;
    if (image.width > maxSize || image.height > maxSize) {
      final ratio = image.width / image.height;
      if (ratio > 1) {
        w = maxSize;
        h = (maxSize / ratio).round();
      } else {
        h = maxSize;
        w = (maxSize * ratio).round();
      }
    } else {
      w = image.width;
      h = image.height;
    }

    // 用 PictureRecorder 绘制缩放后的图像
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.low,
    );
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(w, h);
    final byteData = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);

    image.dispose();
    scaled.dispose();

    return (byteData!.buffer.asUint8List(), w, h);
  }
}
