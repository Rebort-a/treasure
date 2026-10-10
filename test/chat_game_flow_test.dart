import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/02.lan_chat/net_page.dart';
import 'package:treasure/01.home/route.dart';
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
      NetTurnEngine? opponent;
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
        await tester.pumpWidget(
          MaterialApp(home: RouteManager.createRoomPage(alice)),
        );
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
          // search 以原始消息回环，id 即发起者身份。
          if (m.type != MessageType.search || m.id == bob.identity) return;
          searches++;
        });
        await tester.pump();
        expect(find.byType(PinnedRoomCard), findsOneWidget);
        final gameCard = tester.widget<Card>(
          find.byKey(const ValueKey('room-game-card')),
        );
        expect(gameCard.color!.a, closeTo(0.72, 0.01));
        expect(gameCard.elevation, 0);
        expect(gameCard.surfaceTintColor, Colors.transparent);
        expect(gameCard.shadowColor, Colors.transparent);
        expect(find.text('Start matching'), findsOneWidget);
        expect(find.byType(NetChatPage), findsOneWidget);
        await tester.tap(find.text('Start matching'));
        await tester.pump();
        await pumpUntil(() => searches == 1);
        expect(find.byType(NetGomokuPage), findsNothing);
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

        opponent = configureTurnEngine(
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
        await pumpUntil(() => find.byType(NetChatPage).evaluate().isEmpty);
        expect(matchedCount, 1);
        expect(find.byType(NetGomokuPage), findsOneWidget);
        expect(find.byType(NetChatPage, skipOffstage: false), findsOneWidget);
        expect(find.byType(NetChatPage), findsNothing);
        expect(h.server.members.length, 2);

        await tester.runAsync(() async {
          bob.sendNetworkMessage(MessageType.text, 'public while playing');
          opponent!.sendGameMessage(MessageType.text, 'duel only');
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
        expect(find.text('Leave'), findsWidgets);
        expect(
          find.text(
            'Leave the game and return to chat? Use Surrender instead to stay here and replay.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(find.text('duel only'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(
          find.text(
            'Leave the game and return to chat? Use Surrender instead to stay here and replay.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Confirm'));
        await pumpUntil(
          () =>
              find.byType(NetChatPage).evaluate().isNotEmpty &&
              find
                  .byType(NetGomokuPage, skipOffstage: false)
                  .evaluate()
                  .isEmpty,
        );
        expect(find.byType(NetGomokuPage), findsNothing);
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
        final engine = NetTurnEngine.forClient(alice);
        final firstGameId = engine.gameId;
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
        await pumpUntil(
          () =>
              find.byType(NetGomokuPage).evaluate().isNotEmpty &&
              engine.gameStep.value == GameStep.action,
        );
        expect(engine, same(NetTurnEngine.forClient(alice)));
        expect(engine.gameId, isNot(firstGameId));
        expect(h.server.members[aliceId], 'Alice');
        await tester.runAsync(() async => opponent!.finishGame());
        await pumpUntil(
          () =>
              find
                  .byType(NetGomokuPage, skipOffstage: false)
                  .evaluate()
                  .isEmpty &&
              find.text('Start matching').evaluate().isNotEmpty,
        );
        expect(find.text('public while playing'), findsOneWidget);
        expect(h.server.members.length, 2);
        await tester.runAsync(() => bob.close());
        await pumpUntil(() => find.text('Test room (1)').evaluate().isNotEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUntil(() => h.server.members.length == 0);
        expect(h.server.members.containsKey(aliceId), isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          for (final room in h.rooms) {
            await room.close();
          }
        });
        opponent?.releaseGame();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => h.close());
      }
    },
  );
}
