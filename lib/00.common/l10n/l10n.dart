import 'package:flutter/material.dart';
import 'app_localizations.dart';

import '../tool/storage_service.dart';

/// 支持的语言
enum AppLocale { zh, en }

/// 语言切换状态管理（持久化）。
///
/// 同时缓存由 gen-l10n 生成的 [AppLocalizations] 实例，供无 context 的 [S]
/// 门面访问。切换语言时同步更新缓存（先于 [locale] 触发重建，保证门面
/// 读到新实例）；未调用 [load] 前（如单元测试）按当前 [locale] 同步回退。
class LanguageProvider {
  static final LanguageProvider instance = LanguageProvider._();
  LanguageProvider._();

  final ValueNotifier<AppLocale> locale = ValueNotifier(AppLocale.en);

  /// 缓存的 [AppLocalizations]，随语言切换同步更新；未加载前为 null，
  /// 由 [current] 按 [locale] 同步回退。
  final ValueNotifier<AppLocalizations?> localization = ValueNotifier(null);

  /// 始终非空：优先返回缓存的 [localization]，否则按当前 [locale] 同步回退。
  AppLocalizations get current =>
      localization.value ?? lookupAppLocalizations(flutterLocale);

  Locale _localeOf(AppLocale l) =>
      l == AppLocale.zh ? const Locale('zh') : const Locale('en');
  Locale get flutterLocale => _localeOf(locale.value);

  /// 重置状态，仅用于测试
  @visibleForTesting
  void resetForTesting() {
    locale.value = AppLocale.en;
    localization.value = null;
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
    localization.value = lookupAppLocalizations(flutterLocale);
  }

  Future<void> _save() async {
    final data = await StorageService.instance.read('settings');
    data['language'] = locale.value.index;
    await StorageService.instance.write('settings', data);
  }

  Future<void> toggle() async {
    final next = locale.value == AppLocale.zh ? AppLocale.en : AppLocale.zh;
    // 先同步更新缓存，再改 locale 触发重建，确保门面读到新实例。
    localization.value = lookupAppLocalizations(_localeOf(next));
    locale.value = next;
    await _save();
  }

  Future<void> setLocale(AppLocale l) async {
    localization.value = lookupAppLocalizations(_localeOf(l));
    locale.value = l;
    await _save();
  }
}
