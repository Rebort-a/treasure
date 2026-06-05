import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '00.common/style/theme.dart';
import '00.common/tool/storage_service.dart';
import '01.home/home_page.dart';
import 'l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储服务
  await StorageService.instance.init();
  // 加载持久化的语言设置
  await LanguageProvider.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: LanguageProvider.instance.locale,
      builder: (_, __, ___) => MaterialApp(
        theme: globalTheme,
        locale: LanguageProvider.instance.flutterLocale,
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomePage(),
      ),
    );
  }
}
