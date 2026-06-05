import 'package:flutter/material.dart';

import 'achieve_banner.dart';
import 'alert_banner.dart';
import 'text_banner.dart';

class BannerTemplate {
  BannerTemplate._();

  static void snackBarDialog(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static void _showOverlayDialog({
    required BuildContext context,
    required WidgetBuilder builder,
    required Duration duration,
  }) {
    // 创建OverlayEntry
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: builder);

    // 添加到Overlay
    overlay.insert(entry);

    // 时间到后移除弹窗
    Future.delayed(duration, () => entry.remove());
  }

  /// 文本Banner
  static void textBanner({
    required BuildContext context,
    required String text,
    required Duration duration,
  }) {
    _showOverlayDialog(
      context: context,
      duration: duration,
      builder: (context) => TextBanner(text: text, duration: duration),
    );
  }

  /// 成就Banner
  static void achieveBanner({
    required BuildContext context,
    required String title,
    required String description,
    required Duration duration,
  }) {
    _showOverlayDialog(
      context: context,
      duration: duration,
      builder: (context) =>
          AchieveBanner(title: title, description: description),
    );
  }

  /// 警告Banner
  static void alertBanner({
    required BuildContext context,
    required String text,
    required Duration duration,
  }) {
    _showOverlayDialog(
      context: context,
      duration: duration,
      builder: (context) => AlertBanner(text: text, duration: duration),
    );
  }
}
