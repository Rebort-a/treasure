import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/session/turn_game_session.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/00.common/network/engine/network_engine.dart';
import 'package:treasure/02.lan_chat/net_page.dart';
import 'package:treasure/05.gobang/net_page.dart';

import '00.common/network/support/network_room_harness.dart';
import '00.common/network/support/match_game_driver.dart';

void main() {
  testWidgets(
    'card waits in chat, opens a matched game, and returns without reconnecting',
    (tester) async {
      HttpOverrides.global = null;
      LanguageProvider.instance.resetForTesting();
      final h = RoomHarness(3);
      var matchedCount = 0;
      TurnGameSession? opponent;
      Future<void> pumpUntil(bool Function() condition) async {
        for (var i = 0; i < 250; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (condition()) return;
        }
        throw StateError('Widget network state was not reached');
      }

      await tester.runAsync(() => h.server.start());
      try {
        final alice = (await tester.runAsync(() => h.join('Alice')))!;
        alice.matchPhase.addListener(() {
          if (alice.matchPhase.value == RoomMatchPhase.matched) matchedCount++;
        });
        await tester.pumpWidget(MaterialApp(home: NetGomokuPage(room: alice)));
        await pumpUntil(() => h.server.members.length == 1);
        await pumpUntil(() => find.text('Test room (1)').evaluate().isNotEmpty);
        final bob = (await tester.runAsync(() => h.join('Bob')))!;
        await pumpUntil(() => find.text('Test room (2)').evaluate().isNotEmpty);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.textContaining(' · '),
          ),
          findsNothing,
        );
        var searches = 0;
        bob.addMessageListener((m) {
          if (m.type != MessageType.search || m.id == bob.identity) return;
          searches++;
        });
        await tester.pump();
        expect(find.byType(PinnedRoomCard), findsOneWidget);
        expect(find.text('Start matching'), findsOneWidget);
        expect(find.byType(NetChatPage), findsOneWidget);
        await tester.tap(find.text('Start matching'));
        await tester.pump();
        await pumpUntil(() => searches == 1);
        expect(find.byType(NetGomokuPage), findsOneWidget);
        expect(find.text('Matching'), findsOneWidget);
        expect(find.text('Cancel matching'), findsOneWidget);
        expect(find.text('Start matching'), findsNothing);
        // 点击匹配中的卡片不能隐式重启搜索，更不会提前创建游戏引擎。
        await tester.tap(find.byIcon(Icons.gamepad));
        await tester.pump();
        expect(matchedCount, 0);
        expect(searches, 1);
        await tester.tap(find.text('Cancel matching'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        expect(searches, 1, reason: '取消匹配不得发送额外的 search');
        expect(find.text('Start matching'), findsOneWidget);
        expect(find.text('Matching'), findsNothing);
        expect(find.text('Cancel matching'), findsNothing);
        expect(matchedCount, 0);
        await tester.tap(find.text('Start matching'));
        await tester.pump();
        await pumpUntil(() => searches == 2);
        expect(matchedCount, 0);
        expect(h.server.members.length, 2);
        final aliceId = h.server.members.entries
            .firstWhere((e) => e.value == 'Alice')
            .key;
        await tester.runAsync(() async {
          bob.sendNetworkMessage(
            MessageType.text,
            'chat survives cancellation',
          );
        });
        await pumpUntil(
          () => find.text('chat survives cancellation').evaluate().isNotEmpty,
        );
        expect(find.byType(NetChatPage), findsOneWidget);
        expect(matchedCount, 0);

        opponent = TurnGameSession(
          room: bob,
          resourceMode: TurnResourceMode.none,
          searchHandler: () {},
          resourceHandler: (_, __) {},
          actionHandler: (_, __) {},
          exitHandler: () {},
        );
        await tester.runAsync(() async {
          startGame(opponent!);
        });
        await pumpUntil(() => opponent!.gameStep.value == GameStep.action);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(matchedCount, 1);
        expect(find.byType(NetGomokuPage), findsOneWidget);
        expect(find.byType(NetChatPage, skipOffstage: false), findsOneWidget);
        expect(find.byType(NetChatPage), findsNothing);
        expect(h.server.members.length, 2);

        await tester.runAsync(() async {
          bob.sendNetworkMessage(MessageType.text, 'public while playing');
          opponent!.sendNetworkMessage(MessageType.text, 'duel only');
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await pumpUntil(() => find.text('duel only').evaluate().isNotEmpty);
        expect(find.text('duel only'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(NetGomokuPage),
            matching: find.text('public while playing'),
          ),
          findsNothing,
        );
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();
        expect(find.text('Surrender'), findsWidgets);
        expect(find.text('Are you sure you want to surrender?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(find.text('duel only'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Are you sure you want to surrender?'), findsOneWidget);
        await tester.tap(find.text('Confirm'));
        await pumpUntil(
          () => find.byType(NetChatPage).evaluate().isNotEmpty,
        );
        expect(find.byType(NetGomokuPage), findsOneWidget);
        expect(find.byType(NetChatPage), findsOneWidget);
        expect(find.text('public while playing'), findsOneWidget);
        expect(find.text('duel only'), findsNothing);
        await pumpUntil(
          () => find.text('Start matching').evaluate().isNotEmpty,
        );
        expect(matchedCount, 1);
        expect(find.text('Start matching'), findsOneWidget);
        expect(find.text('Cancel matching'), findsNothing);
        expect(h.server.members[aliceId], 'Alice');
        expect(h.server.members.length, 2);
        await tester.runAsync(() => bob.close());
        await pumpUntil(() => find.text('Test room (1)').evaluate().isNotEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUntil(() => h.server.members.length == 0);
        expect(h.server.members.containsKey(aliceId), isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        opponent?.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => h.close());
      }
    },
  );
}
