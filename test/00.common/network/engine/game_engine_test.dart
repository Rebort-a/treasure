import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/base/game_engine.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/net_real_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/06.greedy_snake/net_manager.dart' as snake;
import 'package:treasure/17.tank/net_manager.dart' as tank;
import 'package:treasure/17.tank/base.dart' as tank_model;

import '../support/network_room_harness.dart';
import '../support/match_game_driver.dart';

NetTurnEngine turn(
  SocketClient room, {
  TurnResourceMode mode = TurnResourceMode.none,
  void Function()? search,
  void Function(GameStep, NetworkMessage)? resource,
  void Function(bool, NetworkMessage)? action,
}) => configureTurnEngine(
  room: room,
  resourceMode: mode,
  searchHandler: search ?? () {},
  resourceHandler: resource ?? (_, __) {},
  actionHandler: action ?? (_, __) {},
  exitHandler: () {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('匹配在同一引擎启动对局；私聊与房间聊天共享连接但分开记录', () async {
    final h = RoomHarness(3);
    final games = <GameEngine>{};
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
      await waitFor(
        () => a.readyToOpen.value && b.readyToOpen.value,
        label: () =>
            'A/B first match: ${a.matchPhase.value} / ${b.matchPhase.value}',
      );
      expect(a.playerType, TurnGamerType.front);
      expect(b.playerType, TurnGamerType.rear);
      expect(a.gameStep.value, GameStep.action);
      expect(a.participants, {aRoom.identity: 'Alice', bRoom.identity: 'Bob'});
      expect(b.participants, a.participants);
      expect(a.enemyId, bRoom.identity);
      expect(b.enemyId, aRoom.identity);
      expect(
        () => a.participants[cRoom.identity] = 'Carol',
        throwsUnsupportedError,
      );
      final c = turn(cRoom);
      games.add(c);
      startGame(c);
      final d = turn(dRoom);
      games.add(d);
      startGame(d);
      await waitFor(
        () => c.readyToOpen.value && d.readyToOpen.value,
        label: () =>
            'C/D match: ${c.matchPhase.value} / ${d.matchPhase.value}, candidates: ${c.matchedOpponentId}, ${d.matchedOpponentId}',
      );
      a.sendGameMessage(MessageType.text, 'private');
      cRoom.sendNetworkMessage(MessageType.text, 'room message while playing');
      await waitFor(
        () =>
            b.gameMessageList.value.any((m) => m.content == 'private') &&
            aRoom.messageList.value.any(
              (m) => m.content == 'room message while playing',
            ),
      );
      expect(c.gameMessageList.value, isEmpty);
      expect(
        a.gameMessageList.value
            .firstWhere((m) => m.content == 'private')
            .recipientIds,
        {aRoom.identity, bRoom.identity},
      );
      // 显式空集合或混入房间旁观者的目标都不能从游戏接口意外公开广播。
      a.sendGameMessage(
        MessageType.text,
        'empty game targets',
        recipientIds: {},
      );
      a.sendGameMessage(
        MessageType.text,
        'foreign game target',
        recipientIds: {aRoom.identity, cRoom.identity},
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        a.gameMessageList.value.any((m) => m.content == 'empty game targets'),
        isFalse,
      );
      expect(c.gameMessageList.value, isEmpty);
      expect(
        aRoom.messageList.value.any((m) => m.content == 'private'),
        isFalse,
      );
      expect(h.server.members.length, 4);
      final firstGameId = a.gameMessageList.value
          .firstWhere((m) => m.content == 'private')
          .messageId!;
      final firstGameScope = a.gameId;
      a.finishGame();
      await waitFor(() => b.ended.value);
      expect(h.rooms.map((r) => r.identity).toList(), ids);
      expect(h.server.members.length, 4);
      expect(c.ended.value, isFalse);
      a.releaseGame();
      b.releaseGame();
      final retryA = turn(aRoom);
      games.add(retryA);
      startGame(retryA);
      final retryB = turn(bRoom);
      games.add(retryB);
      startGame(retryB);
      await waitFor(
        () => retryA.readyToOpen.value && retryB.readyToOpen.value,
        label: () =>
            'A/B rematch: ${retryA.matchPhase.value} / ${retryB.matchPhase.value}',
      );
      final oldPacketsAtB = <NetworkMessage>[];
      bRoom.addMessageListener(oldPacketsAtB.add);
      aRoom.sendNetworkMessage(
        MessageType.exit,
        'late old exit',
        recipientIds: {bRoom.identity},
        messageId: '$firstGameId-old-exit',
        gameId: firstGameScope,
      );
      aRoom.sendNetworkMessage(
        MessageType.text,
        'late old text',
        recipientIds: {bRoom.identity},
        messageId: '$firstGameId-old-text',
        gameId: firstGameScope,
      );
      await waitFor(
        () =>
            oldPacketsAtB.any((m) => m.content == 'late old exit') &&
            oldPacketsAtB.any((m) => m.content == 'late old text'),
      );
      aRoom.deliveryFailure.value = NetworkMessage(
        id: aRoom.identity,
        type: MessageType.action,
        source: 'Alice',
        content: 'old delivery failure',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        recipientIds: {bRoom.identity},
        messageId: firstGameId,
        gameId: firstGameScope,
      );
      expect(retryA.ended.value, isFalse);
      expect(retryB.ended.value, isFalse);
      expect(
        retryB.gameMessageList.value.any((m) => m.content == 'late old text'),
        isFalse,
      );
    } finally {
      for (final game in games) {
        game.releaseGame();
      }
      await h.close();
    }
  });

  for (final mode in [TurnResourceMode.frontOnly, TurnResourceMode.both]) {
    test('turn resource flow: ${mode.name}', () async {
      final h = RoomHarness(mode == TurnResourceMode.frontOnly ? 1 : 2);
      await h.server.start();
      NetTurnEngine? a;
      NetTurnEngine? b;
      final receivedA = <GameStep>[];
      final receivedB = <GameStep>[];
      try {
        final ra = await h.join('A');
        final rb = await h.join('B');
        a = turn(
          ra,
          mode: mode,
          search: () => a!.sendGameMessage(MessageType.resource, 'front'),
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
          b.sendGameMessage(MessageType.resource, 'rear');
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
        a?.releaseGame();
        b?.releaseGame();
        await h.close();
      }
    });
  }

  test('取消后重新匹配不创建房间连接', () async {
    final h = RoomHarness(3);
    await h.server.start();
    NetTurnEngine? old;
    NetTurnEngine? current;
    NetTurnEngine? b;
    try {
      final ra = await h.join('A');
      final rb = await h.join('B');
      old = startGame(turn(ra));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      old.cancelMatch();
      old.releaseGame();
      current = startGame(turn(ra));
      b = startGame(turn(rb));
      await waitFor(() => current!.readyToOpen.value && b!.readyToOpen.value);
      expect(identical(old, current), isTrue);
      expect(current.ended.value, isFalse);
      expect(h.server.members.length, 2);
    } finally {
      old?.releaseGame();
      current?.releaseGame();
      b?.releaseGame();
      await h.close();
    }
  });

  test('实时确认后进入页面，必须等所有 sync 才开始行动', () async {
    final h = RoomHarness(6);
    await h.server.start();
    final games = <NetRealEngine>[];
    final syncs = <int, Set<int>>{};
    final resources = <int>{};
    try {
      final ra = await h.join('A');
      final rb = await h.join('B');
      NetRealEngine create(SocketClient room) {
        late NetRealEngine engine;
        engine = configureRealEngine(
          room: room,
          maxPlayers: 4,
          searchHandler: (_) =>
              engine.sendGameMessage(MessageType.resource, 'state'),
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
      a.sendGameMessage(MessageType.sync, 'ready');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(a.gameStep.value, GameStep.synchronizing);
      b.sendGameMessage(MessageType.sync, 'ready');
      await waitFor(
        () =>
            a.gameStep.value == GameStep.action &&
            b.gameStep.value == GameStep.action,
      );
    } finally {
      for (final e in games) {
        e.releaseGame();
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
      b.realEngine.startMatched(
        opponentId: ra.identity,
        publisherId: ra.identity,
        isPublisher: false,
        gameId: 'direct-snake-game',
      );
      a.realEngine.startMatched(
        opponentId: rb.identity,
        publisherId: ra.identity,
        isPublisher: true,
        gameId: 'direct-snake-game',
      );
      expect(a.snakes, isEmpty);
      expect(b.snakes, isEmpty);
      await waitFor(
        () =>
            a!.realEngine.gameStep.value == GameStep.action &&
            b!.realEngine.gameStep.value == GameStep.action,
      );
      expect(a.snakes.keys, {ra.identity, rb.identity});
    } finally {
      a?.dispose();
      b?.dispose();
      await h.close();
    }
  });

  test('贪吃蛇损坏资源不污染局面或推进同步代数', () async {
    final h = RoomHarness(4);
    await h.server.start();
    snake.NetManager? manager;
    try {
      final host = await h.join('Host');
      final guest = await h.join('Guest');
      final game = manager = snake.NetManager(room: guest);
      game.realEngine.startMatched(
        opponentId: host.identity,
        publisherId: host.identity,
        isPublisher: false,
        gameId: 'snake-invalid-resource',
      );
      game.addSnake(host.identity, 10);
      game.addSnake(guest.identity, 10);
      game.addFood(const Offset(10, 10));
      final state = <String, dynamic>{
        'snakes': game.snakes.map((k, v) => MapEntry('$k', v.toJson())),
        'foods': game.foodGrid.toJson(),
      };
      void resource(int syncId, Map<String, dynamic> value) {
        game.realEngine.handleGameMessage(
          NetworkMessage(
            id: host.identity,
            source: 'test',
            gameId: game.realEngine.gameId,
            recipientIds: {host.identity, guest.identity},
            timestamp: 0,
            type: MessageType.resource,
            content: jsonEncode({
              'players': [host.identity, guest.identity],
              'revision': 1,
              'admissions': <String, String>{},
              'data': jsonEncode({'syncId': syncId, 'state': value}),
            }),
          ),
        );
      }

      resource(1, state);
      final previousSnakes = Map.of(game.snakes);
      final previousFoods = game.foodGrid.toJson();
      for (final broken in [
        {
          ...state,
          'snakes': {
            '${host.identity}': game.snakes[host.identity]!.toJson(),
            'bad-id': {},
          },
        },
        {
          ...state,
          'foods': {
            'entries': [
              {
                'position': {'dx': 1, 'dy': 2},
                'radius': 2,
              },
              {},
            ],
          },
        },
      ]) {
        resource(99, broken);
        expect(game.snakes, previousSnakes);
        expect(game.foodGrid.toJson(), previousFoods);
      }
      for (final id in [host.identity, guest.identity]) {
        game.realEngine.handleGameMessage(
          NetworkMessage(
            id: id,
            source: 'test',
            gameId: game.realEngine.gameId,
            recipientIds: {host.identity, guest.identity},
            timestamp: 0,
            type: MessageType.sync,
            content: jsonEncode({'syncId': 1}),
          ),
        );
      }
      expect(game.realEngine.gameStep.value, GameStep.action);
      game.realEngine.handleGameMessage(
        NetworkMessage(
          id: host.identity,
          source: 'test',
          gameId: game.realEngine.gameId,
          recipientIds: {host.identity, guest.identity},
          timestamp: 0,
          type: MessageType.action,
          content: jsonEncode({
            'syncId': 1,
            'actionType': 'joystick',
            'angle': 0.75,
          }),
        ),
      );
      expect(game.snakes[host.identity]!.angle, 0.75);
      expect(game.gameState.value, isTrue);
      resource(100, {
        ...state,
        'foods': {
          'entries': [null],
        },
      });
      expect(game.gameState.value, isTrue);
      expect(game.snakes, previousSnakes);
    } finally {
      manager?.dispose();
      await h.close();
    }
  });

  test('坦克损坏资源保留世界、待确认事件和原同步屏障', () async {
    final h = RoomHarness(6);
    await h.server.start();
    tank.NetTankManager? manager;
    try {
      final host = await h.join('Host');
      final guest = await h.join('Guest');
      final game = manager = tank.NetTankManager(room: guest);
      game.realEngine.startMatched(
        opponentId: host.identity,
        publisherId: host.identity,
        isPublisher: false,
        gameId: 'tank-invalid-resource',
      );
      game.addPlayerTank(host.identity);
      game.addPlayerTank(guest.identity);
      void resource(int match, int sync, Map<String, dynamic> state) {
        game.realEngine.handleGameMessage(
          NetworkMessage(
            id: host.identity,
            source: 'test',
            gameId: game.realEngine.gameId,
            recipientIds: {host.identity, guest.identity},
            timestamp: 0,
            type: MessageType.resource,
            content: jsonEncode({
              'players': [host.identity, guest.identity],
              'revision': 1,
              'admissions': <String, String>{},
              'data': jsonEncode({
                'match': match,
                'sync': sync,
                'state': state,
              }),
            }),
          ),
        );
      }

      resource(1, 1, game.toJson());
      final enemy = tank_model.Tank.enemy(
        position: const Offset(20, 20),
        type: tank_model.EnemyType.basic,
      );
      game.broadcastSpawn(-1, enemy);
      final before = game.toJson();
      final player = game.tanks[guest.identity];
      resource(99, 99, {...before, 'itemSpawnTimer': 'bad'});
      expect(game.toJson(), before);
      expect(game.tanks[guest.identity], same(player));
      expect(game.pendingEnemySpawnCount, 1);
      for (final id in [host.identity, guest.identity]) {
        game.realEngine.handleGameMessage(
          NetworkMessage(
            id: id,
            source: 'test',
            gameId: game.realEngine.gameId,
            recipientIds: {host.identity, guest.identity},
            timestamp: 0,
            type: MessageType.sync,
            content: jsonEncode({'match': 1, 'sync': 1}),
          ),
        );
      }
      expect(game.realEngine.gameStep.value, GameStep.action);
      game.realEngine.handleGameMessage(
        NetworkMessage(
          id: host.identity,
          source: 'test',
          gameId: game.realEngine.gameId,
          recipientIds: {host.identity, guest.identity},
          timestamp: 0,
          type: MessageType.action,
          content: jsonEncode({
            'match': 1,
            'sync': 1,
            'actionType': 'spawn',
            'key': -1,
            'tank': enemy.toJson(),
          }),
        ),
      );
      expect(game.tanks[-1]?.enemyType, tank_model.EnemyType.basic);
      expect(game.pendingEnemySpawnCount, 0);
      expect(game.isRunning.value, isTrue);
      resource(100, 100, {...before, 'score': 'bad'});
      expect(game.isRunning.value, isTrue);
      expect(game.tanks[-1]?.enemyType, tank_model.EnemyType.basic);
      resource(1, 2, before);
      expect(game.tanks[-1], isNull);
    } finally {
      manager?.dispose();
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
      b.realEngine.startMatched(
        opponentId: ra.identity,
        publisherId: ra.identity,
        isPublisher: false,
        gameId: 'direct-tank-game',
      );
      a.realEngine.startMatched(
        opponentId: rb.identity,
        publisherId: ra.identity,
        isPublisher: true,
        gameId: 'direct-tank-game',
      );
      expect(a.tanks, isEmpty);
      expect(b.tanks, isEmpty);
      await waitFor(
        () =>
            a!.realEngine.gameStep.value == GameStep.action &&
            b!.realEngine.gameStep.value == GameStep.action,
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
          startGame(manager.realEngine);
          if (i == 0 || i == 4) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            expect(manager.realEngine.readyToOpen.value, isFalse);
          } else {
            await waitFor(
              () =>
                  manager.realEngine.readyToOpen.value &&
                  manager.tanks.values.where((t) => t.isPlayer).length == i + 1,
            );
            expect(manager.tanks.values.where((t) => t.isPlayer).length, i + 1);
          }
        }
        expect(h.server.members.length, 5);
        managers[1].realEngine.finishGame();
        managers[4].realEngine.client.sendNetworkMessage(
          MessageType.search,
          '',
        );
        await waitFor(
          () =>
              managers[4].realEngine.readyToOpen.value &&
              managers[0].tanks.values.where((t) => t.isPlayer).length == 4 &&
              managers[4].tanks.values.where((t) => t.isPlayer).length == 4,
        );
        expect(managers[0].tanks.values.where((t) => t.isPlayer).length, 4);
        expect(managers[4].authorityId, managers[0].identity);
        managers[0].realEngine.finishGame();
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
        startGame(a.realEngine);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(a.snakes, isEmpty);
        expect(a.realEngine.readyToOpen.value, isFalse);
        final b = snake.NetManager(room: rb);
        managers.add(b);
        startGame(b.realEngine);
        await waitFor(
          () =>
              a.realEngine.gameStep.value == GameStep.action &&
              b.realEngine.gameStep.value == GameStep.action,
        );
        expect(a.realEngine.publisherId, ra.identity);
        expect(b.realEngine.publisherId, ra.identity);
        a.suspendGame();
        b.suspendGame();
        a.snakes[ra.identity]!.body.add(const Offset(10, 10));
        b.snakes[rb.identity]!.body.add(const Offset(20, 20));
        final rc = await h.join('Carol');
        final c = snake.NetManager(room: rc);
        managers.add(c);
        startGame(c.realEngine);
        await waitFor(
          () =>
              c.realEngine.readyToOpen.value &&
              a.snakes.length == 3 &&
              b.snakes.length == 3,
        );
        for (final manager in managers) {
          expect(manager.snakes.values.every((s) => s.body.isEmpty), isTrue);
        }
        c.realEngine.finishGame();
        await waitFor(() => a.snakes.length == 2 && b.snakes.length == 2);
        expect(h.server.members.length, 3);
        expect(rc.identity, isNot(0));
        managers.remove(c);
        c.dispose();
        final rejoined = snake.NetManager(room: rc);
        managers.add(rejoined);
        startGame(rejoined.realEngine);
        await waitFor(
          () => rejoined.realEngine.readyToOpen.value && a.snakes.length == 3,
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
