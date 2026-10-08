import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/network/client/base/game_engine.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/widget/online_game_host.dart';
import 'package:treasure/01.home/route.dart';
import 'package:treasure/02.lan_chat/net_page.dart';

import '../00.common/network/support/match_game_driver.dart';
import '../00.common/network/support/network_room_harness.dart';

class _RoutesObserver extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

/// 模拟由外部模块注入的单局页面；聊天室完全不需要知道它的具体类型。
class _InjectedGamePage extends StatelessWidget {
  final SocketClient room;
  final VoidCallback onCreated;
  final VoidCallback onDisposed;

  const _InjectedGamePage({
    required this.room,
    required this.onCreated,
    required this.onDisposed,
  });

  @override
  Widget build(BuildContext context) => OnlineGameHost<NetTurnEngine>(
    createManager: () {
      onCreated();
      return configureTurnEngine(
        room: room,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      );
    },
    engineOf: (manager) => manager,
    disposeManager: (manager) {
      manager.releaseGame();
      onDisposed();
    },
    pageBuilder: (context, manager, requestExit) => Scaffold(
      body: Column(
        children: [
          const Text('Injected game'),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Game detail')),
              ),
            ),
            child: const Text('Open detail'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  throw StateError('Room route lifecycle did not reach the expected state');
}

Future<void> _cleanup(WidgetTester tester, RoomHarness h) async {
  // close 从真实异步区发起，避免等待由 FakeAsync 计时器持有的关闭 Future。
  await tester.runAsync(() async {
    for (final room in h.rooms) {
      await room.close();
    }
  });
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(() => h.close());
}

void main() {
  testWidgets('没有注入游戏入口时即为普通聊天室，不按房间类型自行创建卡片', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    final h = RoomHarness(3);
    await tester.runAsync(() => h.server.start());
    try {
      final room = (await tester.runAsync(() => h.join('Alice')))!;
      await tester.pumpWidget(MaterialApp(home: NetChatPage(room: room)));
      expect(find.byType(PinnedRoomCard), findsNothing);
      expect(find.text('Start matching'), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is OnlineGameHost),
        findsNothing,
      );
      expect(room.isJoined, isTrue);
    } finally {
      await _cleanup(tester, h);
    }
  });

  test('首页纯聊天入口不注入游戏工厂', () async {
    final h = RoomHarness(0);
    await h.server.start();
    try {
      final room = await h.join('Alice');
      final page = RouteManager.createRoomPage(room);
      expect(page, isA<NetChatPage>());
      expect(page.gamePageBuilder, isNull);
      expect(page.gameName, isEmpty);
    } finally {
      await h.close();
    }
  });

  test('所有游戏类型都统一创建聊天室，工厂未调用时不配置游戏 Manager', () async {
    for (final type in OnlineItemType.values.where(
      (type) => type != OnlineItemType.onlyChat,
    )) {
      final h = RoomHarness(type.index);
      await h.server.start();
      try {
        final room = await h.join('Alice');
        final page = RouteManager.createRoomPage(room);
        expect(page, isA<NetChatPage>());
        expect(page.gamePageBuilder, isNotNull);
        expect(page.gameName, type.name);
        expect(
          (RoomChatEngine.forClient(room) as GameEngine).ended.value,
          isTrue,
        );
      } finally {
        await h.close();
      }
    }
  });

  testWidgets('各游戏只公开普通 StatelessWidget 入口，构建容器仍不提前创建 Manager', (tester) async {
    HttpOverrides.global = null;
    for (final type in OnlineItemType.values.where(
      (type) => type != OnlineItemType.onlyChat,
    )) {
      final h = RoomHarness(type.index);
      await tester.runAsync(() => h.server.start());
      try {
        final room = (await tester.runAsync(() => h.join('Alice')))!;
        final chat = RouteManager.createRoomPage(room);
        late Widget entry;
        late Widget container;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                entry = chat.gamePageBuilder!(context);
                // 这里只构建组合入口，不挂载返回的容器，验证创建时机。
                container = (entry as StatelessWidget).build(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(entry, isA<StatelessWidget>());
        expect(container, isA<OnlineGameHost>());
        expect(
          (RoomChatEngine.forClient(room) as GameEngine).ended.value,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _cleanup(tester, h);
      }
    }
  });

  testWidgets('延迟构建单局路由，重复开局复用连接，整栈卸载后只释放一次资源', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    final h = RoomHarness(3);
    final routes = _RoutesObserver();
    var factories = 0;
    var created = 0;
    var disposed = 0;
    NetTurnEngine? opponent;
    await tester.runAsync(() => h.server.start());
    try {
      final alice = (await tester.runAsync(() => h.join('Alice')))!;
      final bob = (await tester.runAsync(() => h.join('Bob')))!;
      final identity = alice.identity;
      final engine = NetTurnEngine.forClient(alice);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          home: NetChatPage(
            room: alice,
            // 不传名称时使用已认证的房间类型，入口是否存在只由工厂决定。
            gamePageBuilder: (_) {
              factories++;
              return _InjectedGamePage(
                room: alice,
                onCreated: () => created++,
                onDisposed: () => disposed++,
              );
            },
          ),
        ),
      );
      expect(factories, 0);
      expect(created, 0);
      expect(find.byType(PinnedRoomCard), findsOneWidget);
      expect(routes.pushes, 1);
      opponent = configureTurnEngine(
        room: bob,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      );
      await tester.tap(find.text('Start matching'));
      await tester.pump();
      expect(factories, 0);
      await tester.runAsync(() async => startGame(opponent!));
      await _pumpUntil(
        tester,
        () =>
            find.text('Injected game').evaluate().isNotEmpty &&
            find.byType(NetChatPage).evaluate().isEmpty,
      );
      expect(created, 1);
      expect(routes.pushes, 2);
      expect(disposed, 0);
      expect(find.byType(NetChatPage, skipOffstage: false), findsOneWidget);
      final firstGame = engine.gameId;
      await tester.tap(find.text('Open detail'));
      await _pumpUntil(
        tester,
        () => find.text('Game detail').evaluate().isNotEmpty,
      );
      expect(routes.pushes, 3);
      await tester.runAsync(() async => opponent!.finishGame());
      await _pumpUntil(
        tester,
        () =>
            disposed == 1 && find.text('Start matching').evaluate().isNotEmpty,
      );
      expect(routes.pops, 2);
      expect(find.text('Game detail', skipOffstage: false), findsNothing);
      expect(alice.identity, identity);
      expect(alice.isJoined, isTrue);
      expect(NetTurnEngine.forClient(alice), same(engine));

      opponent!.releaseGame();
      opponent = configureTurnEngine(
        room: bob,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      );
      await tester.tap(find.text('Start matching'));
      await tester.pump();
      await tester.runAsync(() async => startGame(opponent!));
      await _pumpUntil(tester, () => created == 2 && engine.isActive);
      expect(routes.pushes, 4);
      expect(engine.gameId, isNot(firstGame));
      expect(alice.identity, identity);

      // 不先关闭网络，直接卸载包含聊天室和游戏的整个 Navigator。
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUntil(
        tester,
        () => disposed == 2 && !h.server.members.containsKey(identity),
      );
      expect(alice.isJoined, isFalse);
      expect(disposed, 2);
      expect(tester.takeException(), isNull);
    } finally {
      await _cleanup(tester, h);
      opponent?.releaseGame();
    }
  });
}
