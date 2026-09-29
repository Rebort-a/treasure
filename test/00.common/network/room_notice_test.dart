import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/model/chat_channel.dart';
import 'package:treasure/00.common/network/session/turn_game_session.dart';
import 'package:treasure/00.common/l10n/app_localizations.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/model/chat_message.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/00.common/model/notifiers.dart';
import 'package:treasure/00.common/widget/component/chat_component.dart';

import 'support/network_room_harness.dart';
import 'support/match_game_driver.dart';

const _english = [
  'Alice Joined the room',
  'Alice Left the room',
  'Alice Matching players',
  'Alice Left the game',
];
const _chinese = ['Alice 加入了房间', 'Alice 离开了房间', 'Alice 正在匹配玩家', 'Alice 退出了游戏'];

NetworkMessage _notice(RoomNotice notice) => NetworkMessage(
  id: 1,
  type: MessageType.notify,
  source: 'Alice',
  content: notice.content,
  timestamp: 1234567890000 + notice.code,
);

Widget _chat(Locale locale, _Chat channel) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: MessageList(channel: channel)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LanguageProvider.instance.resetForTesting());
  tearDown(() => LanguageProvider.instance.resetForTesting());

  test('通知使用固定编码，序列化往返不携带翻译文本', () {
    expect(RoomNotice.values.map((notice) => notice.code), [1, 2, 3, 4]);
    for (final notice in RoomNotice.values) {
      final wire = _notice(notice).toSocketData(encryptionKey: 'room-key');
      final restored = NetworkMessage.fromSocketData(
        wire,
        encryptionKey: 'room-key',
      )!;
      expect(restored.content, notice.code.toString());
      expect(ChatMessage.fromNetworkMessage(restored, 2, 'Bob').notice, notice);
      expect(restored.source, 'Alice');
    }
  });

  test('无效编码和旧通知文本被丢弃，普通聊天内容不受影响', () {
    for (final content in [
      null,
      '',
      '0',
      '-1',
      '999',
      '1.0',
      'joinedRoom',
      'Joined the room',
      '加入了房间',
      'leave room',
    ]) {
      final json = {
        'id': 1,
        'route': 'room',
        'type': MessageType.notify.index,
        'source': 'Alice',
        'content': content,
      };
      expect(NetworkMessage.fromJson(json), isNull);
      json['type'] = MessageType.text.index;
      expect(NetworkMessage.fromJson(json), isNotNull);
    }
    final text = NetworkMessage(
      id: 1,
      type: MessageType.text,
      source: 'Alice',
      content: '1',
    );
    final chat = ChatMessage.fromNetworkMessage(text, 2, 'Bob');
    expect(chat.content, '1');
    expect(chat.notice, isNull);
    expect(chat.isSystem, isFalse);
  });

  testWidgets('同一组消息在两个不同语言的界面中分别本地化', (tester) async {
    final english = _Chat();
    final chinese = _Chat();
    try {
      for (final channel in [english, chinese]) {
        channel.messageList.addAll(RoomNotice.values.map(_notice));
        channel.messageList.add(
          NetworkMessage(
            id: 1,
            type: MessageType.text,
            source: 'Alice',
            content: 'Joined the room',
          ),
        );
        channel.messageList.add(
          NetworkMessage(
            id: 1,
            type: MessageType.text,
            source: 'Alice',
            content: '1',
          ),
        );
      }
      await tester.pumpWidget(
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(child: _chat(const Locale('en'), english)),
            Expanded(child: _chat(const Locale('zh'), chinese)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      for (final text in [..._english, ..._chinese]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('Joined the room'), findsNWidgets(2));
      expect(find.text('1'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      english.dispose();
      chinese.dispose();
    }
  });

  testWidgets('切换本地语言后已有通知重新翻译，不修改原始消息', (tester) async {
    final channel = _Chat();
    final locale = ValueNotifier(const Locale('en'));
    channel.messageList.addAll(RoomNotice.values.map(_notice));
    final original = channel.messageList.value
        .map((m) => m.toJsonString())
        .toList();
    try {
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (_, value, __) => _chat(value, channel),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in _english) {
        expect(find.text(text), findsOneWidget);
      }
      locale.value = const Locale('zh');
      await tester.pumpAndSettle();
      for (final text in _chinese) {
        expect(find.text(text), findsOneWidget);
      }
      for (final text in _english) {
        expect(find.text(text), findsNothing);
      }
      expect(channel.messageList.value.map((m) => m.toJsonString()), original);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      locale.dispose();
      channel.dispose();
    }
  });

  test('真实房间的加入、匹配、退出游戏和离房通知均只发送编码', () async {
    HttpOverrides.global = null;
    final h = RoomHarness(3);
    TurnGameSession? game;
    TurnGameSession? opponent;
    await h.server.start();
    try {
      final observer = await h.join('Observer');
      await LanguageProvider.instance.setLocale(AppLocale.zh);
      final alice = await h.join('Alice');
      List<RoomNotice?> received() => observer.messageList.value
          .where((m) => m.type == MessageType.notify && m.source == 'Alice')
          .map((m) => RoomNotice.fromContent(m.content))
          .toList();
      await waitFor(() => received().contains(RoomNotice.joinedRoom));
      game = startGame(
        TurnGameSession(
          room: alice,
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        ),
      );
      await waitFor(() => received().contains(RoomNotice.matchingPlayers));
      opponent = startGame(
        TurnGameSession(
          room: observer,
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        ),
      );
      await waitFor(
        () => game!.readyToOpen.value && opponent!.readyToOpen.value,
      );
      await LanguageProvider.instance.setLocale(AppLocale.en);
      game.finish();
      await waitFor(() => received().contains(RoomNotice.leftGame));
      await alice.close();
      await waitFor(() => received().contains(RoomNotice.leftRoom));
      expect(received(), [
        RoomNotice.joinedRoom,
        RoomNotice.matchingPlayers,
        RoomNotice.leftGame,
        RoomNotice.leftRoom,
      ]);
    } finally {
      game?.dispose();
      opponent?.dispose();
      await h.close();
    }
  });
}

class _Chat implements ChatChannel {
  @override
  int get identity => 2;
  @override
  String get userName => 'Bob';
  @override
  final messageList = ListNotifier<NetworkMessage>([]);
  @override
  void sendText(String text) {}

  void dispose() {
    messageList.dispose();
  }
}
