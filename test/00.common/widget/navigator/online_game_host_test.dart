import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/widget/navigator/online_game_host.dart';

import '../../network/support/match_game_driver.dart';
import '../../network/support/network_room_harness.dart';

void main() {
  testWidgets('容器重建不重复创建 Manager，释放始终配对创建时的回调', (tester) async {
    HttpOverrides.global = null;
    final h = RoomHarness(3);
    final revision = ValueNotifier(1);
    var created = 0;
    var originalDisposed = 0;
    var replacementDisposed = 0;
    final managers = <NetTurnEngine>[];
    await tester.runAsync(() => h.server.start());
    try {
      final room = (await tester.runAsync(() => h.join('Alice')))!;
      final peer = (await tester.runAsync(() => h.join('Bob')))!;
      await tester.runAsync(() async {
        room.startMatching();
        peer.startMatching();
        await waitFor(
          () =>
              room.matchPhase.value == RoomMatchPhase.matched &&
              peer.matchPhase.value == RoomMatchPhase.matched,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: revision,
            builder: (_, version, _) => OnlineGameHost<NetTurnEngine>(
              createManager: () {
                created++;
                return configureTurnEngine(
                  room: room,
                  resourceMode: TurnResourceMode.none,
                  actionHandler: (_, _) {},
                  exitHandler: () {},
                );
              },
              engineOf: (manager) => manager,
              disposeManager: (manager) {
                manager.releaseGame();
                if (version == 1) {
                  originalDisposed++;
                } else {
                  replacementDisposed++;
                }
              },
              pageBuilder: (_, manager, _) {
                managers.add(manager);
                return Text('Version $version');
              },
            ),
          ),
        ),
      );
      expect(created, 1);
      expect(find.text('Version 1'), findsOneWidget);
      final manager = managers.first;
      expect(manager.isActive, isTrue);
      revision.value = 2;
      await tester.pump();
      expect(find.text('Version 2'), findsOneWidget);
      expect(created, 1);
      expect(managers.every((current) => identical(current, manager)), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(originalDisposed, 1);
      expect(replacementDisposed, 0);
      expect(manager.isActive, isFalse);
      expect(room.isJoined, isTrue, reason: '容器不拥有房间连接');
      expect(NetTurnEngine.forClient(room), same(manager));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.runAsync(() async {
        for (final room in h.rooms) {
          await room.close();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
      revision.dispose();
      await tester.runAsync(() => h.close());
    }
  });
}
