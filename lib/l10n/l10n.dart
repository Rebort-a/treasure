import 'package:flutter/material.dart';

import '../00.common/tool/storage_service.dart';

/// 支持的语言
enum AppLocale { zh, en }

/// 语言切换状态管理（持久化）
class LanguageProvider {
  static final LanguageProvider instance = LanguageProvider._();
  LanguageProvider._();

  final ValueNotifier<AppLocale> locale = ValueNotifier(AppLocale.en);

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

  void toggle() {
    locale.value =
        locale.value == AppLocale.zh ? AppLocale.en : AppLocale.zh;
    _save();
  }

  void setLocale(AppLocale l) {
    locale.value = l;
    _save();
  }

  void _save() {
    StorageService.instance.write('settings', {'language': locale.value.index});
  }

  Locale get flutterLocale =>
      locale.value == AppLocale.zh
          ? const Locale('zh')
          : const Locale('en');
}
