import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/02.lan_chat/net_manager.dart';
import 'package:treasure/05.gobang/net_page.dart';

import 'support/network_room_harness.dart';
import 'support/match_game_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('服务端启动期间停止会关闭迟到端口，重复停止共享同一结果', () async {
    final h = RoomHarness(3);
    final starting = h.server.start();
    final stopping = h.server.stop();
    expect(identical(stopping, h.server.stop()), isTrue);
    await starting;
    await stopping;
    expect(h.server.port, 0);
    expect(h.server.members, isEmpty);
    await expectLater(h.server.start(), throwsStateError);
    await h.close();
  });

  test('关闭和销毁幂等，结束对局并释放房间通知器', () async {
    final h = RoomHarness(3);
    await h.server.start();
    NetTurnEngine? game;
    try {
      final room = await h.join('A');
      final chat = room.chat;
      game = startGame(
        configureTurnEngine(
          room: room,
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        ),
      );
      final closed = room.close();
      expect(identical(closed, room.close()), isTrue);
      expect(game.ended.value, isTrue);
      chat.dispose();
      room.dispose();
      room.dispose();
      await closed;
      await waitFor(() => h.server.members.length == 0);
      void listener() {}
      expect(
        () => room.identityNotifier.addListener(listener),
        throwsFlutterError,
      );
      expect(() => room.members.addListener(listener), throwsFlutterError);
      expect(() => chat.messageList.addListener(listener), throwsFlutterError);
      expect(() => room.status.addListener(listener), throwsFlutterError);
      room.sendNetworkMessage(MessageType.text, '销毁后不发送');
    } finally {
      game?.releaseGame();
      await h.close();
    }
  });

  test('连续请求离开只发布一次导航命令', () async {
    final h = RoomHarness(0);
    await h.server.start();
    try {
      final room = await h.join('A');
      final manager = NetManager(room: room);
      var navigations = 0;
      manager.pageNavigator.addListener(() => navigations++);
      manager.leavePage();
      manager.leavePage();
      await room.close();
      expect(navigations, 1);
      manager.dispose();
      await waitFor(() => h.server.members.length == 0);
    } finally {
      await h.close();
    }
  });

  test('项目页面入口不会提前启动对局或销毁房间连接', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final room = await h.join('A');
      final entry = NetGomokuPage(room: room);
      expect(entry, isA<NetGomokuPage>());
      expect(room.matchPhase.value, RoomMatchPhase.idle);
      expect(room.identity, greaterThan(0));
      expect(h.server.members.length, 1);
    } finally {
      await h.close();
    }
  });

  test('连接尚未建立时销毁，迟到的连接不会入房或触发重连', () async {
    final h = RoomHarness(0);
    await h.server.start();
    final room = SocketClient(
      userName: 'A',
      endpoint: RoomInfo(
        name: 'Test',
        type: 0,
        address: '127.0.0.1',
        port: h.server.port,
        encryptionKey: h.server.encryptionKey,
      ),
    );
    try {
      final pending = expectLater(
        room.join(),
        throwsA(isA<RoomJoinException>()),
      );
      room.dispose();
      await pending;
      await room.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(room.identity, 0);
      expect(h.server.members.length, 0);
    } finally {
      room.dispose();
      await h.close();
    }
  });
}
