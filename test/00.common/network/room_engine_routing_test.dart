import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/net_real_engine.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/network/client/room_chat_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';

import 'support/network_room_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('销毁聊天引擎不会关闭已认证连接', () async {
    final h = RoomHarness(0);
    await h.server.start();
    RoomChatEngine? replacement;
    try {
      final room = await h.join('A');
      final original = RoomChatEngine.forClient(room);
      original.dispose();
      expect(room.isJoined, isTrue);
      replacement = RoomChatEngine.forClient(room);
      expect(identical(original, replacement), isFalse);
      expect(replacement.client, same(room));
    } finally {
      replacement?.dispose();
      await h.close();
    }
  });

  test('认证完成到创建聊天引擎之间的消息会按序补发', () async {
    final h = RoomHarness(0);
    await h.server.start();
    final first = SocketClient(
      userName: 'Alice',
      endpoint: RoomInfo(
        name: '房间',
        type: 0,
        address: '127.0.0.1',
        port: h.server.port,
        encryptionKey: h.server.encryptionKey,
      ),
    );
    RoomChatEngine? chat;
    try {
      await first.join();
      final second = await h.join('Bob');
      second.chat.sendText('页面出现前的消息');
      await waitFor(() => h.server.members.length == 2);
      // 原始观察者用于确定消息已抵达连接；此时尚未创建聊天引擎。
      final arrived = <String>[];
      first.addMessageListener((message) => arrived.add(message.content));
      second.chat.sendText('最后一条');
      await waitFor(() => arrived.contains('最后一条'));

      chat = RoomChatEngine.forClient(first);
      expect(chat.runtimeType, RoomChatEngine);
      expect(
        chat.messageList.value.any((m) => m.content == '页面出现前的消息'),
        isTrue,
      );
      expect(chat.messageList.value.any((m) => m.content == '最后一条'), isTrue);
    } finally {
      chat?.dispose();
      await first.close();
      first.dispose();
      await h.close();
    }
  });

  test('回合引擎保留房间聊天，对局双方消息仅进入额外的对局记录', () async {
    final h = RoomHarness(3);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final c = await h.join('C');
      final turnA = RoomChatEngine.forClient(a) as NetTurnEngine;
      final turnB = RoomChatEngine.forClient(b) as NetTurnEngine;
      final turnC = RoomChatEngine.forClient(c) as NetTurnEngine;
      turnA.startMatching();
      await waitFor(() => turnA.matchPhase.value == RoomMatchPhase.matching);
      turnB.startMatching();
      await waitFor(
        () =>
            turnA.matchPhase.value == RoomMatchPhase.matched &&
            turnB.matchPhase.value == RoomMatchPhase.matched,
      );
      final gameA = turnA
        ..configureGame(
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        )
        ..startFromRoom();
      final gameB = turnB
        ..configureGame(
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        )
        ..startFromRoom();
      expect(identical(gameA, turnA), isTrue);
      expect(identical(gameB, turnB), isTrue);
      gameA.sendGameText('本局私聊');
      turnC.sendText('大厅聊天');
      await waitFor(
        () =>
            turnA.gameMessageList.value.any((m) => m.content == '本局私聊') &&
            turnB.gameMessageList.value.any((m) => m.content == '本局私聊') &&
            turnA.messageList.value.any((m) => m.content == '大厅聊天'),
      );
      expect(turnA.messageList.value.any((m) => m.content == '本局私聊'), isFalse);
      expect(turnC.gameMessageList.value, isEmpty);
      gameA.finishGame(sendExit: false);
      gameB.finishGame(sendExit: false);
      gameA.releaseGame();
      gameB.releaseGame();
      expect(a.isJoined, isTrue);
      final next = turnA
        ..configureGame(
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        );
      expect(next, same(gameA));
      expect(next.gameMessageList.value, isEmpty);
      expect(next.messageList.value.any((m) => m.content == '大厅聊天'), isTrue);
      next.releaseGame();
    } finally {
      await h.close();
    }
  });

  test('实时引擎的群聊只进入参与者的对局记录，不混入房间记录', () async {
    final h = RoomHarness(4);
    await h.server.start();
    try {
      final a = await h.join('A');
      final b = await h.join('B');
      final c = await h.join('C');
      final realA = RoomChatEngine.forClient(a) as NetRealEngine;
      final realB = RoomChatEngine.forClient(b) as NetRealEngine;
      final realC = RoomChatEngine.forClient(c) as NetRealEngine;
      realA.startMatching();
      await waitFor(() => realA.matchPhase.value == RoomMatchPhase.matching);
      realB.startMatching();
      await waitFor(
        () =>
            realA.matchPhase.value == RoomMatchPhase.matched &&
            realB.matchPhase.value == RoomMatchPhase.matched,
      );
      final gameA = realA
        ..configureGame(
          searchHandler: (_) {},
          resourceHandler: (_) {},
          syncHandler: (_) {},
          actionHandler: (_) {},
          exitHandler: (_) {},
        )
        ..startFromRoom();
      final gameB = realB
        ..configureGame(
          searchHandler: (_) {},
          resourceHandler: (_) {},
          syncHandler: (_) {},
          actionHandler: (_) {},
          exitHandler: (_) {},
        )
        ..startFromRoom();
      expect(identical(gameA, realA), isTrue);
      gameA.sendGameText('实时局内消息');
      await waitFor(
        () => realB.gameMessageList.value.any(
          (message) => message.content == '实时局内消息',
        ),
      );
      expect(
        realA.messageList.value.any((m) => m.content == '实时局内消息'),
        isFalse,
      );
      expect(
        realC.messageList.value.any((m) => m.content == '实时局内消息'),
        isFalse,
      );
      expect(realC.gameMessageList.value, isEmpty);
      gameA.releaseGame();
      gameB.releaseGame();
    } finally {
      await h.close();
    }
  });
}
