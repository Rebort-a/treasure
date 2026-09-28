import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/engine/net_game_engine.dart';
import 'package:treasure/00.common/engine/net_turn_engine.dart';
import 'package:treasure/00.common/engine/net_real_engine.dart';
import 'package:treasure/00.common/engine/network_engine.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/06.greedy_snake/net_manager.dart' as snake;
import 'package:treasure/17.tank/net_manager.dart' as tank;

import 'support/network_room_harness.dart';

NetTurnGameEngine turn(
  NetworkEngine room, {
  TurnResourceMode mode = TurnResourceMode.none,
  void Function()? search,
  void Function(GameStep, NetworkMessage)? resource,
  void Function(bool, NetworkMessage)? action,
}) => NetTurnGameEngine(
  room: room,
  resourceMode: mode,
  searchHandler: search ?? () {},
  resourceHandler: resource ?? (_, __) {},
  actionHandler: action ?? (_, __) {},
  exitHandler: () {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'click starts a session; matching and private chat share the room socket',
    () async {
      final h = RoomHarness(3);
      final games = <NetGameEngine>[];
      await h.server.start();
      try {
        final aRoom = await h.join('Alice');
        final bRoom = await h.join('Bob');
        final cRoom = await h.join('Carol');
        final dRoom = await h.join('Dan');
        final ids = h.rooms.map((r) => r.identity).toList();
        final a = turn(aRoom);
        games.add(a);
        a.start();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(a.gameStep.value, GameStep.start);
        expect(a.readyToOpen.value, isFalse);
        final b = turn(bRoom);
        games.add(b);
        b.start();
        await waitFor(() => a.readyToOpen.value && b.readyToOpen.value);
        expect(a.playerType, TurnGamerType.front);
        expect(b.playerType, TurnGamerType.rear);
        expect(a.gameStep.value, GameStep.action);
        final c = turn(cRoom);
        games.add(c);
        c.start();
        final d = turn(dRoom);
        games.add(d);
        d.start();
        await waitFor(() => c.readyToOpen.value && d.readyToOpen.value);
        a.sendNetworkMessage(MessageType.text, 'private');
        cRoom.sendNetworkMessage(
          MessageType.text,
          'room message while playing',
        );
        await waitFor(
          () =>
              b.messageList.value.any((m) => m.content == 'private') &&
              aRoom.messageList.value.any(
                (m) => m.content == 'room message while playing',
              ),
        );
        expect(c.messageList.value, isEmpty);
        expect(
          aRoom.messageList.value.any((m) => m.content == 'private'),
          isFalse,
        );
        expect(h.server.session.count, 4);
        a.finish();
        await waitFor(() => b.ended.value);
        expect(h.rooms.map((r) => r.identity).toList(), ids);
        expect(h.server.session.count, 4);
        expect(c.ended.value, isFalse);
        final retryA = turn(aRoom);
        games.add(retryA);
        retryA.start();
        final retryB = turn(bRoom);
        games.add(retryB);
        retryB.start();
        await waitFor(
          () => retryA.readyToOpen.value && retryB.readyToOpen.value,
        );
        expect(retryA.sessionId, isNot(a.sessionId));
        aRoom.sendNetworkMessage(
          MessageType.exit,
          'late old exit',
          targetId: bRoom.identity,
          sessionId: a.sessionId,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(retryB.ended.value, isFalse);
      } finally {
        for (final game in games) {
          game.dispose();
        }
        await h.close();
      }
    },
  );

  for (final mode in [TurnResourceMode.frontOnly, TurnResourceMode.both]) {
    test('turn resource flow: ${mode.name}', () async {
      final h = RoomHarness(mode == TurnResourceMode.frontOnly ? 1 : 2);
      await h.server.start();
      NetTurnGameEngine? a;
      NetTurnGameEngine? b;
      final receivedA = <GameStep>[];
      final receivedB = <GameStep>[];
      try {
        final ra = await h.join('A');
        final rb = await h.join('B');
        a = turn(
          ra,
          mode: mode,
          search: () => a!.sendNetworkMessage(MessageType.resource, 'front'),
          resource: (step, _) => receivedA.add(step),
        );
        b = turn(
          rb,
          mode: mode,
          resource: (step, _) {
            receivedB.add(step);
          },
        );
        a.start();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        b.start();
        await waitFor(() => receivedB.isNotEmpty);
        if (mode == TurnResourceMode.both) {
          expect(a.gameStep.value, GameStep.frontWait);
          expect(b.gameStep.value, GameStep.rearConfig);
          b.sendNetworkMessage(MessageType.resource, 'rear');
        }
        await waitFor(
          () =>
              a!.gameStep.value == GameStep.action &&
              b!.gameStep.value == GameStep.action,
        );
        expect(
          receivedA,
          mode == TurnResourceMode.both
              ? [GameStep.frontConfig, GameStep.frontWait]
              : [GameStep.frontConfig],
        );
        expect(
          receivedB,
          mode == TurnResourceMode.both
              ? [GameStep.rearWait, GameStep.rearConfig]
              : [GameStep.rearWait],
        );
      } finally {
        a?.dispose();
        b?.dispose();
        await h.close();
      }
    });
  }

  test(
    'repeated clicks replace a waiting engine without creating sockets',
    () async {
      final h = RoomHarness(3);
      await h.server.start();
      NetTurnGameEngine? old;
      NetTurnGameEngine? current;
      NetTurnGameEngine? b;
      try {
        final ra = await h.join('A');
        final rb = await h.join('B');
        old = turn(ra)..start();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        old.finish();
        current = turn(ra)..start();
        b = turn(rb)..start();
        await waitFor(() => current!.readyToOpen.value && b!.readyToOpen.value);
        expect(old.ended.value, isTrue);
        expect(h.server.session.count, 2);
        expect(current.requestId, isNot(old.requestId));
      } finally {
        old?.dispose();
        current?.dispose();
        b?.dispose();
        await h.close();
      }
    },
  );

  test(
    'real-time resources do not open the page until every sync arrives',
    () async {
      final h = RoomHarness(6);
      await h.server.start();
      final games = <NetRealGameEngine>[];
      final syncs = <int, Set<int>>{};
      final resources = <int>{};
      try {
        final ra = await h.join('A');
        final rb = await h.join('B');
        NetRealGameEngine create(NetworkEngine room) {
          late NetRealGameEngine engine;
          engine = NetRealGameEngine(
            room: room,
            maxPlayers: 4,
            searchHandler: (_) =>
                engine.sendNetworkMessage(MessageType.resource, 'state'),
            resourceHandler: (_) {
              resources.add(room.identity);
            },
            syncHandler: (m) {
              final seen = syncs.putIfAbsent(room.identity, () => <int>{})
                ..add(m.id);
              if (seen.length == 2) engine.completeSynchronization();
            },
            actionHandler: (_) {},
            exitHandler: (_) {},
          );
          games.add(engine);
          return engine;
        }

        final a = create(ra)..start();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final b = create(rb)..start();
        await waitFor(() => resources.length == 2);
        expect(a.readyToOpen.value, isFalse);
        expect(b.readyToOpen.value, isFalse);
        a.sendNetworkMessage(MessageType.sync, 'ready');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(a.readyToOpen.value, isFalse);
        b.sendNetworkMessage(MessageType.sync, 'ready');
        await waitFor(() => a.readyToOpen.value && b.readyToOpen.value);
      } finally {
        for (final e in games) {
          e.dispose();
        }
        await h.close();
      }
    },
  );

  test(
    'tank starts at two, caps at four, and admits a waiting player',
    () async {
      final h = RoomHarness(6);
      final managers = <tank.NetTankManager>[];
      await h.server.start();
      try {
        for (var i = 0; i < 5; i++) {
          final room = await h.join('P$i');
          final manager = tank.NetTankManager(room: room);
          managers.add(manager);
          manager.engine.start();
          if (i == 0 || i == 4) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            expect(manager.engine.readyToOpen.value, isFalse);
          } else {
            await waitFor(() => manager.engine.readyToOpen.value);
            expect(manager.tanks.values.where((t) => t.isPlayer).length, i + 1);
          }
        }
        expect(h.server.session.count, 5);
        managers[1].engine.finish();
        await waitFor(() => managers[4].engine.readyToOpen.value);
        expect(managers[0].tanks.values.where((t) => t.isPlayer).length, 4);
        expect(managers[4].authorityId, managers[0].identity);
        managers[0].engine.finish();
        await waitFor(() => managers[4].authorityId == managers[2].identity);
        expect(h.server.session.count, 5);
      } finally {
        for (final manager in managers) {
          manager.dispose();
        }
        await h.close();
      }
    },
  );

  test(
    'snake newcomer resync keeps only heads and preserves the room connection',
    () async {
      final h = RoomHarness(4);
      await h.server.start();
      final managers = <snake.NetManager>[];
      try {
        final ra = await h.join('Alice');
        final rb = await h.join('Bob');
        final a = snake.NetManager(room: ra);
        managers.add(a);
        a.engine.start();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(a.snakes, isEmpty);
        expect(a.engine.readyToOpen.value, isFalse);
        final b = snake.NetManager(room: rb);
        managers.add(b);
        b.engine.start();
        await waitFor(
          () => a.engine.readyToOpen.value && b.engine.readyToOpen.value,
        );
        expect(a.engine.publisherId, ra.identity);
        expect(b.engine.publisherId, ra.identity);
        a.suspendGame();
        b.suspendGame();
        a.snakes[ra.identity]!.body.add(const Offset(10, 10));
        b.snakes[rb.identity]!.body.add(const Offset(20, 20));
        final rc = await h.join('Carol');
        final c = snake.NetManager(room: rc);
        managers.add(c);
        c.engine.start();
        await waitFor(
          () =>
              c.engine.readyToOpen.value &&
              a.snakes.length == 3 &&
              b.snakes.length == 3,
        );
        for (final manager in managers) {
          expect(manager.snakes.values.every((s) => s.body.isEmpty), isTrue);
        }
        c.engine.finish();
        await waitFor(() => a.snakes.length == 2 && b.snakes.length == 2);
        expect(h.server.session.count, 3);
        expect(rc.identity, isNot(0));
        final rejoined = snake.NetManager(room: rc);
        managers.add(rejoined);
        rejoined.engine.start();
        await waitFor(
          () => rejoined.engine.readyToOpen.value && a.snakes.length == 3,
        );
        rc.sendNetworkMessage(
          MessageType.exit,
          jsonEncode({'request': c.engine.requestId}),
          sessionId: c.engine.sessionId,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(a.snakes.length, 3);
        expect(h.server.session.count, 3);
      } finally {
        for (final m in managers) {
          m.dispose();
        }
        await h.close();
      }
    },
  );
}
