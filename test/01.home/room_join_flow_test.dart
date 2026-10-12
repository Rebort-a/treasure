import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/00.common/widget/navigator/notifier_navigator.dart';
import 'package:treasure/01.home/home_manager.dart';
import 'package:treasure/01.home/dialog.dart';
import 'package:treasure/01.home/player_settings.dart';
import 'package:treasure/02.lan_chat/net_page.dart';

import '../00.common/network/support/network_room_harness.dart';

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
  }
  throw StateError('页面状态未及时更新');
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Widget _home(HomeManager manager, VoidCallback join) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        NotifierNavigator(navigatorHandler: manager.pageNavigator),
        const Text('Home marker'),
        ElevatedButton(onPressed: join, child: const Text('Open room')),
      ],
    ),
  ),
);

void main() {
  for (final password in <String?>[null, 'secret']) {
    testWidgets('手动加入从服务器取得密钥并打开正确游戏入口：password=$password', (tester) async {
      HttpOverrides.global = null;
      LanguageProvider.instance.resetForTesting();
      PlayerSettings.instance.resetForTesting();
      final h = RoomHarness(3, password: password, key: 'server-only-key');
      final manager = HomeManager(startDiscovery: false);
      await tester.runAsync(() => h.server.start());
      try {
        await tester.pumpWidget(_home(manager, manager.showJoinByIpDialog));
        await tester.tap(find.text('Open room'));
        await _pumpUntil(
          tester,
          () => find.byType(JoinRoomDialog).evaluate().isNotEmpty,
        );
        await tester.enterText(_field(S.enterUserName), 'Alice');
        await tester.enterText(_field('IP'), '127.0.0.1');
        await tester.enterText(_field(S.port), '${h.server.port}');
        if (password != null) {
          await tester.enterText(_field(S.roomPassword), 'wrong');
          await tester.tap(find.text(S.join));
          await _pumpUntil(
            tester,
            () => find.text(S.incorrectRoomPassword).evaluate().isNotEmpty,
          );
          expect(find.byType(NetChatPage), findsNothing);
          expect(h.server.members, isEmpty);
          await tester.enterText(_field(S.roomPassword), password);
        }
        await tester.tap(find.text(S.join));
        await _pumpUntil(
          tester,
          () => find.byType(NetChatPage).evaluate().isNotEmpty,
        );
        final page = tester.widget<NetChatPage>(find.byType(NetChatPage));
        expect(page.room.endpoint, isNot(isA<RoomInfo>()));
        expect(page.room.encryptionKey, 'server-only-key');
        expect(page.room.roomName, 'Test room');
        expect(page.room.roomType, 3);
        expect(page.gamePageBuilder, isNotNull);
        expect(page.gameName, 'gobang');
        expect(h.server.members, {page.room.identity: 'Alice'});
        expect(find.byType(JoinRoomDialog), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        manager.dispose();
        await tester.runAsync(() => h.close());
      }
    });
  }

  testWidgets('密码错误留在主页并保留输入，认证成功后才打开聊天室且只创建一个成员', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    PlayerSettings.instance.resetForTesting();
    final h = RoomHarness(3, password: 'secret');
    final manager = HomeManager(startDiscovery: false);
    await tester.runAsync(() => h.server.start());
    try {
      await tester.pumpWidget(
        _home(
          manager,
          () => manager.showJoinRoomDialog(
            RoomInfo(
              name: 'Test room',
              type: 3,
              address: '127.0.0.1',
              port: h.server.port,
              encryptionKey: h.server.encryptionKey,
              hasPassword: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open room'));
      await _pumpUntil(
        tester,
        () => find.byType(JoinRoomDialog).evaluate().isNotEmpty,
      );
      await tester.enterText(_field(S.enterUserName), 'Alice');
      await tester.enterText(_field(S.roomPassword), 'wrong');
      await tester.tap(find.text(S.join));
      await _pumpUntil(
        tester,
        () => find.text(S.incorrectRoomPassword).evaluate().isNotEmpty,
      );
      expect(find.byType(NetChatPage), findsNothing);
      expect(h.server.members, isEmpty);
      expect(
        tester.widget<TextField>(_field(S.enterUserName)).controller!.text,
        'Alice',
      );
      expect(
        tester.widget<TextField>(_field(S.roomPassword)).controller!.text,
        'wrong',
      );
      await tester.enterText(_field(S.roomPassword), 'secret');
      await tester.tap(find.text(S.join));
      await tester.tap(find.text(S.join));
      await _pumpUntil(
        tester,
        () => find.byType(NetChatPage).evaluate().isNotEmpty,
      );
      final page = tester.widget<NetChatPage>(find.byType(NetChatPage));
      expect(page.room.isJoined, isTrue);
      expect(page.room.userName, 'Alice');
      expect(page.room.roomType, 3);
      expect(page.gamePageBuilder, isNotNull);
      expect(page.gameName, 'gobang');
      expect(h.server.members, {page.room.identity: 'Alice'});
      expect(find.byType(NetChatPage), findsOneWidget);
      expect(find.byType(JoinRoomDialog), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await _pumpUntil(
        tester,
        () =>
            find.text('Home marker').evaluate().isNotEmpty &&
            find.byType(NetChatPage).evaluate().isEmpty &&
            h.server.members.isEmpty,
      );
      expect(find.byType(NetChatPage), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
      await tester.runAsync(() => h.close());
    }
  });

  testWidgets('等待认证时取消，只关闭待加入连接，不跳转也不误退出主页', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    PlayerSettings.instance.resetForTesting();
    final manager = HomeManager(startDiscovery: false);
    final server = (await tester.runAsync(
      () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    ))!;
    final sockets = <WebSocket>[];
    var receivedHandshake = false;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) => receivedHandshake = true);
    });
    try {
      await tester.pumpWidget(_home(manager, manager.showJoinByIpDialog));
      await tester.tap(find.text('Open room'));
      await _pumpUntil(
        tester,
        () => find.byType(JoinRoomDialog).evaluate().isNotEmpty,
      );
      await tester.enterText(_field(S.enterUserName), 'Alice');
      await tester.enterText(_field('IP'), '127.0.0.1');
      await tester.enterText(_field(S.port), '${server.port}');
      await tester.tap(find.text(S.join));
      await _pumpUntil(tester, () => receivedHandshake);
      expect(find.byType(NetChatPage), findsNothing);
      await tester.tap(find.text(S.cancel));
      await _pumpUntil(
        tester,
        () => find.byType(JoinRoomDialog).evaluate().isEmpty,
      );
      expect(find.text('Home marker'), findsOneWidget);
      expect(find.byType(NetChatPage), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
      await tester.runAsync(() async {
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      });
    }
  });
}
