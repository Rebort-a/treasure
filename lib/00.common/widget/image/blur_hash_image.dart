import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../tool/blur_hash.dart';

/// BlurHash 模糊占位 + 高斯模糊溶解加载动画
///
/// 显示 BlurHash 解码的低分辨率占位图（天然模糊），
/// 实际图片加载完成后以溶解动画过渡。
class BlurHashImage extends StatefulWidget {
  final String hash;
  final Uint8List imageBytes;
  final BoxFit fit;
  final int decodeWidth;
  final int decodeHeight;
  final VoidCallback? onLoad;

  const BlurHashImage({
    super.key,
    required this.hash,
    required this.imageBytes,
    this.fit = BoxFit.cover,
    this.decodeWidth = 32,
    this.decodeHeight = 32,
    this.onLoad,
  });

  @override
  State<BlurHashImage> createState() => _BlurHashImageState();
}

class _BlurHashImageState extends State<BlurHashImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ImageProvider? _placeholderProvider;
  late ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _imageProvider = Image.memory(widget.imageBytes).image;
    _decodePlaceholder();
    _listenImageLoad();
  }

  void _decodePlaceholder() {
    try {
      final pixels = BlurHash.decode(
        widget.hash,
        widget.decodeWidth,
        widget.decodeHeight,
      );
      _placeholderProvider = Image.memory(
        _encodeBmp(pixels, widget.decodeWidth, widget.decodeHeight),
      ).image;
    } catch (_) {
      // hash 无效时跳过占位图
    }
  }

  void _listenImageLoad() {
    final stream = _imageProvider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, __) {
        if (mounted) _controller.forward();
        widget.onLoad?.call();
        stream.removeListener(listener);
      },
      onError: (_, __) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：BlurHash 低分辨率占位（天然模糊）
        if (_placeholderProvider != null)
          Image(image: _placeholderProvider!, fit: widget.fit),
        // 顶层：实际图片，溶解淡入
        FadeTransition(
          opacity: _controller.drive(CurveTween(curve: Curves.easeOut)),
          child: Image(
            image: _imageProvider,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// 将 RGBA 像素编码为 BMP 字节（用于 Image.memory 显示）
  static Uint8List _encodeBmp(Uint8List rgba, int w, int h) {
    final rowBytes = w * 3;
    final padding = (4 - rowBytes % 4) % 4;
    final pixelSize = (rowBytes + padding) * h;
    final fileSize = 54 + pixelSize;
    final buf = Uint8List(fileSize);
    final bd = ByteData.view(buf.buffer);

    // BMP 文件头 (14 bytes)
    buf[0] = 0x42;
    buf[1] = 0x4D; // 'BM'
    bd.setUint32(2, fileSize, Endian.little);
    bd.setUint32(10, 54, Endian.little); // 像素数据偏移

    // DIB 头 (40 bytes)
    bd.setUint32(14, 40, Endian.little); // 头大小
    bd.setInt32(18, w, Endian.little);
    bd.setInt32(22, h, Endian.little);
    bd.setUint16(26, 1, Endian.little); // planes
    bd.setUint16(28, 24, Endian.little); // bits per pixel
    bd.setUint32(34, pixelSize, Endian.little);

    // 像素数据（BGR，从底部行开始）
    int offset = 54;
    for (int y = h - 1; y >= 0; y--) {
      for (int x = 0; x < w; x++) {
        final si = (y * w + x) * 4;
        buf[offset++] = rgba[si + 2]; // B
        buf[offset++] = rgba[si + 1]; // G
        buf[offset++] = rgba[si]; // R
      }
      offset += padding;
    }
    return buf;
  }
}
