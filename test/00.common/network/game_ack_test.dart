import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/base/client_abstract.dart';
import 'package:treasure/00.common/network/client/net_real_engine.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/game/step.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';

import 'support/match_game_driver.dart';
import 'support/network_room_harness.dart';

class _InspectTransport implements ClientTransport {
  final bool Function(NetworkMessage message) drop;
  final void Function(NetworkMessage message)? inspect;

  _InspectTransport({required this.drop, this.inspect});

  @override
  Future<ClientConnection> connect(String host, int port) async =>
      _InspectConnection(
        await createClientTransport().connect(host, port),
        drop: drop,
        inspect: inspect,
      );
}

class _InspectConnection implements ClientConnection {
  final ClientConnection _inner;
  final bool Function(NetworkMessage) drop;
  final void Function(NetworkMessage)? inspect;

  _InspectConnection(this._inner, {required this.drop, this.inspect});

  @override
  void listen({
    required ClientDataCallback onData,
    required ClientDoneCallback onDone,
    required ClientErrorCallback onError,
  }) => _inner.listen(onData: onData, onDone: onDone, onError: onError);

  @override
  void send(List<int> data) {
    final message =
        NetworkMessage.fromPlainSocketData(data) ??
        NetworkMessage.fromSocketData(data, encryptionKey: 'test-key');
    if (message != null) {
      inspect?.call(message);
      if (drop(message)) return;
    }
    _inner.send(data);
  }

  @override
  Future<void> flush() => _inner.flush();

  @override
  Future<void> close() => _inner.close();
}

NetRealEngine _real(
  SocketClient room, {
  int maxPlayers = 3,
  void Function(NetworkMessage)? onResource,
  void Function(NetworkMessage)? onAction,
}) {
  late NetRealEngine engine;
  engine = configureRealEngine(
    room: room,
    maxPlayers: maxPlayers,
    searchHandler: (_) => engine.sendGameMessage(MessageType.resource, 'state'),
    resourceHandler: (message) {
      onResource?.call(message);
      // 本组测试只验证入局事务，不重复验证具体游戏 Manager 的同步屏障。
      engine.completeSynchronization();
    },
    syncHandler: (_) {},
    actionHandler: onAction ?? (_) {},
    exitHandler: (_) {},
  );
  return engine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gameId 协议往返保持不变，拒绝空值、错误类型和超长标识', () {
    final message = NetworkMessage(
      id: 1,
      type: MessageType.action,
      source: 'A',
      content: 'move',
      timestamp: 1,
      recipientId: 2,
      messageId: 'packet',
      gameId: 'game',
    );
    expect(NetworkMessage.fromJson(message.toJson())?.gameId, 'game');
    for (final invalid in ['', 123, 'x' * 129]) {
      expect(
        NetworkMessage.fromJson({...message.toJson(), 'gameId': invalid}),
        isNull,
      );
    }
  });

  test('另一局的 ACK 不能确认当前局同一 messageId 的投递', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final a = await h.join(
        'A',
        gameAckTimeout: const Duration(milliseconds: 30),
        maxGameResendAttempts: 1,
      );
      final b = await h.join(
        'B',
        transport: _InspectTransport(
          drop: (message) =>
              message.type == MessageType.ack && message.gameId == 'current',
        ),
      );
      final incoming = <NetworkMessage>[];
      b.addMessageListener(incoming.add);
      a.sendNetworkMessage(
        MessageType.action,
        'move',
        recipientId: b.identity,
        messageId: 'same-packet',
        gameId: 'current',
      );
      await waitFor(() => incoming.any((m) => m.content == 'move'));
      b.sendNetworkMessage(
        MessageType.ack,
        'same-packet',
        recipientId: a.identity,
        gameId: 'old',
      );
      await waitFor(() => a.deliveryFailure.value?.messageId == 'same-packet');
      expect(a.deliveryConfirmed.value, isNull);
    } finally {
      await h.close();
    }
  });

  test('丢失首个 ACK 时重发相同 messageId，双方仅处理一次局内消息', () async {
    final h = RoomHarness(3);
    await h.server.start();
    var attempts = 0;
    var dropped = false;
    try {
      final a = await h.join(
        'A',
        gameAckTimeout: const Duration(milliseconds: 35),
        transport: _InspectTransport(
          drop: (_) => false,
          inspect: (message) {
            if (message.type == MessageType.action) attempts++;
          },
        ),
      );
      final b = await h.join(
        'B',
        transport: _InspectTransport(
          drop: (message) {
            if (message.type != MessageType.ack || dropped) return false;
            dropped = true;
            return true;
          },
        ),
      );
      final seenA = <NetworkMessage>[];
      final seenB = <NetworkMessage>[];
      a.addMessageListener(seenA.add);
      b.addMessageListener(seenB.add);
      a.sendNetworkMessage(MessageType.action, 'once', recipientId: b.identity);
      await waitFor(() => dropped && attempts >= 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(attempts, 2);
      expect(seenA.where((m) => m.content == 'once'), hasLength(1));
      expect(seenB.where((m) => m.content == 'once'), hasLength(1));
      expect(
        seenA.singleWhere((m) => m.content == 'once').messageId,
        isNotNull,
      );
      expect(a.deliveryFailure.value, isNull);
    } finally {
      await h.close();
    }
  });

  test('房间 search 不等待 ACK，不进入游戏消息重发队列', () async {
    final h = RoomHarness(3);
    await h.server.start();
    var sends = 0;
    try {
      final a = await h.join(
        'A',
        gameAckTimeout: const Duration(milliseconds: 25),
        transport: _InspectTransport(
          drop: (_) => false,
          inspect: (message) {
            if (message.type == MessageType.search) sends++;
          },
        ),
      );
      a.sendNetworkMessage(MessageType.search, '');
      await waitFor(() => sends == 1);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(sends, 1);
      expect(a.deliveryFailure.value, isNull);
    } finally {
      await h.close();
    }
  });

  test('群发须收到每个对手的 ACK；重发不会重复应用已确认成员的消息', () async {
    final h = RoomHarness(4);
    await h.server.start();
    var sends = 0;
    var dropped = false;
    try {
      final a = await h.join(
        'A',
        gameAckTimeout: const Duration(milliseconds: 45),
        transport: _InspectTransport(
          drop: (_) => false,
          inspect: (message) {
            if (message.type == MessageType.sync) sends++;
          },
        ),
      );
      final b = await h.join('B');
      final c = await h.join(
        'C',
        transport: _InspectTransport(
          drop: (message) {
            if (message.type != MessageType.ack || dropped) return false;
            dropped = true;
            return true;
          },
        ),
      );
      final seenB = <NetworkMessage>[];
      final seenC = <NetworkMessage>[];
      b.addMessageListener(seenB.add);
      c.addMessageListener(seenC.add);
      a.sendNetworkMessage(
        MessageType.sync,
        'group',
        recipientIds: {a.identity, b.identity, c.identity},
      );
      await waitFor(() => dropped && sends >= 2);
      await Future<void>.delayed(const Duration(milliseconds: 110));
      expect(sends, 2);
      expect(seenB.where((m) => m.content == 'group'), hasLength(1));
      expect(seenC.where((m) => m.content == 'group'), hasLength(1));
      expect(a.deliveryFailure.value, isNull);
    } finally {
      await h.close();
    }
  });

  test('持续缺少 ACK 会报告投递失败，且重发次数有上限', () async {
    final h = RoomHarness(3);
    await h.server.start();
    var sends = 0;
    try {
      final a = await h.join(
        'A',
        gameAckTimeout: const Duration(milliseconds: 25),
        maxGameResendAttempts: 1,
        transport: _InspectTransport(
          drop: (_) => false,
          inspect: (message) {
            if (message.type == MessageType.action) sends++;
          },
        ),
      );
      final b = await h.join(
        'B',
        transport: _InspectTransport(
          drop: (message) => message.type == MessageType.ack,
        ),
      );
      a.sendNetworkMessage(
        MessageType.action,
        'timeout',
        recipientId: b.identity,
      );
      await waitFor(() => a.deliveryFailure.value?.content == 'timeout');
      expect(sends, 2);
    } finally {
      await h.close();
    }
  });

  test('首个匹配提交丢失且重发间隔超过两秒，双方仍能完成同一场匹配', () async {
    final h = RoomHarness(3);
    await h.server.start();
    var dropped = false;
    try {
      final a = await h.join(
        'A',
        gameAckTimeout: const Duration(milliseconds: 2100),
        transport: _InspectTransport(
          drop: (message) {
            if (message.type != MessageType.confirm ||
                !message.content.startsWith('commit:') ||
                dropped) {
              return false;
            }
            dropped = true;
            return true;
          },
        ),
      );
      final b = await h.join('B');
      a.startMatching();
      await waitFor(() => a.matchPhase.value == RoomMatchPhase.matching);
      b.startMatching();
      await waitFor(
        () =>
            dropped &&
            a.matchPhase.value == RoomMatchPhase.matched &&
            b.matchPhase.value == RoomMatchPhase.matched,
      );
      expect(a.matchedOpponentId, b.identity);
      expect(b.matchedOpponentId, a.identity);
    } finally {
      await h.close();
    }
  });

  test('实时中途加入复用已有 gameId，所有参与者和资源回调属于同一局', () async {
    final h = RoomHarness(4);
    await h.server.start();
    try {
      final a = startGame(_real(await h.join('A')));
      final b = startGame(_real(await h.join('B')));
      await waitFor(
        () =>
            a.gameStep.value == GameStep.action &&
            b.gameStep.value == GameStep.action,
      );
      final firstGame = a.gameId;
      expect(firstGame, isNotNull);
      expect(b.gameId, firstGame);
      String? resourceGame;
      final c = startGame(
        _real(
          await h.join('C'),
          onResource: (message) => resourceGame = message.gameId,
        ),
      );
      await waitFor(
        () =>
            a.participants.length == 3 &&
            b.participants.length == 3 &&
            c.participants.length == 3 &&
            c.gameStep.value == GameStep.action,
      );
      expect(c.gameId, firstGame);
      expect(resourceGame, firstGame);
      expect(c.matchedOfferId, isNot(a.matchedOfferId));
      c.sendGameText('shared game');
      await waitFor(
        () =>
            a.gameMessageList.value.any((m) => m.content == 'shared game') &&
            b.gameMessageList.value.any((m) => m.content == 'shared game'),
      );
      expect(a.gameMessageList.value.last.gameId, firstGame);
    } finally {
      await h.close();
    }
  });

  test('入局 start 持续丢失会回滚预留；不暂停旧局，且释放满员名额', () async {
    final h = RoomHarness(4);
    await h.server.start();
    var newcomer = 0;
    var dropAbortOnce = true;
    var abortDropped = false;
    var resources = 0;
    try {
      final a = startGame(
        _real(
          await h.join(
            'A',
            gameAckTimeout: const Duration(milliseconds: 30),
            maxGameResendAttempts: 1,
            transport: _InspectTransport(
              drop: (message) {
                if (message.recipientId != newcomer) return false;
                if (message.type == MessageType.confirm &&
                    message.content.startsWith('start:')) {
                  return true;
                }
                if (dropAbortOnce &&
                    message.type == MessageType.confirm &&
                    message.content.startsWith('abort:')) {
                  dropAbortOnce = false;
                  abortDropped = true;
                  return true;
                }
                return false;
              },
            ),
          ),
          onResource: (_) => resources++,
        ),
      );
      final b = startGame(_real(await h.join('B')));
      await waitFor(() => a.gameStep.value == GameStep.action);
      final before = resources;
      final roomC = await h.join('C');
      newcomer = roomC.identity;
      final received = <NetworkMessage>[];
      roomC.addMessageListener(received.add);
      final c = startGame(_real(roomC));
      await waitFor(() => abortDropped);
      // 等待可靠 abort 的重发确实送达，候选锁已经释放。
      await waitFor(() => received.any((m) => m.content.startsWith('abort:')));
      expect(a.participants.keys, {a.identity, b.identity});
      expect(a.gameStep.value, GameStep.action);
      expect(b.gameStep.value, GameStep.action);
      expect(resources, before);
      expect(c.isActive, isFalse);
      c.cancelMatch();
      c.releaseGame();
      final d = startGame(_real(await h.join('D')));
      await waitFor(
        () =>
            d.gameStep.value == GameStep.action &&
            a.participants.containsKey(d.identity),
      );
      expect(a.participants, hasLength(3));
      expect(a.participants.containsKey(newcomer), isFalse);
    } finally {
      await h.close();
    }
  });

  test('joined 的 ACK 全丢失后撤销新成员并重同步，原有对局继续', () async {
    final h = RoomHarness(4);
    await h.server.start();
    var newcomer = 0;
    String? joinedMessageId;
    String? joinedContent;
    var searches = 0;
    var sawAbort = false;
    var resources = 0;
    NetworkMessage? provisionalResource;
    try {
      final a = startGame(
        _real(
          await h.join(
            'A',
            transport: _InspectTransport(
              drop: (message) =>
                  message.type == MessageType.ack &&
                  message.recipientId == newcomer &&
                  message.content == joinedMessageId,
            ),
          ),
          onResource: (_) => resources++,
        ),
      );
      final b = startGame(_real(await h.join('B')));
      await waitFor(() => a.gameStep.value == GameStep.action);
      final originalGame = a.gameId;
      final before = resources;
      final roomC = await h.join(
        'C',
        gameAckTimeout: const Duration(milliseconds: 30),
        maxGameResendAttempts: 1,
        transport: _InspectTransport(
          inspect: (message) {
            if (message.type == MessageType.confirm &&
                message.content.startsWith('joined:')) {
              joinedMessageId = message.messageId;
              joinedContent = message.content;
            }
          },
          // 本测试停在回滚结果，不让自动重新搜索立即开始另一轮入局。
          drop: (message) =>
              message.type == MessageType.search && searches++ > 0,
        ),
      );
      newcomer = roomC.identity;
      a.client.addMessageListener((message) {
        if (message.id == newcomer && message.content.startsWith('abort:')) {
          sawAbort = true;
        }
        if (message.type == MessageType.resource &&
            (message.recipientIds?.contains(newcomer) ?? false)) {
          provisionalResource = message;
        }
      });
      final c = startGame(_real(roomC));
      await waitFor(
        () =>
            sawAbort &&
            a.participants.length == 2 &&
            b.participants.length == 2 &&
            a.gameStep.value == GameStep.action &&
            b.gameStep.value == GameStep.action,
      );
      expect(resources, greaterThan(before));
      expect(a.gameId, originalGame);
      expect(b.gameId, originalGame);
      expect(a.ended.value, isFalse);
      expect(c.isActive, isFalse);
      expect(c.matchedGameId, isNull);
      expect(provisionalResource, isNotNull);
      final replayed = <NetworkMessage>[];
      b.client.addMessageListener(replayed.add);
      a.client.sendNetworkMessage(
        MessageType.resource,
        provisionalResource!.content,
        recipientIds: provisionalResource!.recipientIds,
        messageId: 'late-provisional-roster',
        gameId: originalGame,
      );
      await waitFor(
        () => replayed.any((m) => m.messageId == 'late-provisional-roster'),
      );
      expect(a.participants, hasLength(2));
      expect(b.participants, hasLength(2));
      // 旧包到达已回滚的事务不能重新添加成员。
      roomC.sendNetworkMessage(
        MessageType.confirm,
        joinedContent!,
        recipientId: a.identity,
        gameId: originalGame,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(a.participants, hasLength(2));
    } finally {
      await h.close();
    }
  });

  test('实时重新匹配后旧局合法群发包不能改动新局，同一消息 ID 可跨局使用', () async {
    final h = RoomHarness(4);
    await h.server.start();
    final actions = <String>[];
    try {
      final roomA = await h.join('A');
      final roomB = await h.join('B');
      var a = startGame(_real(roomA));
      var b = startGame(_real(roomB));
      await waitFor(() => a.gameStep.value == GameStep.action);
      final oldGame = a.gameId;
      a.finishGame(sendExit: false);
      b.finishGame(sendExit: false);
      a.releaseGame();
      b.releaseGame();
      a = startGame(_real(roomA));
      b = startGame(_real(roomB, onAction: (m) => actions.add(m.content)));
      await waitFor(
        () =>
            a.gameStep.value == GameStep.action &&
            b.gameStep.value == GameStep.action,
      );
      expect(a.gameId, isNot(oldGame));
      final incoming = <NetworkMessage>[];
      roomB.addMessageListener(incoming.add);
      final targets = {roomA.identity, roomB.identity};
      for (final type in [
        MessageType.exit,
        MessageType.resource,
        MessageType.action,
        MessageType.text,
      ]) {
        roomA.sendNetworkMessage(
          type,
          'old-${type.name}',
          recipientIds: targets,
          messageId: type == MessageType.text
              ? 'reused-id'
              : 'old-${type.name}',
          gameId: oldGame,
        );
      }
      roomA.sendNetworkMessage(
        MessageType.text,
        'current text',
        recipientIds: targets,
        messageId: 'reused-id',
        gameId: a.gameId,
      );
      await waitFor(
        () =>
            incoming.any((m) => m.content == 'old-exit') &&
            b.gameMessageList.value.any((m) => m.content == 'current text'),
      );
      expect(actions, isEmpty);
      expect(b.participants.keys, targets);
      expect(b.gameStep.value, GameStep.action);
      expect(
        b.gameMessageList.value.any((m) => m.content == 'old-text'),
        isFalse,
      );
      expect(a.gameId, b.gameId);
    } finally {
      await h.close();
    }
  });

  test('实时发布者退出后 gameId 不变，新发布者邀请也复用同一对局', () async {
    final h = RoomHarness(4);
    await h.server.start();
    try {
      final a = startGame(_real(await h.join('A')));
      final b = startGame(_real(await h.join('B')));
      await waitFor(() => a.gameStep.value == GameStep.action);
      final originalGame = a.gameId;
      final c = startGame(_real(await h.join('C')));
      await waitFor(() => c.gameStep.value == GameStep.action);
      a.finishGame();
      await waitFor(
        () =>
            b.publisherId == b.identity &&
            c.publisherId == b.identity &&
            b.gameStep.value == GameStep.action &&
            c.gameStep.value == GameStep.action &&
            b.participants.length == 2,
      );
      expect(b.gameId, originalGame);
      expect(c.gameId, originalGame);
      a.releaseGame();
      final returning = startGame(_real(a.client));
      await waitFor(
        () =>
            returning.gameStep.value == GameStep.action &&
            b.participants.length == 3 &&
            c.participants.length == 3,
      );
      expect(returning.gameId, originalGame);
      expect(returning.publisherId, b.identity);
      returning.sendGameMessage(MessageType.action, 'returning player action');
      final received = <NetworkMessage>[];
      b.client.addMessageListener(received.add);
      returning.sendGameMessage(MessageType.sync, 'returning player sync');
      await waitFor(
        () => received.any((m) => m.content == 'returning player sync'),
      );
      expect(b.publisherId, b.identity);
      expect(c.publisherId, b.identity);
    } finally {
      await h.close();
    }
  });

  test('发布者在最终 ACK 前断开，已知参与者也能撤销尚未完成的入局', () async {
    final h = RoomHarness(4);
    await h.server.start();
    var newcomer = 0;
    String? joinedMessageId;
    var searches = 0;
    try {
      final a = startGame(
        _real(
          await h.join(
            'A',
            transport: _InspectTransport(
              drop: (message) =>
                  message.type == MessageType.ack &&
                  message.recipientId == newcomer &&
                  message.content == joinedMessageId,
            ),
          ),
        ),
      );
      final b = startGame(_real(await h.join('B')));
      await waitFor(() => a.gameStep.value == GameStep.action);
      final originalGame = a.gameId;
      final roomC = await h.join(
        'C',
        transport: _InspectTransport(
          inspect: (message) {
            if (message.type == MessageType.confirm &&
                message.content.startsWith('joined:')) {
              joinedMessageId = message.messageId;
            }
          },
          drop: (message) =>
              message.type == MessageType.search && searches++ > 0,
        ),
      );
      newcomer = roomC.identity;
      final incoming = <NetworkMessage>[];
      roomC.addMessageListener(incoming.add);
      final c = startGame(_real(roomC));
      await waitFor(
        () =>
            incoming.any((m) => m.type == MessageType.resource) &&
            b.participants.containsKey(newcomer),
      );
      await a.client.close();
      await waitFor(
        () =>
            b.participants.keys.toSet().difference({b.identity}).isEmpty &&
            !b.participants.containsKey(newcomer) &&
            c.matchPhase.value == RoomMatchPhase.matching,
      );
      expect(b.gameId, originalGame);
      expect(b.ended.value, isFalse);
      expect(c.isActive, isFalse);
    } finally {
      await h.close();
    }
  });
}
