import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/02.lan_chat/net_page.dart';
import 'package:treasure/05.gobang/net_manager.dart';
import 'package:treasure/05.gobang/net_page.dart';

import '../00.common/network/support/match_game_driver.dart';
import '../00.common/network/support/network_room_harness.dart';

void main() {
  testWidgets('投降和自然胜负均停留棋盘，灰色重开层不影响聊天且重开不换路由', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    final h = RoomHarness(3);
    NetManager? remote;
    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 400; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 10));
        if (ready()) return;
      }
      fail('网络页面未进入预期状态');
    }

    await tester.runAsync(h.server.start);
    try {
      final alice = (await tester.runAsync(() => h.join('Alice')))!;
      final bob = (await tester.runAsync(() => h.join('Bob')))!;
      remote = NetManager(room: bob);
      await tester.pumpWidget(
        MaterialApp(
          home: NetChatPage(
            room: alice,
            gamePageBuilder: (_) => NetGomokuPage(room: alice),
          ),
        ),
      );
      await tester.tap(find.text(S.startMatching));
      await tester.pump();
      await tester.runAsync(() async => startGame(remote!.turnEngine));
      final engine = NetTurnEngine.forClient(alice);
      await until(
        () =>
            find.byType(NetGomokuPage).evaluate().isNotEmpty &&
            engine.gameStep.value == GameStep.action,
      );
      await tester.pump(const Duration(milliseconds: 400));
      final page = tester.element(find.byType(NetGomokuPage));
      final session = engine.gameId;
      engine.sendGameText('persistent round chat');
      await until(
        () => find.text('persistent round chat').evaluate().isNotEmpty,
      );
      await tester.tap(find.byIcon(Icons.flag));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(S.confirm));
      await until(
        () => find.byKey(const ValueKey('round-replay')).evaluate().isNotEmpty,
      );
      expect(find.byType(NetGomokuPage), findsOneWidget);
      expect(find.byType(NetChatPage), findsNothing);
      expect(find.text('persistent round chat'), findsOneWidget);
      final blockers = tester.widgetList<AbsorbPointer>(
        find.byType(AbsorbPointer),
      );
      expect(blockers.any((w) => w.absorbing), isTrue);
      await tester.tap(find.byKey(const ValueKey('round-replay')));
      await tester.pump();
      expect(engine.roundReplay!.waiting.value, isTrue);
      expect(find.byKey(const ValueKey('round-replay')), findsNothing);
      await until(() => remote!.turnEngine.roundReplay!.finished.value);
      remote.turnEngine.requestReplay();
      await until(
        () =>
            engine.roundReplay!.round == 1 &&
            engine.gameStep.value == GameStep.action,
      );
      expect(tester.element(find.byType(NetGomokuPage)), same(page));
      expect(engine.gameId, session);
      expect(find.text('persistent round chat'), findsOneWidget);
      expect(find.byKey(const ValueKey('round-replay')), findsNothing);
      // 新局通过真实落子产生胜利，而不是直接设置结束标志。
      for (final index in [0, 15, 1, 16, 2, 17, 3, 18, 4]) {
        final actor = index < 15 ? engine : remote.turnEngine;
        actor.sendGameMessage(MessageType.action, '{"index":$index}');
        await until(
          () =>
              remote!.board.moveHistory.length >=
              [0, 15, 1, 16, 2, 17, 3, 18, 4].indexOf(index) + 1,
        );
      }
      await until(
        () => find.byKey(const ValueKey('round-replay')).evaluate().isNotEmpty,
      );
      expect(find.byType(NetGomokuPage), findsOneWidget);
      expect(engine.ended.value, isFalse);
      engine.sendGameText('chat after victory');
      await until(() => find.text('chat after victory').evaluate().isNotEmpty);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await until(() => find.byType(NetChatPage).evaluate().isNotEmpty);
      expect(alice.isJoined, isTrue);
    } finally {
      await tester.runAsync(() async {
        for (final room in h.rooms) {
          await room.close();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      remote?.dispose();
      await tester.runAsync(h.close);
    }
  });
}
