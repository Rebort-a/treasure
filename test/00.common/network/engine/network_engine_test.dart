import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/network/client/network_engine.dart';
import 'package:treasure/00.common/network/client/net_real_engine.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/real_game_session.dart';
import 'package:treasure/00.common/network/client/turn_game_session.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';

import '../support/network_room_harness.dart';

RoomInfo endpoint(int type) => RoomInfo(
  name: 'room',
  type: type,
  address: '127.0.0.1',
  port: 1,
  encryptionKey: 'test-key',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('按房间类型创建唯一网络引擎，纯聊天室没有游戏子类', () {
    final chat = NetworkEngine.forRoom(userName: 'A', endpoint: endpoint(0));
    final turn = NetworkEngine.forRoom(userName: 'B', endpoint: endpoint(3));
    final real = NetworkEngine.forRoom(userName: 'C', endpoint: endpoint(4));
    expect(chat.runtimeType, NetworkEngine);
    expect(turn, isA<NetTurnEngine>());
    expect(real, isA<NetRealEngine>());
    chat.dispose();
    turn.dispose();
    real.dispose();
  });

  test('回合房间复用连接引擎，并且同一时刻只允许一个对局会话', () {
    final room = NetworkEngine.forRoom(
      userName: 'A',
      endpoint: endpoint(3),
    ) as NetTurnEngine;
    TurnGameSession create() => room.createSession(
      resourceMode: TurnResourceMode.none,
      actionHandler: (_, __) {},
      exitHandler: () {},
    );
    final first = create();
    expect(identical(first.room, room), isTrue);
    expect(create, throwsStateError);
    first.finish(sendExit: false);
    final next = create();
    expect(identical(next.room, room), isTrue);
    next.dispose();
    first.dispose();
    room.dispose();
  });

  test('手动地址未知类型：认证后沿用原连接加入回合对局', () async {
    final harness = RoomHarness(3);
    await harness.server.start();
    final manual = NetworkEngine.forRoom(
      userName: 'Manual',
      endpoint: RoomInfo(
        name: 'direct',
        type: OnlineItemType.onlyChat.index,
        address: '127.0.0.1',
        port: harness.server.port,
        encryptionKey: harness.server.encryptionKey,
      ),
    );
    TurnGameSession? session;
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
      session = createTurnSession(
        room: manual,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      )..startFromRoom();
      expect(session.isActive, isTrue);
      expect(session.enemyId, peer.identity);
      expect(harness.server.members.length, 2);
    } finally {
      session?.dispose();
      await manual.close();
      manual.dispose();
      await harness.close();
    }
  });

  test('手动地址未知类型：认证后沿用原连接加入实时对局', () async {
    final harness = RoomHarness(4);
    await harness.server.start();
    final manual = NetworkEngine.forRoom(
      userName: 'Manual',
      endpoint: RoomInfo(
        name: 'direct',
        type: OnlineItemType.onlyChat.index,
        address: '127.0.0.1',
        port: harness.server.port,
        encryptionKey: harness.server.encryptionKey,
      ),
    );
    RealGameSession? session;
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
      session = createRealSession(
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
      session?.dispose();
      await manual.close();
      manual.dispose();
      await harness.close();
    }
  });
}
