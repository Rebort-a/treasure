import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/engine/net_turn_engine.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/00.common/network/network_room.dart';
import 'package:treasure/02.lan_chat/net_page.dart';
import 'package:treasure/01.home/route.dart';
import 'package:treasure/05.gobang/net_page.dart';

import 'support/network_room_harness.dart';

void main() {
  testWidgets(
    'card waits in chat, opens a matched game, and returns without reconnecting',
    (tester) async {
      HttpOverrides.global = null;
      LanguageProvider.instance.resetForTesting();
      final h = RoomHarness(3);
      NetTurnGameEngine? opponent;
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
        await tester.pumpWidget(
          MaterialApp(
            home: NetChatPage(
              gameFactory: RouteManager.createRoomGame,
              userName: 'Alice',
              roomInfo: RoomInfo(
                name: 'IP join',
                type: 0,
                address: '127.0.0.1',
                port: h.server.port,
              ),
            ),
          ),
        );
        await pumpUntil(() => h.server.session.count == 1);
        final bob = (await tester.runAsync(() => h.join('Bob')))!;
        var searches = 0;
        bob.addMessageListener((m) {
          if (m.type == MessageType.search && m.id != bob.identity) searches++;
        });
        await tester.pump();
        expect(find.byType(PinnedRoomCard), findsOneWidget);
        expect(find.text('Click to play'), findsOneWidget);
        expect(find.byType(NetGomokuPage), findsNothing);
        await tester.tap(find.text('Click to play'));
        await tester.pump();
        await pumpUntil(() => searches == 1);
        expect(find.byType(NetGomokuPage), findsNothing);
        await tester.tap(find.text('Click to play'));
        await tester.pump();
        await pumpUntil(() => searches == 2);
        expect(h.server.session.count, 2);
        final aliceId = h.server.session.members.entries
            .firstWhere((e) => e.value == 'Alice')
            .key;

        opponent = NetTurnGameEngine(
          room: bob,
          resourceMode: TurnResourceMode.none,
          searchHandler: () {},
          resourceHandler: (_, __) {},
          actionHandler: (_, __) {},
          exitHandler: () {},
        );
        await tester.runAsync(() async {
          opponent!.start();
        });
        await pumpUntil(() => opponent!.gameStep.value == GameStep.action);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(NetGomokuPage), findsOneWidget);
        expect(h.server.session.count, 2);

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
        await pumpUntil(() => find.byType(NetGomokuPage).evaluate().isEmpty);
        expect(find.byType(NetGomokuPage), findsNothing);
        expect(find.text('public while playing'), findsOneWidget);
        expect(find.text('duel only'), findsNothing);
        expect(h.server.session.members[aliceId], 'Alice');
        expect(h.server.session.count, 2);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUntil(() => h.server.session.count == 1);
        expect(h.server.session.members.containsKey(aliceId), isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        opponent?.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => h.close());
      }
    },
  );
}
