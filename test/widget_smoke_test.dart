import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/01.home/middle/player_settings.dart';
import 'package:treasure/01.home/upper/home_manager.dart';
import 'package:treasure/01.home/upper/widgets/floating_navigation_bar.dart';
import 'package:treasure/01.home/upper/home_page.dart';
import 'package:treasure/01.home/upper/route.dart';
import 'package:treasure/03.animal_chess/local_page.dart';
import 'package:treasure/main.dart';

void main() {
  setUp(() {
    LanguageProvider.instance.resetForTesting();
    ThemeProvider.instance.resetForTesting();
    PlayerSettings.instance.resetForTesting();
  });

  testWidgets('首页启动并可通过本地应用列表进入游戏页面', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.pump();

    final animalName = S.roomTypeString(AppItemType.animalChess.name);
    final gobangName = S.roomTypeString(AppItemType.gobang.name);
    expect(find.text(animalName), findsOneWidget);
    expect(find.byType(FloatingNavigationBar), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, gobangName);
    await tester.pump();
    expect(find.text(gobangName), findsWidgets);
    expect(find.text(animalName), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();

    manager.routeLocal(AppItemType.animalChess);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // push 路由后首页仍保留在 Navigator 的 offstage 路由栈中。
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LocalAnimalChessPage), findsOneWidget);
  });

  testWidgets('创建房间先选择类型，再输入名称和可选密码', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.tap(find.byKey(const ValueKey('navigation-destination-1')));
    await tester.pump();
    await tester.tap(find.text(S.createRoom));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final typeName = S.roomTypeString(OnlineItemType.gobang.name);
    await tester.ensureVisible(find.text(typeName));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(typeName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(manager.createdRooms.value, isEmpty);
  });

  testWidgets('应用卡片可跳过类型选择快速创建联机房间', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.pump();

    final appCard = find.ancestor(
      of: find.text(S.roomTypeString(AppItemType.gobang.name)),
      matching: find.byType(ListTile),
    );
    final quickCreateButton = find.descendant(
      of: appCard,
      matching: find.byTooltip(S.quickCreateRoom),
    );
    await tester.ensureVisible(quickCreateButton);
    await tester.tap(quickCreateButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('设置页修改默认玩家名称后生效', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.tap(find.byKey(const ValueKey('navigation-destination-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.defaultPlayerName));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Alice');
    await tester.tap(find.text(S.confirm));
    await tester.pumpAndSettle();
    expect(PlayerSettings.instance.defaultName.value, 'Alice');
    expect(tester.takeException(), isNull);
  });
}
