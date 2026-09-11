import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/01.home/home_manager.dart';
import 'package:treasure/01.home/home_page.dart';
import 'package:treasure/01.home/route.dart';
import 'package:treasure/03.animal_chess/local_page.dart';
import 'package:treasure/15.memory_card/page.dart';
import 'package:treasure/main.dart';

void main() {
  setUp(() {
    LanguageProvider.instance.resetForTesting();
    ThemeProvider.instance.resetForTesting();
  });

  testWidgets('首页启动并可通过本地应用列表进入游戏页面', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.pump();

    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Animal Chess'), findsOneWidget);

    manager.routeLocal(LocalItemType.animalChess);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // push 路由后首页仍保留在 Navigator 的 offstage 路由栈中。
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LocalAnimalChessPage), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('Animal Chess 页面可独立构建且无异常', (tester) async {
    await tester.pumpWidget(MyApp(home: LocalAnimalChessPage()));
    await tester.pump();

    expect(find.text('Animal Chess'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Memory Match 页面可构建且显示棋盘', (tester) async {
    await tester.pumpWidget(MyApp(home: MemoryPage()));
    await tester.pump();

    expect(find.text('Memory Match'), findsOneWidget);
    expect(find.byType(CardView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
