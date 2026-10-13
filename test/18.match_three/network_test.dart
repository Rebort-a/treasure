import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/network/client/base/client_abstract.dart';
import 'package:treasure/00.common/network/client/net_multi_turn_engine.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/18.match_three/middle/net_manager.dart';
import 'package:treasure/18.match_three/base/match_board.dart';

import '../00.common/network/support/match_game_driver.dart';
import '../00.common/network/support/network_room_harness.dart';

/// 故意丢一份 ready 和一份动作请求，验证应用层屏障与传输重发共同工作。
class _DropOnceTransport implements ClientTransport {
  bool droppedReady = false;
  bool droppedAction = false;
  int actionAttempts = 0;

  @override
  Future<ClientConnection> connect(String host, int port) async =>
      _DropOnceConnection(
        await createClientTransport().connect(host, port),
        this,
      );
}

class _DropOnceConnection implements ClientConnection {
  final ClientConnection inner;
  final _DropOnceTransport owner;

  _DropOnceConnection(this.inner, this.owner);

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
        jsonDecode(jsonDecode(message!.content)['data'] as String)['phase'] ==
            'ready' &&
        !owner.droppedReady) {
      owner.droppedReady = true;
      return;
    }
    if (message?.type == MessageType.action) {
      owner.actionAttempts++;
      if (!owner.droppedAction) {
        owner.droppedAction = true;
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

NetMatchManager _start(SocketClient room) {
  final manager = NetMatchManager(room: room)..reduceMotion = true;
  startGame(manager.turnEngine);
  return manager;
}

Future<void> _synced(
  List<NetMatchManager> games, {
  int? moves,
  int? players,
}) => waitFor(
  () => games.every(
    (game) =>
        game.turnEngine.synchronized.value &&
        (moves == null || game.board?.moveNumber == moves) &&
        (players == null || game.turnEngine.participants.length == players),
  ),
  label: () => games
      .map(
        (g) =>
            '${g.turnEngine.identity}: rev=${g.turnEngine.revision.value} sync=${g.turnEngine.synchronized.value} players=${g.turnEngine.participants.keys} board=${g.board?.moveNumber}',
      )
      .join('; '),
);

void _sameBoards(List<NetMatchManager> games) {
  final reference = jsonEncode(games.first.board!.toJson());
  for (final game in games) {
    expect(jsonEncode(game.board!.toJson()), reference);
    expect(game.playerScores.value, games.first.playerScores.value);
    expect(game.turnEngine.gameId, games.first.turnEngine.gameId);
    expect(
      game.turnEngine.currentPlayer.value,
      games.first.turnEngine.currentPlayer.value,
    );
  }
}

void main() {
  test('个人贡献快照校验、同分排名、旧快照兼容和新局清空', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await h.server.start();
    try {
      games.add(_start(await h.join('A')));
      games.add(_start(await h.join('B')));
      await _synced(games, players: 2);
      final first = games.first;
      final a = first.turnEngine.identity;
      final b = games.last.turnEngine.identity;
      final data = first.saveState()
        ..['score'] = 600
        ..['playerScores'] = {'$a': 200, '$b': 200, '99': 200};
      for (final game in games) {
        game.loadState(data);
        expect(game.personalScore, 200);
        expect(game.personalRank, 1);
      }
      _sameBoards(games);
      final saved = Map.of(first.playerScores.value);
      for (final invalid in <Object>[
        [],
        {'bad': 1},
        {'0': 1},
        {'2147483648': 1},
        {'$a': -1},
        {'$a': 1.5},
        {'$a': 10000001},
        {'$a': 601},
        {'$a': 1, '0$a': 1},
        {for (var id = 1; id <= 1001; id++) '$id': 0},
      ]) {
        expect(
          () => first.loadState({...data, 'playerScores': invalid}),
          throwsFormatException,
        );
        expect(first.playerScores.value, saved);
      }
      first.loadState({
        ...data,
        'playerScores': {'$a': 100, '$b': 250, '99': 250},
      });
      expect(first.personalRank, 3);
      final legacy = Map<String, dynamic>.of(data)..remove('playerScores');
      first.loadState(legacy);
      expect(first.personalScore, 0);
      first.loadState(data);
      first.bonusTime.value = true;
      expect(first.showPersonalScore.value, isTrue);
      first.resetNetworkRound();
      expect(first.playerScores.value, isEmpty);
      expect(first.showPersonalScore.value, isFalse);
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });

  test('匹配、轮转和提醒不依赖 ID，只有发布者退出才按最小 ID 接管', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await h.server.start();
    try {
      final low = await h.join('Low');
      final middle = await h.join('Middle');
      final high = await h.join('High');
      final first = _start(high);
      games.add(first);
      await waitFor(
        () => first.turnEngine.matchPhase.value == RoomMatchPhase.matching,
      );
      final second = _start(middle);
      games.add(second);
      await _synced(games, players: 2);
      final third = _start(low);
      games.add(third);
      await _synced(games, players: 3);
      expect(
        games.every(
          (g) =>
              g.turnEngine.publisherId == high.identity &&
              g.turnEngine.currentPlayer.value == high.identity,
        ),
        isTrue,
      );

      final before = jsonEncode(first.board!.toJson());
      second.selectCell(0);
      await waitFor(() => games.every((g) => g.hint.value == 0));
      // 相邻的第二次点击只移动提醒，不会被解释成交换。
      second.selectCell(1);
      await waitFor(() => games.every((g) => g.hint.value == 1));
      third.selectCell(7);
      await waitFor(() => games.every((g) => g.hint.value == 7));
      expect(games.every((g) => g.selected.value == null), isTrue);
      expect(first.turnEngine.submitHint({'cell': 8}), isFalse);
      second.swap(0, 1);
      second.selectCell(-1);
      second.selectCell(64);
      expect(jsonEncode(first.board!.toJson()), before);
      expect(games.every((g) => g.hint.value == 7), isTrue);

      // 当前操作者的选中、改选和取消同步给全员，但不产生棋盘动作。
      first.selectCell(0);
      await waitFor(() => games.every((g) => g.selected.value == 0));
      first.selectCell(7);
      await waitFor(() => games.every((g) => g.selected.value == 7));
      first.selectCell(7);
      await waitFor(() => games.every((g) => g.selected.value == null));
      expect(jsonEncode(first.board!.toJson()), before);
      expect(second.turnEngine.submitSelection({'cell': 5}), isFalse);
      second.turnEngine.sendGameMessage(
        MessageType.sync,
        jsonEncode({
          'phase': 'selection',
          'revision': second.turnEngine.revision.value,
          'data': {'cell': 5},
        }),
      );
      for (final cell in [-1, MatchBoard.cells, 'bad']) {
        first.turnEngine.sendGameMessage(
          MessageType.sync,
          jsonEncode({
            'phase': 'selection',
            'revision': first.turnEngine.revision.value,
            'data': {'cell': cell},
          }),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(games.every((g) => g.selected.value == null), isTrue);

      final swap = first.board!.legalMoves.first;
      first.selectCell(swap.$1);
      await waitFor(() => games.every((g) => g.selected.value == swap.$1));
      first.selectCell(swap.$2);
      await _synced(games, moves: 1);
      expect(
        games.every(
          (g) =>
              g.turnEngine.currentPlayer.value == middle.identity &&
              g.hint.value == null &&
              g.selected.value == null,
        ),
        isTrue,
      );
      // 迟到提醒不能落到下一步棋盘上。
      third.turnEngine.sendGameMessage(
        MessageType.sync,
        jsonEncode({
          'phase': 'hint',
          'revision': third.turnEngine.revision.value - 1,
          'data': {'cell': 9},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(games.every((g) => g.hint.value == null), isTrue);
      second.turnEngine.sendGameMessage(
        MessageType.sync,
        jsonEncode({
          'phase': 'selection',
          'revision': second.turnEngine.revision.value - 1,
          'data': {'cell': 9},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(games.every((g) => g.selected.value == null), isTrue);

      // 当前行动者退出，按入局顺序交给后继，不触发发布者竞选。
      second.turnEngine.leavePage();
      await _synced([first, third], players: 2);
      expect(
        [first, third].every(
          (g) =>
              g.turnEngine.publisherId == high.identity &&
              g.turnEngine.currentPlayer.value == low.identity,
        ),
        isTrue,
      );
      first.turnEngine.leavePage();
      await _synced([third], players: 1);
      expect(third.turnEngine.publisherId, low.identity);
      expect(third.board!.moveNumber, 1);
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });

  test('六人同时准备进入同一个合作局，而不是被拆成多个双人局', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await h.server.start();
    try {
      final rooms = <SocketClient>[];
      for (var i = 0; i < 6; i++) {
        rooms.add(await h.join('Player $i'));
      }
      for (final room in rooms) {
        games.add(_start(room));
      }
      await _synced(games, players: 6);
      _sameBoards(games);
      final swap = games.first.board!.legalMoves.first;
      games.first.swap(swap.$1, swap.$2);
      await _synced(games, moves: 1, players: 6);
      _sameBoards(games);
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });

  test('ready 与动作首次丢失后可靠重发，整步仍只结算一次', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    final transport = _DropOnceTransport();
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join(
        'B',
        transport: transport,
        gameAckTimeout: const Duration(milliseconds: 20),
      );
      games.add(_start(a));
      games.add(_start(b));
      await _synced(games, players: 2);
      expect(transport.droppedReady, isTrue);
      // 发布者自己的回环不需要网络 ACK；先由 A 正常走一步，再丢 B 发给发布者的请求。
      final first = games.firstWhere((g) => g.turnEngine.canAct);
      final firstSwap = first.board!.legalMoves.first;
      first.swap(firstSwap.$1, firstSwap.$2);
      await _synced(games, moves: 1);
      final actor = games.firstWhere((g) => g.turnEngine.canAct);
      expect(actor.turnEngine.identity, b.identity);
      final swap = actor.board!.legalMoves.first;
      actor.swap(swap.$1, swap.$2);
      await _synced(games, moves: 2);
      expect(transport.droppedAction, isTrue);
      expect(transport.actionAttempts, greaterThanOrEqualTo(2));
      _sameBoards(games);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(games.first.board!.moveNumber, 2);
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });

  test('四人共享棋盘，一人一步，中途加入不重置，非法/重复动作不推进', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await h.server.start();
    try {
      final rooms = <SocketClient>[];
      for (final name in ['A', 'B', 'C', 'D', 'Spectator']) {
        rooms.add(await h.join(name));
      }
      games.add(_start(rooms[0]));
      games.add(_start(rooms[1]));
      await _synced(games, players: 2);
      final initialSeed = games.first.board!.seed;
      games.add(_start(rooms[2]));
      await _synced(games, players: 3);
      games.add(_start(rooms[3]));
      await _synced(games, players: 4);
      _sameBoards(games);
      expect(games.first.board!.seed, initialSeed);
      expect(games.first.turnEngine, isA<NetMultiTurnEngine>());
      final initialActor = games.firstWhere((g) => g.turnEngine.canAct);
      expect(
        initialActor.turnEngine.submitAction({'from': 0, 'to': 7}),
        isTrue,
      );
      await waitFor(() => !initialActor.turnEngine.pendingAction.value);
      expect(games.first.board!.moveNumber, 0);
      expect(initialActor.turnEngine.canAct, isTrue);
      for (var step = 0; step < 8; step++) {
        final actorId = games.first.turnEngine.currentPlayer.value;
        final actor = games.firstWhere((g) => g.turnEngine.identity == actorId);
        final other = games.firstWhere((g) => g != actor);
        expect(other.turnEngine.submitAction({'from': 0, 'to': 1}), isFalse);
        final swap = actor.board!.legalMoves.first;
        final beforeScore = actor.board!.score;
        final previousPersonal = actor.personalScore;
        final replay = MatchBoard.fromJson(actor.board!.toJson());
        final result = replay.playSwap(swap.$1, swap.$2)!;
        final turnScore =
            result.frames
                .firstWhere(
                  (frame) => frame.phase == FramePhase.bonus,
                  orElse: () => result.frames.last,
                )
                .score -
            beforeScore;
        actor.swap(swap.$1, swap.$2);
        await _synced(games, moves: step + 1, players: 4);
        _sameBoards(games);
        expect(actor.personalScore, previousPersonal + turnScore);
        expect(
          games.first.turnEngine.currentPlayer.value,
          rooms[(step + 1) % 4].identity,
        );
      }
      final engine = games.first.turnEngine;
      final before = games.first.board!.moveNumber;
      final scoresBeforeInvalid = Map.of(games.first.playerScores.value);
      // 合法传输的迟到请求仍携带旧修订，不能在同一人的下一轮重放。
      rooms.first.sendNetworkMessage(
        MessageType.action,
        jsonEncode({
          'revision': 1,
          'data': {'from': 0, 'to': 1},
        }),
        recipientIds: {engine.publisherId!},
        gameId: engine.gameId,
      );
      final valid = games.first.board!.legalMoves.first;
      // 同一局的非当前操作者、旧对局的当前操作者均没有推进权。
      for (final (room, gameId) in [
        (rooms[1], engine.gameId),
        (rooms[0], 'old-game'),
      ]) {
        room.sendNetworkMessage(
          MessageType.action,
          jsonEncode({
            'revision': engine.revision.value,
            'data': {'from': valid.$1, 'to': valid.$2},
          }),
          recipientIds: {engine.publisherId!},
          gameId: gameId,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(games.first.board!.moveNumber, before);
      expect(games.first.playerScores.value, scoresBeforeInvalid);
      games.add(_start(await h.join('Late')));
      await _synced(games, moves: before, players: 5);
      _sameBoards(games);
      expect(games.last.personalScore, 0);
      engine.sendGameText('队伍聊天');
      rooms.last.sendNetworkMessage(MessageType.text, '房间聊天');
      await waitFor(
        () => games.every(
          (g) => g.turnEngine.gameMessageList.value.any(
            (m) => m.content == '队伍聊天',
          ),
        ),
      );
      expect(
        rooms.last.chat.messageList.value.any((m) => m.content == '队伍聊天'),
        isFalse,
      );
      expect(engine.messageList.value.any((m) => m.content == '房间聊天'), isTrue);
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });

  test('发布者离开后沿用棋盘/对局 ID，跳过离开者，剩一人仍可继续', () async {
    final h = RoomHarness(OnlineItemType.matchThree.index);
    final games = <NetMatchManager>[];
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final c = await h.join('C');
      games.add(_start(a));
      games.add(_start(b));
      await _synced(games, players: 2);
      games.add(_start(c));
      await _synced(games, players: 3);
      final first = games.first;
      final firstSwap = first.board!.legalMoves.first;
      first.swap(firstSwap.$1, firstSwap.$2);
      await _synced(games, moves: 1, players: 3);
      final contributions = Map.of(first.playerScores.value);
      final reference = jsonEncode(games.first.board!.toJson());
      final gameId = games.first.turnEngine.gameId;
      final publisher = games.first.turnEngine.publisherId!;
      final leaving = games.firstWhere(
        (g) => g.turnEngine.identity == publisher,
      );
      final remaining = games.where((g) => g != leaving).toList();
      leaving.turnEngine.leavePage();
      await _synced(remaining, players: 2);
      expect(remaining.first.turnEngine.gameId, gameId);
      expect(jsonEncode(remaining.first.board!.toJson()), reference);
      expect(remaining.first.turnEngine.publisherId, isNot(publisher));
      _sameBoards(remaining);
      expect(remaining.first.playerScores.value, contributions);
      final current = remaining.first.turnEngine.currentPlayer.value;
      final secondLeaving = remaining.firstWhere(
        (g) => g.turnEngine.identity == current,
      );
      final survivor = remaining.firstWhere((g) => g != secondLeaving);
      await h.rooms.firstWhere((room) => room.identity == current).close();
      await _synced([survivor], players: 1);
      final swap = survivor.board!.legalMoves.first;
      survivor.swap(swap.$1, swap.$2);
      await _synced([survivor], moves: 2, players: 1);
      expect(
        survivor.turnEngine.currentPlayer.value,
        survivor.turnEngine.identity,
      );
    } finally {
      for (final game in games) {
        game.dispose();
      }
      await h.close();
    }
  });
}
