import 'package:flutter/material.dart';

import '00.common/l10n/app_localizations.dart';
import '00.common/l10n/l10n.dart';
import '00.common/style/theme.dart';
import '00.common/tool/app_info.dart';
import '00.common/service/storage_service.dart';
import '00.common/sound/audio_preferences.dart';

import '01.home/upper/home_page.dart';
import '01.home/middle/background_settings.dart';

void main() async {
  // 初始化 Flutter 引擎与插件绑定。
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地 JSON 存储服务。
  await StorageService.instance.init();
  // 加载应用版本等基础信息。
  await AppInfo.load();
  // 加载语言、主题、背景和全局音频偏好。
  await _loadConfiguration();

  runApp(const MyApp()); // 启动应用并显示根组件。
}

Future<void> _loadConfiguration() async {
  await LanguageProvider.instance.load();
  await ThemeProvider.instance.load();
  await BackgroundSettings.instance.load();
  await AudioPreferences.instance.ready;
}

class MyApp extends StatelessWidget {
  final Widget home;

  const MyApp({super.key, this.home = const HomePage()});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: LanguageProvider.instance.locale,
      builder: (_, __, ___) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeProvider.instance.themeMode,
        builder: (_, themeMode, ___) => MaterialApp(
          theme: globalTheme,
          darkTheme: globalDarkTheme,
          themeMode: themeMode,
          locale: LanguageProvider.instance.flutterLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home,
        ),
      ),
    );
  }
}
