import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
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
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Alice');
      await tester.enterText(_field('Room password'), 'wrong');
      await tester.tap(find.text('Join'));
      await _pumpUntil(
        tester,
        () => find.text('Incorrect room password').evaluate().isNotEmpty,
      );
      expect(find.byType(NetChatPage), findsNothing);
      expect(h.server.members, isEmpty);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, 'Alice');
      expect(
        tester.widget<TextField>(_field('Room password')).controller!.text,
        'wrong',
      );
      await tester.enterText(_field('Room password'), 'secret');
      await tester.tap(find.text('Join'));
      await tester.tap(find.text('Join'));
      await _pumpUntil(
        tester,
        () => find.byType(NetChatPage).evaluate().isNotEmpty,
      );
      final page = tester.widget<NetChatPage>(find.byType(NetChatPage));
      expect(page.room.isJoined, isTrue);
      expect(page.room.userName, 'Alice');
      expect(page.room.roomType, 3);
      expect(h.server.members, {page.room.identity: 'Alice'});
      expect(find.byType(NetChatPage), findsOneWidget);
      expect(find.byType(JoinRoomDialog), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
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
      await tester.enterText(find.byType(TextField).at(0), 'Alice');
      await tester.enterText(_field('IP'), '127.0.0.1');
      await tester.enterText(find.byType(TextField).at(2), '${server.port}');
      await tester.enterText(_field('Encryption key'), 'test-key');
      await tester.tap(find.text('Join'));
      await _pumpUntil(tester, () => receivedHandshake);
      expect(find.byType(NetChatPage), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Cancel'));
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
