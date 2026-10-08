import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/06.greedy_snake/net_page.dart';
import 'package:treasure/06.greedy_snake/net_manager.dart' as snake;
import 'package:treasure/06.greedy_snake/foundation_widget.dart';
import 'package:treasure/02.lan_chat/net_page.dart';
import 'package:treasure/01.home/route.dart';

import '00.common/network/support/network_room_harness.dart';

void main() {
  testWidgets('实时模式单人留在聊天室，协调与同步完成后才打开游戏页面', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    final h = RoomHarness(4);
    snake.NetManager? peerGame;

    Future<void> pumpUntil(bool Function() condition) async {
      for (var i = 0; i < 250; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (condition()) return;
      }
      throw StateError('Realtime chat transition was not reached');
    }

    await tester.runAsync(() => h.server.start());
    try {
      final host = (await tester.runAsync(() => h.join('Host')))!;
      await tester.pumpWidget(
        MaterialApp(home: RouteManager.createRoomPage(host)),
      );
      await tester.tap(find.text('Start matching'));
      await tester.pump();
      await pumpUntil(() => find.text('Cancel matching').evaluate().isNotEmpty);
      expect(find.byType(GameScreen), findsNothing);
      expect(find.text('Cancel matching'), findsOneWidget);

      final guest = (await tester.runAsync(() => h.join('Guest')))!;
      guest.matchPhase.addListener(() {
        if (guest.matchPhase.value != RoomMatchPhase.matched) return;
        peerGame = snake.NetManager(room: guest)..realEngine.startFromRoom();
        guest.openMatchedGame();
      });
      guest.startMatching();
      await pumpUntil(() => find.byType(GameScreen).evaluate().isNotEmpty);
      await pumpUntil(
        () => peerGame?.realEngine.gameStep.value == GameStep.action,
      );
      await pumpUntil(() => find.byType(NetChatPage).evaluate().isEmpty);
      expect(peerGame?.realEngine.readyToOpen.value, isTrue);
      expect(h.server.members.length, 2);
      expect(find.byType(NetGreedySnakePage), findsOneWidget);
      expect(find.byType(NetChatPage), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(NetChatPage), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await pumpUntil(
        () =>
            find.byType(NetChatPage).evaluate().isNotEmpty &&
            find
                .byType(NetGreedySnakePage, skipOffstage: false)
                .evaluate()
                .isEmpty,
      );
      expect(find.byType(NetGreedySnakePage), findsNothing);
      expect(h.server.members.length, 2);
    } finally {
      peerGame?.dispose();
      // 从真实异步环境先关闭房间，再卸载带有定时器的游戏页面。
      if (h.rooms.isNotEmpty) {
        await tester.runAsync(() => h.rooms.first.close());
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => h.close());
    }
  });
}
