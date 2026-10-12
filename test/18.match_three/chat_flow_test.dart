import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/network/client/net_multi_turn_engine.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/01.home/upper/route.dart';
import 'package:treasure/02.lan_chat/net_page.dart';
import 'package:treasure/18.match_three/middle/net_manager.dart';
import 'package:treasure/18.match_three/upper/net_page.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';

import '../00.common/network/support/match_game_driver.dart';
import '../00.common/network/support/network_room_harness.dart';

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
  }
  throw StateError('Cooperative room route did not reach expected state');
}

void main() {
  testWidgets('队内聊天在小窗口和键盘遮挡下保留草稿、可发送并返回游戏', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    try {
      await tester.runAsync(() async {
        await h.server.start();
        for (final name in ['Alice', 'Bob']) {
          games.add(
            NetMatchManager(room: await h.join(name))..reduceMotion = true,
          );
        }
        for (final game in games) {
          startGame(game.turnEngine);
        }
        await waitFor(
          () => games.every((g) => g.turnEngine.synchronized.value),
        );
      });
      final local = games.first;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: MatchGameView(
            manager: local,
            engine: local.turnEngine,
            onExit: () {},
          ),
        ),
      );
      await tester.tap(find.byTooltip(S.matchTeamChat));
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      const draft = 'Keep this draft when the keyboard opens';
      await tester.enterText(input, draft);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 360);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(draft), findsOneWidget);

      await tester.ensureVisible(input);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await _until(
        tester,
        () => games.last.turnEngine.gameMessageList.value.any(
          (message) => message.content == draft,
        ),
      );
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(S.close));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(MatchGameView), findsOneWidget);
      expect(h.rooms.first.isJoined, isTrue);
      expect(local.board!.moveNumber, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final game in games) {
        game.dispose();
      }
      await tester.runAsync(h.close);
    }
  });

  testWidgets('聊天室匹配进入简单游戏页，第三人加入，系统返回只退出本人并保留聊天连接', (tester) async {
    HttpOverrides.global = null;
    LanguageProvider.instance.resetForTesting();
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final remotes = <NetMatchManager>[];
    await tester.runAsync(() => h.server.start());
    try {
      final alice = (await tester.runAsync(() => h.join('Alice')))!;
      final bob = (await tester.runAsync(() => h.join('Bob')))!;
      final dana = (await tester.runAsync(() => h.join('Dana')))!;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RouteManager.createRoomPage(alice),
                  ),
                ),
                child: const Text('Open room'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open room'));
      await tester.pumpAndSettle();
      expect(find.byType(NetChatPage), findsOneWidget);
      expect(find.byType(NetMatchThreePage), findsNothing);
      final remote = NetMatchManager(room: bob)..reduceMotion = true;
      remotes.add(remote);
      await tester.tap(find.text(S.startMatching));
      final local = NetMultiTurnEngine.forClient(alice);
      // 本地先准备，随后验证自己的回合及 0/3 → 2/3 → 1/3 等待人数。
      await _until(
        tester,
        () => local.matchPhase.value == RoomMatchPhase.matching,
      );
      startGame(remote.turnEngine);
      await _until(
        tester,
        () =>
            find.byType(NetMatchThreePage).evaluate().isNotEmpty &&
            local.synchronized.value,
      );
      expect(find.byType(MatchGameView), findsOneWidget);
      final originalGame = local.gameId;
      final third = NetMatchManager(room: dana)..reduceMotion = true;
      remotes.add(third);
      startGame(third.turnEngine);
      await _until(
        tester,
        () =>
            local.participants.length == 3 &&
            local.synchronized.value &&
            remotes.every((g) => g.turnEngine.synchronized.value),
      );
      expect(find.text(S.matchYourTurn), findsOneWidget);
      final view = tester.widget<MatchGameView>(find.byType(MatchGameView));
      final swap = view.manager.board!.legalMoves.first;
      view.manager.swap(swap.$1, swap.$2);
      await _until(
        tester,
        () =>
            view.manager.board!.moveNumber == 1 &&
            remotes.every(
              (g) =>
                  g.board!.moveNumber == 1 && g.turnEngine.synchronized.value,
            ),
      );
      expect(
        find.text(
          S.matchPlayerTurn(local.participants[local.currentPlayer.value]!),
        ),
        findsOneWidget,
      );
      final next = remotes.firstWhere((g) => g.turnEngine.canAct);
      final nextSwap = next.board!.legalMoves.first;
      next.swap(nextSwap.$1, nextSwap.$2);
      await _until(
        tester,
        () =>
            view.manager.board!.moveNumber == 2 &&
            local.synchronized.value &&
            remotes.every(
              (g) =>
                  g.board!.moveNumber == 2 && g.turnEngine.synchronized.value,
            ),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(S.coopConfirmLeave), findsOneWidget);
      await tester.tap(find.text(S.confirm));
      await _until(
        tester,
        () =>
            find.byType(NetMatchThreePage).evaluate().isEmpty &&
            remotes.every(
              (g) =>
                  g.turnEngine.participants.length == 2 &&
                  g.turnEngine.synchronized.value,
            ),
      );
      expect(find.byType(NetChatPage), findsOneWidget);
      expect(alice.isJoined, isTrue);
      expect(RoomChatEngine.forClient(alice), same(local));
      expect(local.ended.value, isTrue);
      expect(remotes.first.turnEngine.gameId, originalGame);
      expect(remotes.first.board!.moveNumber, 2);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.runAsync(() async {
        for (final room in h.rooms) {
          await room.close();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      for (final remote in remotes) {
        remote.dispose();
      }
      await tester.runAsync(() => h.close());
    }
  });
}
