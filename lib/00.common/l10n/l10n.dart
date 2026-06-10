import 'package:flutter/material.dart';

import '../tool/storage_service.dart';

/// 支持的语言
enum AppLocale { zh, en }

/// 语言切换状态管理（持久化）
class LanguageProvider {
  static final LanguageProvider instance = LanguageProvider._();
  LanguageProvider._();

  final ValueNotifier<AppLocale> locale = ValueNotifier(AppLocale.en);

  /// 重置状态，仅用于测试
  @visibleForTesting
  void resetForTesting() {
    locale.value = AppLocale.en;
  }

  /// 从本地加载语言设置
  Future<void> load() async {
    final data = await StorageService.instance.read('settings');
    if (data['language'] != null) {
      final index = data['language'] as int;
      if (index >= 0 && index < AppLocale.values.length) {
        locale.value = AppLocale.values[index];
      }
    }
  }

  Future<void> _save() async {
    final data = await StorageService.instance.read('settings');
    data['language'] = locale.value.index;
    StorageService.instance.write('settings', data);
  }

  Future<void> toggle() async {
    locale.value = locale.value == AppLocale.zh ? AppLocale.en : AppLocale.zh;
    await _save();
  }

  Future<void> setLocale(AppLocale l) async {
    locale.value = l;
    await _save();
  }

  Locale get flutterLocale =>
      locale.value == AppLocale.zh ? const Locale('zh') : const Locale('en');
}
