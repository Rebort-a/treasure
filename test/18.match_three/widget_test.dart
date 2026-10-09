import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/network/client/net_multi_turn_engine.dart';
import 'package:treasure/00.common/network/client/socket_client.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';
import 'package:treasure/18.match_three/upper/match_board_widget.dart';

/// 只提供界面测试所需的成员表，不启动真实匹配。
class _HeaderEngine extends NetMultiTurnEngine {
  _HeaderEngine(super.client);

  @override
  Map<int, String> get participants => const {1: '测试玩家', 2: 'bb'};
}

Widget _app(
  MatchManager manager, {
  bool reduceMotion = true,
  bool dark = false,
  double textScale = 1,
  GlobalKey? boundary,
}) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: dark ? Brightness.dark : Brightness.light,
    ),
  ),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: RepaintBoundary(
        key: boundary,
        child: MatchGameView(manager: manager, onExit: () {}),
      ),
    ),
  ),
);

Future<Uint8List> _pixels(
  WidgetTester tester,
  GlobalKey key, {
  ImageByteFormat format = ImageByteFormat.rawRgba,
}) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(format: format))!;
      return Uint8List.fromList(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  setUp(() => LanguageProvider.instance.resetForTesting());

  testWidgets('单机顶部只显示步数和当前分数，不显示分数进度条或联机板', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    expect(find.text(S.matchScore), findsOneWidget);
    expect(find.text('${manager.view.value!.score}'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(S.matchYourTurn), findsNothing);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('联机回合提示简短且信息列与数字列等宽', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(S.matchYourTurn, 'Your turn');
    expect(S.matchPlayerTurn('bb'), "bb's turn");
    LanguageProvider.instance.locale.value = AppLocale.zh;
    final client = SocketClient(
      userName: '测试玩家',
      endpoint: RoomInfo(
        name: 'Test',
        type: 18,
        address: '127.0.0.1',
        port: 1,
        encryptionKey: 'test-key',
      ),
    );
    // 仅测试布局，不连接服务器，也不启动匹配流程。
    client.identityNotifier.value = 1;
    client.status.value = const RoomStatus(RoomConnectionState.joined);
    final engine = _HeaderEngine(client);
    engine.currentPlayer.value = engine.identity;
    final manager = MatchManager(seed: 7);
    addTearDown(() {
      engine.dispose();
      client.dispose();
      manager.dispose();
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: MatchGameView(
              manager: manager,
              engine: engine,
              onExit: () {},
            ),
          ),
        ),
      ),
    );
    expect(S.matchYourTurn, '你的回合');
    expect(find.text(S.matchYourTurn), findsOneWidget);
    final teamColumn = find
        .ancestor(of: find.text(S.matchYourTurn), matching: find.byType(Column))
        .first;
    final scoreColumn = find
        .ancestor(of: find.text(S.matchScore), matching: find.byType(Column))
        .first;
    expect(
      tester.getSize(teamColumn).width,
      closeTo(tester.getSize(scoreColumn).width, 0.01),
    );
    final text = tester.widget<Text>(find.text(S.matchYourTurn));
    final painter = TextPainter(
      text: TextSpan(text: text.data, style: text.style),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThanOrEqualTo(tester.getSize(teamColumn).width));
    painter.dispose();
    engine.currentPlayer.value = 2;
    manager.refreshView();
    await tester.pump();
    expect(find.text('bb 的回合'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text(S.matchYourTurn), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('目标条目左侧是图标，右侧两行显示名称与数字', (tester) async {
    final manager = MatchManager(seed: 100);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    await tester.pump();
    final view = manager.view.value!;

    // 第一行是动物名称，第二行是原来的收集进度。
    final entries = view.targets.entries.toList();
    for (final entry in entries) {
      expect(find.text(S.matchAnimalNames[entry.key]), findsOneWidget);
      expect(
        find.text(
          '${view.collected[entry.key].clamp(0, entry.value)} / ${entry.value}',
        ),
        findsOneWidget,
      );
    }
    // 名称与数字都靠左，两行占同一宽度。
    final first = entries.first;
    final label = find.text(S.matchAnimalNames[first.key]);
    final value = find.text(
      '${view.collected[first.key].clamp(0, first.value)} / ${first.value}',
    );
    expect(
      tester.renderObject<RenderParagraph>(label).textAlign,
      TextAlign.left,
    );
    expect(
      tester.renderObject<RenderParagraph>(value).textAlign,
      TextAlign.left,
    );
    expect(tester.getSize(label).width, tester.getSize(value).width);
    // 冰块目标第一行显示剩余冰块，第二行是冰块数量。
    expect(find.text(S.matchIceLeft), findsOneWidget);
    expect(find.text('${view.iceLeft}'), findsWidgets);
    expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('随机目标与棋盘可见，交换与重开均有效', (tester) async {
    final manager = MatchManager(seed: 100);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    expect(find.byType(MatchBoardWidget), findsOneWidget);
    expect(find.text(S.matchThree), findsOneWidget);
    expect(manager.board!.pieces.length, 64);
    final before = manager.board!.seed;
    final swap = manager.board!.legalMoves.first;
    await tester.ensureVisible(find.byKey(const ValueKey('match-board')));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('match-board')));
    final cell = rect.width / MatchBoard.side;
    Offset center(int index) =>
        rect.topLeft +
        Offset((index % 8 + 0.5) * cell, (index ~/ 8 + 0.5) * cell);
    await tester.tapAt(center(swap.$1));
    await tester.tapAt(center(swap.$2));
    await tester.pump();
    expect(manager.board!.moveNumber, 1);
    expect(manager.comboPraise.value, isNotNull);
    expect(
      {
        'Good',
        'Great',
        'Excellent',
        'Amazing',
        'Unbelievable',
      }.contains(manager.comboPraise.value),
      isTrue,
    );
    expect(find.text(manager.comboPraise.value!), findsOneWidget);
    expect(manager.busy.value, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(manager.busy.value, isFalse);
    await tester.tap(find.byKey(const ValueKey('match-restart')));
    await tester.pump();
    expect(manager.board!.seed, isNot(before));
    expect(manager.board!.moveNumber, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滑动交换只推进一步，左右边界不会跨行', (tester) async {
    final manager = MatchManager(seed: 123);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager));
    await tester.ensureVisible(find.byKey(const ValueKey('match-board')));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('match-board')));
    final cell = rect.width / 8;
    final swap = manager.board!.legalMoves.first;
    Offset center(int index) =>
        rect.topLeft +
        Offset((index % 8 + 0.5) * cell, (index ~/ 8 + 0.5) * cell);
    await tester.dragFrom(center(swap.$1), center(swap.$2) - center(swap.$1));
    await tester.pump();
    expect(manager.board!.moveNumber, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.dragFrom(center(7), Offset(cell, 0));
    await tester.pump();
    expect(manager.board!.moveNumber, 1);
  });

  testWidgets('无效交换会短暂移动动物后复位且不消耗步数', (tester) async {
    final manager = MatchManager(seed: 100);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    final board = manager.board!;
    final invalidSwap = [
      for (var index = 0; index < MatchBoard.cells; index++)
        if (index % MatchBoard.side < MatchBoard.side - 1 &&
            board.ice[index] == 0 &&
            board.ice[index + 1] == 0 &&
            !board.canSwap(index, index + 1))
          (index, index + 1),
      for (var index = 0; index < MatchBoard.cells - MatchBoard.side; index++)
        if (board.ice[index] == 0 &&
            board.ice[index + MatchBoard.side] == 0 &&
            !board.canSwap(index, index + MatchBoard.side))
          (index, index + MatchBoard.side),
    ].first;
    final pieceId = board.pieces[invalidSwap.$1]!.id;
    await tester.pumpWidget(_app(manager, reduceMotion: false));
    await tester.ensureVisible(find.byKey(const ValueKey('match-board')));
    await tester.pump();
    final piece = find.byKey(ValueKey('piece-$pieceId'));
    final originalPosition = tester.getTopLeft(piece);

    manager.swap(invalidSwap.$1, invalidSwap.$2);
    expect(manager.board!.moveNumber, 0);
    expect(manager.canInteract, isFalse);
    expect(manager.invalidSwapAnimating.value, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getTopLeft(piece), isNot(originalPosition));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('match-multiplier')),
        matching: find.text('0'),
        matchRoot: true,
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 90));
    expect(manager.invalidSwap.value, isNull);
    expect(manager.invalidSwapAnimating.value, isTrue);
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getTopLeft(piece), originalPosition);
    expect(manager.canInteract, isTrue);
    expect(manager.invalidSwapAnimating.value, isFalse);
    expect(find.byKey(const ValueKey('match-multiplier')), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('窄屏、大字体和深浅主题不溢出（深色：$dark）', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manager = MatchManager(seed: 99);
      addTearDown(manager.dispose);
      // 本测试聚焦稳定棋盘，先完成开局入场。
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpWidget(_app(manager, dark: dark, textScale: 2));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MatchBoardWidget), findsOneWidget);
    });
  }

  testWidgets('待机时棋子真实重绘，减少动画设置下画面保持静止', (tester) async {
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final manager = MatchManager(seed: 42);
    addTearDown(manager.dispose);
    // 本测试聚焦稳定棋盘，先完成开局入场。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    final key = GlobalKey();
    await tester.pumpWidget(_app(manager, reduceMotion: false, boundary: key));
    final moving = await _pixels(tester, key);
    await tester.pump(const Duration(milliseconds: 850));
    expect(await _pixels(tester, key), isNot(orderedEquals(moving)));
    await tester.pumpWidget(_app(manager, boundary: key));
    await tester.pump();
    final still = await _pixels(tester, key);
    await tester.pump(const Duration(seconds: 1));
    expect(await _pixels(tester, key), orderedEquals(still));
    // 可选导出预览，不将验证图片或额外产物写进项目。
    final previewPath = Platform.environment['TREASURE_MATCH_PREVIEW'];
    if (previewPath != null) {
      final bytes = await _pixels(tester, key, format: ImageByteFormat.png);
      await tester.runAsync(() => File(previewPath).writeAsBytes(bytes));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('结算动画中卸载后不再写通知器或遗留 ticker', (tester) async {
    final manager = MatchManager(seed: 9);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpWidget(_app(manager, reduceMotion: false));
    final swap = manager.board!.legalMoves.first;
    manager.swap(swap.$1, swap.$2);
    expect(manager.busy.value, isTrue);
    expect(manager.comboMultiplier.value, isNotNull);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });
}
