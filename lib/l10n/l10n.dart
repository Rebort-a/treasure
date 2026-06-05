import 'package:flutter/material.dart';

/// 支持的语言
enum AppLocale { zh, en }

/// 语言切换状态管理
class LanguageProvider {
  static final LanguageProvider instance = LanguageProvider._();
  LanguageProvider._();

  final ValueNotifier<AppLocale> locale = ValueNotifier(AppLocale.en);

  void toggle() {
    locale.value =
        locale.value == AppLocale.zh ? AppLocale.en : AppLocale.zh;
  }

  void setLocale(AppLocale l) => locale.value = l;

  Locale get flutterLocale =>
      locale.value == AppLocale.zh
          ? const Locale('zh')
          : const Locale('en');
}
