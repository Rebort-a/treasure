import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/01.home/player_settings.dart';
import 'package:treasure/00.common/network/server/socket_server.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/01.home/home_manager.dart';
import 'package:treasure/01.home/floating_navigation_bar.dart';
import 'package:treasure/01.home/home_page.dart';
import 'package:treasure/01.home/route.dart';
import 'package:treasure/03.animal_chess/local_page.dart';
import 'package:treasure/15.memory_card/page.dart';
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

    expect(find.text('Apps'), findsWidgets);
    expect(find.text('Animal Chess'), findsOneWidget);
    expect(find.byType(FloatingNavigationBar), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Gomoku');
    await tester.pump();
    expect(find.text('Gomoku'), findsWidgets);
    expect(find.text('Animal Chess'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();

    manager.routeLocal(AppItemType.animalChess);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // push 路由后首页仍保留在 Navigator 的 offstage 路由栈中。
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LocalAnimalChessPage), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('本地应用搜索、数量和导航图标', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.pump();

    expect(find.byIcon(Icons.widgets), findsOneWidget);
    expect(find.byIcon(Icons.lan_outlined), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering), findsWidgets);
    expect(
      find.text('All apps (${AppItemType.values.length})'),
      findsOneWidget,
    );
    final search = find.byType(TextField).first;
    expect(
      tester.widget<TextField>(search).decoration!.border,
      InputBorder.none,
    );
    await tester.tap(search);
    await tester.pump();
    expect(
      tester.widget<TextField>(search).decoration!.focusedBorder,
      isA<OutlineInputBorder>(),
    );
    await tester.enterText(search, 'Gomoku');
    await tester.pump();
    expect(find.text('All apps (1)'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('首页导航分离网络房间与设置', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.tap(find.byKey(const ValueKey('navigation-destination-1')));
    await tester.pump();
    expect(find.byIcon(Icons.lan), findsOneWidget);
    expect(find.byIcon(Icons.lan_outlined), findsNothing);
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('No rooms yet'), findsWidgets);
    manager.createdRooms.add(
      CreatedRoomInfo(
        name: 'Private',
        type: 0,
        port: 1234,
        encryptionKey: 'test-key',
        hasPassword: true,
        password: 'secret',
        server: SocketServer(
          roomName: 'Private',
          roomType: 0,
          encryptionKey: 'test-key',
          password: 'secret',
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('navigation-destination-2')));
    await tester.pump();
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Create Room'), findsNothing);
    await tester.tap(find.text('Default player name'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).last, 'Alice');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(PlayerSettings.instance.defaultName.value, 'Alice');
  });

  testWidgets('创建房间先选择类型，再输入名称和可选密码', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.tap(find.byKey(const ValueKey('navigation-destination-1')));
    await tester.pump();
    await tester.tap(find.text('Create Room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Gomoku'), findsOneWidget);
    await tester.ensureVisible(find.text('Gomoku'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Gomoku'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter room name'), findsOneWidget);
    expect(find.text('Room password'), findsOneWidget);
    expect(manager.createdRooms.value, isEmpty);
  });

  testWidgets('应用卡片可跳过类型选择快速创建联机房间', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.pump();

    final appCard = find.ancestor(
      of: find.text('Gomoku'),
      matching: find.byType(ListTile),
    );
    final quickCreateButton = find.descendant(
      of: appCard,
      matching: find.byTooltip('Quick create room'),
    );
    await tester.ensureVisible(quickCreateButton);
    await tester.tap(quickCreateButton);
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsWidgets);
    expect(find.text('Enter room name'), findsOneWidget);
    expect(find.text('Game'), findsNothing);
  });

  testWidgets('房间锁图标位于名称前，不替代游戏或聊天图标', (tester) async {
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.tap(find.byKey(const ValueKey('navigation-destination-1')));
    await tester.pump();

    for (final created in [false, true]) {
      for (final game in [false, true]) {
        for (final locked in [false, true]) {
          manager.createdRooms.value = [];
          manager.othersRooms.value = [];
          final type = game
              ? OnlineItemType.gobang.index
              : OnlineItemType.onlyChat.index;
          if (created) {
            manager.createdRooms.add(
              CreatedRoomInfo(
                name: 'Room',
                type: type,
                port: 1234,
                encryptionKey: 'test-key',
                hasPassword: locked,
                server: SocketServer(
                  roomName: 'Room',
                  roomType: type,
                  encryptionKey: 'test-key',
                ),
              ),
            );
          } else {
            manager.othersRooms.add(
              RoomInfo(
                name: 'Room',
                type: type,
                address: '192.168.1.2',
                port: 1234,
                encryptionKey: 'test-key',
                hasPassword: locked,
              ),
            );
          }
          await tester.pump();
          final tileFinder = find.ancestor(
            of: find.text('Room (0)'),
            matching: find.byType(ListTile),
          );
          final tile = tester.widget<ListTile>(tileFinder);
          expect(
            (tile.leading as Icon).icon,
            game ? Icons.gamepad : Icons.forum_outlined,
          );
          final lock = find.descendant(
            of: find.byWidget(tile.title!),
            matching: find.byIcon(Icons.lock_outline),
          );
          expect(lock, locked ? findsOneWidget : findsNothing);
          if (locked) {
            expect(
              tester.getRect(lock).right,
              lessThan(tester.getRect(find.text('Room (0)')).left),
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
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
