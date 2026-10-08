import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/client/net_real_engine.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';

import '../support/network_room_harness.dart';
import '../support/match_game_driver.dart';

RoomInfo endpoint(int type) => RoomInfo(
  name: 'room',
  type: type,
  address: '127.0.0.1',
  port: 1,
  encryptionKey: 'test-key',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('认证前只创建连接，不能靠发现信息选择游戏引擎', () {
    final chat = SocketClient(userName: 'A', endpoint: endpoint(0));
    final turn = SocketClient(userName: 'B', endpoint: endpoint(3));
    final real = SocketClient(userName: 'C', endpoint: endpoint(4));
    expect(chat.runtimeType, SocketClient);
    expect(turn.runtimeType, SocketClient);
    expect(real.runtimeType, SocketClient);
    expect(() => RoomChatEngine.forClient(turn), throwsStateError);
    chat.dispose();
    turn.dispose();
    real.dispose();
  });

  test('认证后复用唯一回合引擎，同一时间只配置一局', () async {
    final h = RoomHarness(3);
    await h.server.start();
    final room = await h.join('A');
    final engine = RoomChatEngine.forClient(room) as NetTurnEngine;
    NetTurnEngine create() => engine..configureGame(
      resourceMode: TurnResourceMode.none,
      actionHandler: (_, __) {},
      exitHandler: () {},
    );
    try {
      final first = create();
      expect(identical(first.client, room), isTrue);
      expect(create, throwsStateError);
      first.finishGame(sendExit: false);
      first.releaseGame();
      final next = create();
      expect(identical(next, first), isTrue);
      next.releaseGame();
    } finally {
      await h.close();
    }
  });

  test('手动地址未知类型：认证后沿用原连接加入回合对局', () async {
    final harness = RoomHarness(3);
    await harness.server.start();
    final manual = SocketClient(
      userName: 'Manual',
      endpoint: RoomInfo(
        name: 'direct',
        type: OnlineItemType.onlyChat.index,
        address: '127.0.0.1',
        port: harness.server.port,
        encryptionKey: harness.server.encryptionKey,
      ),
    );
    NetTurnEngine? session;
    try {
      await manual.join();
      final peer = await harness.join('Peer');
      manual.startMatching();
      await waitFor(() => manual.matchPhase.value == RoomMatchPhase.matching);
      peer.startMatching();
      await waitFor(
        () =>
            manual.matchPhase.value == RoomMatchPhase.matched &&
            peer.matchPhase.value == RoomMatchPhase.matched,
      );
      session = configureTurnEngine(
        room: manual,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      )..startFromRoom();
      expect(session.isActive, isTrue);
      expect(session.enemyId, peer.identity);
      expect(harness.server.members.length, 2);
    } finally {
      session?.releaseGame();
      if (manual.isJoined) NetTurnEngine.forClient(manual).dispose();
      await manual.close();
      manual.dispose();
      await harness.close();
    }
  });

  test('手动地址未知类型：认证后沿用原连接加入实时对局', () async {
    final harness = RoomHarness(4);
    await harness.server.start();
    final manual = SocketClient(
      userName: 'Manual',
      endpoint: RoomInfo(
        name: 'direct',
        type: OnlineItemType.onlyChat.index,
        address: '127.0.0.1',
        port: harness.server.port,
        encryptionKey: harness.server.encryptionKey,
      ),
    );
    NetRealEngine? session;
    try {
      await manual.join();
      final peer = await harness.join('Peer');
      manual.startMatching();
      await waitFor(() => manual.matchPhase.value == RoomMatchPhase.matching);
      peer.startMatching();
      await waitFor(
        () =>
            manual.matchPhase.value == RoomMatchPhase.matched &&
            peer.matchPhase.value == RoomMatchPhase.matched,
      );
      session = configureRealEngine(
        room: manual,
        searchHandler: (_) {},
        resourceHandler: (_) {},
        syncHandler: (_) {},
        actionHandler: (_) {},
        exitHandler: (_) {},
      )..startFromRoom();
      expect(session.isActive, isTrue);
      expect(session.publisherId, manual.identity);
      expect(harness.server.members.length, 2);
    } finally {
      session?.releaseGame();
      if (manual.isJoined) NetRealEngine.forClient(manual).dispose();
      await manual.close();
      manual.dispose();
      await harness.close();
    }
  });
}
