import 'package:flutter/material.dart';
import '00.common/l10n/app_localizations.dart';

import '00.common/style/theme.dart';
import '00.common/tool/storage_service.dart';
import '00.common/tool/app_info.dart';
import '01.home/home_page.dart';
import '00.common/l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储服务
  await StorageService.instance.init();
  // 加载应用版本信息
  await AppInfo.load();
  // 加载持久化的语言和主题设置
  await LanguageProvider.instance.load();
  await ThemeProvider.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          home: const HomePage(),
        ),
      ),
    );
  }
}
