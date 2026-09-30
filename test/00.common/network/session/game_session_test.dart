import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/session/game_session.dart';
import 'package:treasure/00.common/network/session/turn_game_session.dart';
import 'package:treasure/00.common/network/session/real_game_session.dart';
import 'package:treasure/00.common/network/engine/network_engine.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/06.greedy_snake/net_manager.dart' as snake;
import 'package:treasure/17.tank/net_manager.dart' as tank;

import '../support/network_room_harness.dart';
import '../support/match_game_driver.dart';

TurnGameSession turn(
  NetworkEngine room, {
  TurnResourceMode mode = TurnResourceMode.none,
  void Function()? search,
  void Function(GameStep, NetworkMessage)? resource,
  void Function(bool, NetworkMessage)? action,
}) => TurnGameSession(
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
      final games = <GameSession>[];
      await h.server.start();
      try {
        final aRoom = await h.join('Alice');
        final bRoom = await h.join('Bob');
        final cRoom = await h.join('Carol');
        final dRoom = await h.join('Dan');
        final ids = h.rooms.map((r) => r.identity).toList();
        final a = turn(aRoom);
        games.add(a);
        startGame(a);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(a.gameStep.value, GameStep.start);
        expect(a.readyToOpen.value, isFalse);
        final b = turn(bRoom);
        games.add(b);
        startGame(b);
        await waitFor(() => a.readyToOpen.value && b.readyToOpen.value);
        expect(a.playerType, TurnGamerType.front);
        expect(b.playerType, TurnGamerType.rear);
        expect(a.gameStep.value, GameStep.action);
        final c = turn(cRoom);
        games.add(c);
        startGame(c);
        final d = turn(dRoom);
        games.add(d);
        startGame(d);
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
        expect(h.server.members.length, 4);
        a.finish();
        await waitFor(() => b.ended.value);
        expect(h.rooms.map((r) => r.identity).toList(), ids);
        expect(h.server.members.length, 4);
        expect(c.ended.value, isFalse);
        final retryA = turn(aRoom);
        games.add(retryA);
        startGame(retryA);
        final retryB = turn(bRoom);
        games.add(retryB);
        startGame(retryB);
        await waitFor(
          () => retryA.readyToOpen.value && retryB.readyToOpen.value,
        );
        aRoom.sendNetworkMessage(
          MessageType.exit,
          'late old exit',
          recipientIds: {bRoom.identity},
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
      TurnGameSession? a;
      TurnGameSession? b;
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
        startGame(a);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        startGame(b);
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

  test('取消后重新匹配不创建房间连接', () async {
    final h = RoomHarness(3);
    await h.server.start();
    TurnGameSession? old;
    TurnGameSession? current;
    TurnGameSession? b;
    try {
      final ra = await h.join('A');
      final rb = await h.join('B');
      old = startGame(turn(ra));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      old.cancelMatch();
      current = startGame(turn(ra));
      b = startGame(turn(rb));
      await waitFor(() => current!.readyToOpen.value && b!.readyToOpen.value);
      expect(old.ended.value, isTrue);
      expect(h.server.members.length, 2);
    } finally {
      old?.dispose();
      current?.dispose();
      b?.dispose();
      await h.close();
    }
  });

  test('实时确认后进入页面，必须等所有 sync 才开始行动', () async {
    final h = RoomHarness(6);
    await h.server.start();
    final games = <RealGameSession>[];
    final syncs = <int, Set<int>>{};
    final resources = <int>{};
    try {
      final ra = await h.join('A');
      final rb = await h.join('B');
      RealGameSession create(NetworkEngine room) {
        late RealGameSession engine;
        engine = RealGameSession(
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

      final a = startGame(create(ra));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final b = startGame(create(rb));
      await waitFor(() => resources.length == 2);
      expect(a.gameStep.value, GameStep.synchronizing);
      expect(b.gameStep.value, GameStep.synchronizing);
      a.sendNetworkMessage(MessageType.sync, 'ready');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(a.gameStep.value, GameStep.synchronizing);
      b.sendNetworkMessage(MessageType.sync, 'ready');
      await waitFor(
        () =>
            a.gameStep.value == GameStep.action &&
            b.gameStep.value == GameStep.action,
      );
    } finally {
      for (final e in games) {
        e.dispose();
      }
      await h.close();
    }
  });

  test('贪吃蛇资源在服务器回环前不写入本地游戏状态', () async {
    final h = RoomHarness(4);
    await h.server.start();
    snake.NetManager? a;
    snake.NetManager? b;
    try {
      final ra = await h.join('A');
      final rb = await h.join('B');
      a = snake.NetManager(room: ra);
      b = snake.NetManager(room: rb);
      b.realSession.startMatched(
        opponentId: ra.identity,
        publisherId: ra.identity,
        isPublisher: false,
      );
      a.realSession.startMatched(
        opponentId: rb.identity,
        publisherId: ra.identity,
        isPublisher: true,
      );
      expect(a.snakes, isEmpty);
      expect(b.snakes, isEmpty);
      await waitFor(
        () =>
            a!.realSession.gameStep.value == GameStep.action &&
            b!.realSession.gameStep.value == GameStep.action,
      );
      expect(a.snakes.keys, {ra.identity, rb.identity});
    } finally {
      a?.dispose();
      b?.dispose();
      await h.close();
    }
  });

  test('坦克资源在服务器回环前不写入本地游戏状态', () async {
    final h = RoomHarness(6);
    await h.server.start();
    tank.NetTankManager? a;
    tank.NetTankManager? b;
    try {
      final ra = await h.join('A');
      final rb = await h.join('B');
      a = tank.NetTankManager(room: ra);
      b = tank.NetTankManager(room: rb);
      b.realSession.startMatched(
        opponentId: ra.identity,
        publisherId: ra.identity,
        isPublisher: false,
      );
      a.realSession.startMatched(
        opponentId: rb.identity,
        publisherId: ra.identity,
        isPublisher: true,
      );
      expect(a.tanks, isEmpty);
      expect(b.tanks, isEmpty);
      await waitFor(
        () =>
            a!.realSession.gameStep.value == GameStep.action &&
            b!.realSession.gameStep.value == GameStep.action,
      );
      expect(a.tanks.keys.where((id) => id > 0), {ra.identity, rb.identity});
    } finally {
      a?.dispose();
      b?.dispose();
      await h.close();
    }
  });

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
          startGame(manager.realSession);
          if (i == 0 || i == 4) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            expect(manager.realSession.readyToOpen.value, isFalse);
          } else {
            await waitFor(
              () =>
                  manager.realSession.readyToOpen.value &&
                  manager.tanks.values.where((t) => t.isPlayer).length == i + 1,
            );
            expect(manager.tanks.values.where((t) => t.isPlayer).length, i + 1);
          }
        }
        expect(h.server.members.length, 5);
        managers[1].realSession.finish();
        managers[4].realSession.room.sendNetworkMessage(MessageType.search, '');
        await waitFor(
          () =>
              managers[4].realSession.readyToOpen.value &&
              managers[0].tanks.values.where((t) => t.isPlayer).length == 4 &&
              managers[4].tanks.values.where((t) => t.isPlayer).length == 4,
        );
        expect(managers[0].tanks.values.where((t) => t.isPlayer).length, 4);
        expect(managers[4].authorityId, managers[0].identity);
        managers[0].realSession.finish();
        await waitFor(() => managers[4].authorityId == managers[2].identity);
        expect(h.server.members.length, 5);
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
        startGame(a.realSession);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(a.snakes, isEmpty);
        expect(a.realSession.readyToOpen.value, isFalse);
        final b = snake.NetManager(room: rb);
        managers.add(b);
        startGame(b.realSession);
        await waitFor(
          () =>
              a.realSession.gameStep.value == GameStep.action &&
              b.realSession.gameStep.value == GameStep.action,
        );
        expect(a.realSession.publisherId, ra.identity);
        expect(b.realSession.publisherId, ra.identity);
        a.suspendGame();
        b.suspendGame();
        a.snakes[ra.identity]!.body.add(const Offset(10, 10));
        b.snakes[rb.identity]!.body.add(const Offset(20, 20));
        final rc = await h.join('Carol');
        final c = snake.NetManager(room: rc);
        managers.add(c);
        startGame(c.realSession);
        await waitFor(
          () =>
              c.realSession.readyToOpen.value &&
              a.snakes.length == 3 &&
              b.snakes.length == 3,
        );
        for (final manager in managers) {
          expect(manager.snakes.values.every((s) => s.body.isEmpty), isTrue);
        }
        c.realSession.finish();
        await waitFor(() => a.snakes.length == 2 && b.snakes.length == 2);
        expect(h.server.members.length, 3);
        expect(rc.identity, isNot(0));
        final rejoined = snake.NetManager(room: rc);
        managers.add(rejoined);
        startGame(rejoined.realSession);
        await waitFor(
          () => rejoined.realSession.readyToOpen.value && a.snakes.length == 3,
        );
        expect(a.snakes.length, 3);
        expect(h.server.members.length, 3);
      } finally {
        for (final m in managers) {
          m.dispose();
        }
        await h.close();
      }
    },
  );
}
