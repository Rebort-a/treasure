import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/engine/net_turn_engine.dart';
import 'package:treasure/00.common/engine/network_engine.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/00.common/network/network_room.dart';
import 'package:treasure/00.common/tool/notifiers.dart';
import 'package:treasure/00.common/widget/navigator/game_launch.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('关闭和销毁幂等，结束对局并释放通知器与输入控制器', () async {
    final h = RoomHarness(3);
    await h.server.start();
    NetTurnGameEngine? game;
    try {
      final room = await h.join('A');
      game = NetTurnGameEngine(
        room: room,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      )..start();
      final closed = room.closeSocket();
      expect(identical(closed, room.closeSocket()), isTrue);
      expect(game.ended.value, isTrue);
      room.dispose();
      room.dispose();
      await closed;
      await waitFor(() => h.server.session.count == 0);
      void listener() {}
      expect(
        () => room.identityNotifier.addListener(listener),
        throwsFlutterError,
      );
      expect(() => room.roomSession.addListener(listener), throwsFlutterError);
      expect(() => room.messageList.addListener(listener), throwsFlutterError);
      expect(
        () => room.textController.addListener(listener),
        throwsFlutterError,
      );
      expect(
        () => room.scrollController.addListener(listener),
        throwsFlutterError,
      );
      room.sendNetworkMessage(MessageType.text, '销毁后不发送');
    } finally {
      game?.dispose();
      await h.close();
    }
  });

  test('连续请求离开只发布一次导航命令', () async {
    final h = RoomHarness(0);
    await h.server.start();
    try {
      final room = await h.join('A');
      var navigations = 0;
      room.navigatorHandler.addListener(() => navigations++);
      room.leavePage();
      room.leavePage();
      await room.closeSocket();
      expect(navigations, 1);
      await waitFor(() => h.server.session.count == 0);
    } finally {
      await h.close();
    }
  });

  test('游戏启动对象只释放一次管理器，不销毁房间连接', () async {
    final h = RoomHarness(3);
    await h.server.start();
    GameLaunch? launch;
    try {
      final room = await h.join('A');
      final game = NetTurnGameEngine(
        room: room,
        resourceMode: TurnResourceMode.none,
        actionHandler: (_, __) {},
        exitHandler: () {},
      );
      var releases = 0;
      launch = GameLaunch(game, () => const SizedBox.shrink(), () {
        releases++;
        game.dispose();
      });
      launch.dispose();
      launch.dispose();
      expect(releases, 1);
      expect(room.identity, greaterThan(0));
      expect(h.server.session.count, 1);
    } finally {
      launch?.dispose();
      await h.close();
    }
  });

  test('连接尚未建立时销毁，迟到的连接不会入房或触发重连', () async {
    final h = RoomHarness(0);
    await h.server.start();
    final navigator = AlwaysNotifier<void Function(BuildContext)>((_) {});
    var commands = 0;
    navigator.addListener(() => commands++);
    final room = NetworkEngine(
      userName: 'A',
      roomInfo: RoomInfo(
        name: 'Test',
        type: 0,
        address: '127.0.0.1',
        port: h.server.port,
      ),
      navigatorHandler: navigator,
    );
    try {
      room.dispose();
      await room.closeSocket();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(room.identity, 0);
      expect(h.server.session.count, 0);
      expect(commands, 0);
    } finally {
      room.dispose();
      navigator.dispose();
      await h.close();
    }
  });
}
