import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/client/net_turn_engine.dart';
import 'package:treasure/00.common/l10n/app_localizations.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/model/chat_message.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/model/notifiers.dart';
import 'package:treasure/00.common/widget/component/chat_component.dart';

import 'support/network_room_harness.dart';
import 'support/match_game_driver.dart';

const _english = [
  'Alice Joined the room',
  'Alice Left the room',
  'Alice Matching players',
  'Alice Room closed',
];
const _chinese = ['Alice 加入了房间', 'Alice 离开了房间', 'Alice 正在匹配玩家', 'Alice 房间已关闭'];

NetworkMessage _notice(NoticeType type) {
  final needsMember = type != NoticeType.close;
  return NetworkMessage(
    id: 0,
    type: MessageType.notify,
    source: 'Alice',
    content: RoomNotification(
      type: type,
      memberId: needsMember ? 1 : null,
      memberName: needsMember ? 'Alice' : null,
    ).content,
    timestamp: 1234567890000 + type.index,
  );
}

Widget _chat(Locale locale, _Chat channel) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: MessageList(
      identity: channel.identity,
      userName: channel.userName,
      messageList: channel.messageList,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LanguageProvider.instance.resetForTesting());
  tearDown(() => LanguageProvider.instance.resetForTesting());

  test('通知使用固定编码，序列化往返不携带翻译文本', () {
    expect(NoticeType.values.map((type) => type.code), [1, 2, 3, 4]);
    for (final notificationType in NoticeType.values) {
      final wire = _notice(notificationType)
          .toSocketData(encryptionKey: 'room-key');
      final restored = NetworkMessage.fromSocketData(
        wire,
        encryptionKey: 'room-key',
      )!;
      expect(
        RoomNotification.tryFromContent(restored.content)?.type,
        notificationType,
      );
      expect(
        ChatMessage.fromNetworkMessage(restored, 2, 'Bob').notificationType,
        notificationType,
      );
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
      '{"notice":1}',
      '{"notice":999}',
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
        'timestamp': 1,
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
      timestamp: 1,
    );
    final chat = ChatMessage.fromNetworkMessage(text, 2, 'Bob');
    expect(chat.content, '1');
    expect(chat.notificationType, isNull);
    expect(chat.isSystem, isFalse);
  });

  testWidgets('同一组消息在两个不同语言的界面中分别本地化', (tester) async {
    final english = _Chat();
    final chinese = _Chat();
    try {
      for (final channel in [english, chinese]) {
        channel.messageList.addAll(NoticeType.values.map(_notice));
        channel.messageList.add(
          NetworkMessage(
            id: 1,
            type: MessageType.text,
            source: 'Alice',
            content: 'Joined the room',
            timestamp: 1,
          ),
        );
        channel.messageList.add(
          NetworkMessage(
            id: 1,
            type: MessageType.text,
            source: 'Alice',
            content: '1',
            timestamp: 1,
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
    channel.messageList.addAll(NoticeType.values.map(_notice));
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

  test('房间加入、搜索和断开通知均由服务端发送，搜索同时原样转发', () async {
    HttpOverrides.global = null;
    final h = RoomHarness(3);
    NetTurnEngine? game;
    NetTurnEngine? opponent;
    await h.server.start();
    try {
      final observer = await h.join('Observer');
      await LanguageProvider.instance.setLocale(AppLocale.zh);
      final alice = await h.join('Alice');
      final wire = <NetworkMessage>[];
      observer.addMessageListener(wire.add);
      List<NoticeType?> received() => observer.messageList.value
          .where((m) => m.type == MessageType.notify && m.source == 'Alice')
          .map((m) => RoomNotification.tryFromContent(m.content)?.type)
          .toList();
      await waitFor(() => received().contains(NoticeType.join));
      final joined = observer.messageList.value.firstWhere(
        (message) =>
            message.type == MessageType.notify &&
            message.source == 'Alice' &&
            RoomNotification.tryFromContent(message.content)?.type ==
                NoticeType.join,
      );
      expect(joined.id, 0);
      expect(
        RoomNotification.tryFromContent(joined.content)?.type,
        NoticeType.join,
      );
      expect(
        RoomNotification.tryFromContent(joined.content)?.memberId,
        alice.identity,
      );
      game = startGame(
        configureTurnEngine(
          room: alice,
          resourceMode: TurnResourceMode.none,
          actionHandler: (_, __) {},
          exitHandler: () {},
        ),
      );
      // 搜索同时产生展示通知和原样转发的原始消息。
      await waitFor(() => received().contains(NoticeType.search));
      await waitFor(
        () => wire.any(
          (message) =>
              message.type == MessageType.search &&
              message.id == alice.identity,
        ),
      );
      opponent = startGame(
        configureTurnEngine(
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
      game.finishGame();
      await alice.close();
      await waitFor(() => received().contains(NoticeType.left));
      expect(received(), [NoticeType.join, NoticeType.search, NoticeType.left]);
    } finally {
      game?.releaseGame();
      opponent?.releaseGame();
      await h.close();
    }
  });

  test('房主关闭房间时服务端发送特殊样式通知', () async {
    final h = RoomHarness(0);
    await h.server.start();
    final room = await h.join('Observer');
    try {
      await h.server.stop();
      await waitFor(
        () => room.messageList.value.any(
          (message) =>
              message.type == MessageType.notify &&
              RoomNotification.tryFromContent(message.content)?.type ==
                  NoticeType.close,
        ),
      );
      expect(room.messageList.value.last.id, 0);
    } finally {
      await h.close();
    }
  });
}

class _Chat {
  int get identity => 2;
  String get userName => 'Bob';
  final messageList = ListNotifier<NetworkMessage>([]);
  void dispose() {
    messageList.dispose();
  }
}
