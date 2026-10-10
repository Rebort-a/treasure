import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../00.common/service/storage_service.dart';

/// 仅供首页使用的背景设置，保存图片内容，避免原文件移动后背景丢失。
class BackgroundSettings {
  BackgroundSettings._();
  static final instance = BackgroundSettings._();

  static const maxImageBytes = 10 * 1024 * 1024;
  final ValueNotifier<Uint8List?> image = ValueNotifier(null);

  Future<void> load() async {
    final data = await StorageService.instance.read(
      'background',
      project: '01.home',
    );
    try {
      final encoded = data['image'];
      if (encoded is! String) {
        image.value = null;
        return;
      }
      if (encoded.length > (maxImageBytes * 4 / 3).ceil() + 4) {
        throw const FormatException('Image too large');
      }
      final bytes = base64Decode(encoded);
      await _validate(bytes);
      image.value = bytes;
    } catch (error) {
      image.value = null;
      debugPrint('[Background] Invalid saved image: $error');
    }
  }

  Future<void> setImage(Uint8List? bytes) async {
    if (bytes != null) await _validate(bytes);
    await StorageService.instance.write('background', {
      if (bytes != null) 'image': base64Encode(bytes),
    }, project: '01.home');
    image.value = bytes;
  }

  /// 在替换前实际解码，取消选择或无效图片不会破坏原有背景。
  Future<void> _validate(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const FormatException('Invalid image size');
    }
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1920,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  @visibleForTesting
  void resetForTesting() => image.value = null;
}
