import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/base/client_abstract.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/03.animal_chess/net_manager.dart' as animal;
import 'package:treasure/04.elemental_battle/upper/net_combat_manager.dart';
import 'package:treasure/04.elemental_battle/middle/elemental.dart';
import 'package:treasure/05.gobang/net_manager.dart' as gomoku;
import 'package:treasure/07.weiqi/net_manager.dart' as go;
import 'package:treasure/18.match_three/middle/net_manager.dart';

import 'support/match_game_driver.dart';
import 'support/network_room_harness.dart';

class _DropReplayTransport implements ClientTransport {
  final dropped = <String>{};

  @override
  Future<ClientConnection> connect(String host, int port) async =>
      _DropReplayConnection(
        await createClientTransport().connect(host, port),
        this,
      );
}

class _DropReplayConnection implements ClientConnection {
  final ClientConnection inner;
  final _DropReplayTransport owner;
  _DropReplayConnection(this.inner, this.owner);

  @override
  void listen({
    required ClientDataCallback onData,
    required ClientDoneCallback onDone,
    required ClientErrorCallback onError,
  }) => inner.listen(onData: onData, onDone: onDone, onError: onError);

  @override
  void send(List<int> data) {
    final message =
        NetworkMessage.fromPlainSocketData(data) ??
        NetworkMessage.fromSocketData(data, encryptionKey: 'test-key');
    if (message?.type == MessageType.sync &&
        message!.content.startsWith('@round-replay:')) {
      final phase =
          jsonDecode(
                message.content.substring('@round-replay:'.length),
              )['phase']
              as String;
      if (const {'ready', 'prepare', 'ack', 'begin'}.contains(phase) &&
          owner.dropped.add(phase)) {
        return;
      }
    }
    inner.send(data);
  }

  @override
  Future<void> flush() => inner.flush();

  @override
  Future<void> close() => inner.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final type in [
    OnlineItemType.animalChess,
    OnlineItemType.gobang,
    OnlineItemType.weiqi,
    OnlineItemType.elementalBattle,
  ]) {
    test('${type.name} 投降后原会话重开，保留聊天且不重新搜索', () async {
      final h = RoomHarness(type.index);
      final engines = <NetTurnEngine>[];
      final drops = type == OnlineItemType.gobang
          ? _DropReplayTransport()
          : null;
      final dispose = <void Function()>[];
      await h.server.start();
      try {
        for (final name in ['Alice', 'Bob']) {
          final room = await h.join(
            name,
            transport: name == 'Alice' ? drops : null,
          );
          switch (type) {
            case OnlineItemType.animalChess:
              final manager = animal.NetManager(room: room);
              engines.add(manager.turnEngine);
              dispose.add(manager.dispose);
            case OnlineItemType.gobang:
              final manager = gomoku.NetManager(room: room);
              engines.add(manager.turnEngine);
              dispose.add(manager.dispose);
            case OnlineItemType.weiqi:
              final manager = go.GoNetManager(room: room);
              engines.add(manager.turnEngine);
              dispose.add(manager.dispose);
            case OnlineItemType.elementalBattle:
              final manager = NetCombatManager(room: room);
              engines.add(manager.turnEngine);
              dispose.add(manager.dispose);
            default:
              throw StateError('Unexpected game');
          }
        }
        for (final engine in engines) {
          startGame(engine);
        }
        await waitFor(() => engines.every((e) => e.isActive));
        Future<void> configureCombat() async {
          if (type != OnlineItemType.elementalBattle) return;
          for (final step in [GameStep.frontConfig, GameStep.rearConfig]) {
            await waitFor(() => engines.any((e) => e.gameStep.value == step));
            final engine = engines.firstWhere((e) => e.gameStep.value == step);
            engine.sendGameMessage(
              MessageType.resource,
              Elemental.configToJsonString(
                engine.userName,
                EnergyConfigs.defaultConfigs(healthPoints: 10),
                0,
              ),
            );
          }
        }

        await configureCombat();
        await waitFor(
          () => engines.every((e) => e.gameStep.value == GameStep.action),
        );
        final session = engines.first.gameId;
        engines.first.sendGameText('keep history');
        await waitFor(
          () => engines.every((e) => e.gameMessageList.length == 1),
        );
        var searches = 0;
        h.rooms.first.addMessageListener((m) {
          if (m.type == MessageType.search) searches++;
        });
        for (var round = 1; round <= 2; round++) {
          engines.first.completeRound();
          await waitFor(
            () => engines.every((e) => e.roundReplay!.finished.value),
          );
          expect(engines.every((e) => !e.ended.value), isTrue);
          engines.first.requestReplay();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(engines.first.roundReplay!.waiting.value, isTrue);
          expect(engines.last.roundReplay!.finished.value, isTrue);
          engines.last.requestReplay();
          await waitFor(
            () => engines.every((e) => e.roundReplay!.round == round),
          );
          await configureCombat();
          await waitFor(
            () => engines.every((e) => e.gameStep.value == GameStep.action),
          );
          expect(engines.every((e) => !e.roundReplay!.finished.value), isTrue);
          expect(engines.every((e) => e.gameId == session), isTrue);
          expect(
            engines.every(
              (e) => e.gameMessageList.single.content == 'keep history',
            ),
            isTrue,
          );
        }
        expect(searches, 0);
        if (drops != null) {
          expect(
            drops.dropped,
            containsAll(['ready', 'prepare', 'ack', 'begin']),
          );
        }
      } finally {
        for (final release in dispose) {
          release();
        }
        await h.close();
      }
    });
  }

  test('三消先准备的两人重开，原发布者迟到加入时不重置当前棋盘', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await h.server.start();
    try {
      for (final name in ['Alice', 'Bob', 'Carol']) {
        final room = await h.join(name);
        final manager = NetMatchManager(room: room)..reduceMotion = true;
        games.add(manager);
        startGame(manager.turnEngine);
      }
      await waitFor(
        () => games.every(
          (g) =>
              g.turnEngine.synchronized.value &&
              g.turnEngine.participants.length == 3,
        ),
      );
      final session = games.first.turnEngine.gameId;
      games.first.turnEngine.sendGameText('old chat');
      await waitFor(
        () => games.every((g) => g.turnEngine.gameMessageList.length == 1),
      );
      games.first.turnEngine.completeRound();
      await waitFor(
        () => games.every((g) => g.turnEngine.roundReplay!.finished.value),
      );
      // 原发布者不参加准备；另外两人仍能独立开启新局。
      games[1].turnEngine.requestReplay();
      games[2].turnEngine.requestReplay();
      await waitFor(
        () => games
            .skip(1)
            .every(
              (g) =>
                  g.turnEngine.roundReplay!.round == 1 &&
                  g.turnEngine.synchronized.value &&
                  g.turnEngine.participants.length == 2,
            ),
      );
      expect(games.first.turnEngine.roundReplay!.finished.value, isTrue);
      expect(games.first.canInteract, isFalse);
      final publisher = games[1];
      final move = publisher.board!.legalMoves.first;
      publisher.swap(move.$1, move.$2);
      await waitFor(
        () => games
            .skip(1)
            .every(
              (g) =>
                  g.board!.moveNumber == 1 && g.turnEngine.synchronized.value,
            ),
      );
      final state = jsonEncode(publisher.board!.toJson());
      games.first.turnEngine.requestReplay();
      await waitFor(
        () => games.every(
          (g) =>
              g.turnEngine.synchronized.value &&
              !g.turnEngine.roundReplay!.finished.value &&
              g.turnEngine.participants.length == 3,
        ),
      );
      expect(
        games.every((g) => jsonEncode(g.board!.toJson()) == state),
        isTrue,
      );
      expect(games.every((g) => g.turnEngine.gameId == session), isTrue);
      expect(
        games.every(
          (g) => g.turnEngine.gameMessageList.single.content == 'old chat',
        ),
        isTrue,
      );
      // 旧轮次的可靠重发即使会话 ID 相同也不能再次推进棋盘。
      h.rooms[1].sendNetworkMessage(
        MessageType.action,
        jsonEncode({
          'round': 0,
          'version': 0,
          'data': jsonEncode({
            'revision': 1,
            'data': {'from': move.$1, 'to': move.$2},
          }),
        }),
        recipientIds: games.first.turnEngine.participants.keys.toSet(),
        gameId: session,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        games.every((g) => jsonEncode(g.board!.toJson()) == state),
        isTrue,
      );
      final newcomer = NetMatchManager(room: await h.join('Dana'))
        ..reduceMotion = true;
      games.add(newcomer);
      startGame(newcomer.turnEngine);
      await waitFor(
        () => games.every(
          (g) =>
              g.turnEngine.synchronized.value &&
              g.turnEngine.participants.length == 4 &&
              g.turnEngine.roundReplay!.members.length == 4,
        ),
      );
      expect(
        games.every((g) => jsonEncode(g.board!.toJson()) == state),
        isTrue,
      );
      publisher.turnEngine.completeRound();
      await waitFor(
        () => games.every((g) => g.turnEngine.roundReplay!.finished.value),
      );
      games.first.turnEngine.requestReplay();
      newcomer.turnEngine.requestReplay();
      await waitFor(
        () => [games.first, newcomer].every(
          (g) =>
              g.turnEngine.roundReplay!.round == 2 &&
              g.turnEngine.synchronized.value &&
              g.turnEngine.participants.length == 2,
        ),
      );
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });

  test('六人同时准备可汇合到同一新局，协调者等待期间退出不阻塞其他玩家', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await h.server.start();
    try {
      for (var i = 0; i < 6; i++) {
        final manager = NetMatchManager(room: await h.join('Player $i'))
          ..reduceMotion = true;
        games.add(manager);
        startGame(manager.turnEngine);
      }
      await waitFor(
        () => games.every(
          (g) =>
              g.turnEngine.synchronized.value &&
              g.turnEngine.participants.length == 6,
        ),
      );
      games.first.turnEngine.completeRound();
      await waitFor(
        () => games.every((g) => g.turnEngine.roundReplay!.finished.value),
      );
      for (final game in games) {
        game.turnEngine.requestReplay();
      }
      await waitFor(
        () => games.every(
          (g) =>
              g.turnEngine.roundReplay!.round == 1 &&
              g.turnEngine.synchronized.value &&
              g.turnEngine.participants.length == 6,
        ),
      );
      final state = jsonEncode(games.first.board!.toJson());
      expect(
        games.every((g) => jsonEncode(g.board!.toJson()) == state),
        isTrue,
      );
      games.first.turnEngine.completeRound();
      await waitFor(
        () => games.every((g) => g.turnEngine.roundReplay!.finished.value),
      );
      games[1].turnEngine.requestReplay();
      games.first.turnEngine.leavePage();
      await waitFor(
        () => games
            .skip(1)
            .every(
              (g) => !g.turnEngine.roundReplay!.members.containsKey(
                games.first.turnEngine.identity,
              ),
            ),
      );
      games[2].turnEngine.requestReplay();
      await waitFor(
        () => games
            .skip(1)
            .take(2)
            .every(
              (g) =>
                  g.turnEngine.roundReplay!.round == 2 &&
                  g.turnEngine.synchronized.value &&
                  g.turnEngine.participants.length == 2,
            ),
      );
      expect(
        games.skip(3).every((g) => g.turnEngine.roundReplay!.finished.value),
        isTrue,
      );
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });
}
