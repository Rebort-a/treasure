import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/audio_preferences.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';

Map<String, dynamic> _winningState({int seed = 7, int moves = 3}) {
  final data = MatchBoard.random(seed: seed).toJson()
    ..['pieces'] = [
      for (var index = 0; index < MatchBoard.cells; index++)
        [
          index + 1,
          {0: 0, 1: 0, 2: 1, 3: 0, 10: 0}[index] ??
              (index ~/ MatchBoard.side * 2 + index % MatchBoard.side) %
                  MatchBoard.kinds,
          PieceEffect.none.index,
        ],
    ]
    ..['nextId'] = MatchBoard.cells + 1
    ..['ice'] = List.filled(MatchBoard.cells, 0)
    ..['targets'] = {'0': 1, '1': 1}
    ..['collected'] = [0, 1, 0, 0, 0, 0]
    ..['movesLeft'] = moves
    ..['score'] = 0;
  data['moveNumber'] = data['initialMoves'] - moves;
  return data;
}

Map<String, dynamic> _rainbowState() => _winningState()
  ..['targets'] = {'0': 1000, '1': 1000}
  ..['pieces'] = [
    for (var index = 0; index < MatchBoard.cells; index++)
      [
        index + 1,
        (index ~/ MatchBoard.side * 2 + index % MatchBoard.side) %
            MatchBoard.kinds,
        (index == 0
                ? PieceEffect.rainbow
                : index == 1
                ? PieceEffect.bomb
                : PieceEffect.none)
            .index,
      ],
  ];

void main() {
  testWidgets('无效交换提供一次振动反馈，关闭振动后不触发', (tester) async {
    final manager = MatchManager(seed: 7)..reduceMotion = true;
    manager.loadState(_rainbowState());
    final vibration = AudioPreferences.instance.vibrationEnabled;
    final original = vibration.value;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      vibration.value = original;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      manager.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MatchGameView(manager: manager, onExit: () {}),
      ),
    );
    // 选取相邻但无法消除的普通棋子，走实际的无效交换流程。
    final board = manager.board!;
    final from = List.generate(MatchBoard.cells - 1, (i) => i).firstWhere(
      (i) =>
          board.adjacent(i, i + 1) &&
          board.ice[i] == 0 &&
          board.ice[i + 1] == 0 &&
          !board.canSwap(i, i + 1),
    );
    vibration.value = true;
    manager.swap(from, from + 1);
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    vibration.value = false;
    manager.swap(from, from + 1);
    await tester.pump();
    expect(calls, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
  });

  testWidgets('通关结算结束后可重开，结算期间不开放重开入口', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    await tester.pumpWidget(
      MaterialApp(
        home: MatchGameView(manager: manager, onExit: () {}),
      ),
    );
    final replay = find.byKey(const ValueKey('round-replay'));
    final multiplier = find.byKey(const ValueKey('match-multiplier'));
    var sawMultiplier = false;
    var sawCelebration = false;
    manager.swap(10, 2);
    expect(manager.busy.value, isTrue);
    for (var step = 0; step < 120 && manager.busy.value; step++) {
      expect(replay, findsNothing);
      sawMultiplier |= multiplier.evaluate().isNotEmpty;
      if (manager.winCelebration.value && multiplier.evaluate().isNotEmpty) {
        sawCelebration = true;
        expect(manager.bonusTime.value, isFalse);
      }
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(sawMultiplier, isTrue);
    expect(sawCelebration, isTrue);
    expect(manager.busy.value, isFalse);
    expect(manager.bonusTime.value, isFalse);
    expect(manager.view.value!.status, MatchStatus.won);
    expect(manager.view.value!.score, manager.board!.score);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(replay, findsOneWidget);
    await tester.ensureVisible(replay);
    await tester.tap(replay);
    await tester.pump();
    expect(manager.view.value!.status, MatchStatus.playing);
    expect(manager.view.value!.score, 0);
    expect(replay, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
    await tester.pump();
  });

  testWidgets('减少动画模式仍能结算、重开和清空联机状态', (tester) async {
    final manager = MatchManager(seed: 7)..reduceMotion = true;
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    manager.swap(10, 2);
    for (var step = 0; step < 20 && manager.busy.value; step++) {
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(manager.busy.value, isFalse);
    expect(manager.view.value!.status, MatchStatus.won);
    expect(manager.view.value!.score, manager.board!.score);
    manager.restart(seed: 7);
    expect(manager.view.value!.score, 0);
    manager.resetNetworkRound();
    expect(manager.view.value, isNull);
  });

  testWidgets('彩虹连线到达后才转换，重开取消旧连线通知', (tester) async {
    final manager = MatchManager(seed: 7);
    addTearDown(manager.dispose);
    final data = _rainbowState();
    manager.loadState(data);
    manager.swap(0, 1);
    Future<void> reachTransfer() async {
      for (var i = 0; i < 120; i++) {
        if (manager.view.value!.frame.phase == FramePhase.transfer) {
          return;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail('未进入转换连线阶段');
    }

    await reachTransfer();
    final transfer = manager.view.value!.frame;
    final targets = transfer.transferringPieceIds;
    expect(targets, isNotEmpty);
    expect(transfer.transferSourcePieceId, 1);
    for (final piece in transfer.pieces.whereType<Piece>()) {
      if (targets.contains(piece.id)) expect(piece.effect, PieceEffect.none);
    }
    expect(manager.canInteract, isFalse);
    await tester.pump();
    expect(manager.view.value!.frame, same(transfer));
    manager.finishBoardAnimation(transfer);
    await tester.pump();
    final converted = manager.view.value!.frame;
    expect(converted.phase, FramePhase.transform);
    expect(converted.convertedPieceIds, targets);
    expect(converted.score - transfer.score, targets.length * 40);
    expect(converted.movesLeft, transfer.movesLeft);
    for (final piece in converted.pieces.whereType<Piece>()) {
      if (targets.contains(piece.id)) {
        expect(
          piece.effect,
          anyOf(PieceEffect.row, PieceEffect.column, PieceEffect.bomb),
        );
      }
    }
    expect(manager.busy.value, isTrue);
    manager.loadState(data);
    manager.swap(0, 1);
    await reachTransfer();
    final newTransfer = manager.view.value!.frame;
    manager.finishBoardAnimation(transfer);
    await tester.pump();
    expect(manager.view.value!.frame, same(newTransfer));
    manager.restart(seed: 9);
    await tester.pump(const Duration(seconds: 30));
    expect(manager.view.value!.seed, 9);
    expect(manager.view.value!.score, 0);
    expect(manager.busy.value, isFalse);
    expect(manager.bonusTime.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('奖励转换与自然连锁并行，补块三连按普通节奏触发：$reduceMotion', (tester) async {
      final manager = MatchManager(generate: false)
        ..reduceMotion = reduceMotion
        ..loadState(_winningState(seed: 55, moves: 5));
      addTearDown(manager.dispose);
      final transfers = <(DateTime, BoardFrame)>[];
      final conversions = <(DateTime, BoardFrame)>[];
      final clears = <(DateTime, BoardFrame)>[];
      final falls = <(DateTime, BoardFrame)>[];
      DateTime? openedAt;
      manager.view.addListener(() {
        if (!manager.bonusTime.value) return;
        final frame = manager.view.value!.frame;
        final event = (tester.binding.clock.now(), frame);
        if (frame.phase == FramePhase.bonus) openedAt ??= event.$1;
        if (frame.phase == FramePhase.transfer) transfers.add(event);
        if (frame.convertedPieceIds.isNotEmpty) conversions.add(event);
        if (frame.phase == FramePhase.clear) clears.add(event);
        if (frame.phase == FramePhase.fall) falls.add(event);
      });

      manager.swap(10, 2);
      for (var i = 0; i < 1500 && manager.busy.value; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(transfers, hasLength(4));
      expect(conversions, hasLength(4));
      expect(
        transfers.first.$1.difference(openedAt!),
        const Duration(milliseconds: BonusTiming.firstTransfer),
      );
      const conversionInterval = Duration(
        milliseconds: BonusTiming.transferInterval,
      );
      final ignitionTimes = <DateTime>[];
      for (var i = 0; i < conversions.length; i++) {
        final (transferTime, transfer) = transfers[i];
        final (convertedAt, conversion) = conversions[i];
        final id = conversion.convertedPieceIds.single;
        expect(transfer.movesLeft, 3 - i);
        expect(conversion.movesLeft, transfer.movesLeft);
        expect(
          convertedAt.difference(transferTime),
          manager.transferDuration(transfer),
        );
        final (ignitedAt, _) = clears.singleWhere(
          (event) => event.$2.clearing.any(
            (index) => event.$2.pieces[index]?.id == id,
          ),
        );
        expect(
          ignitedAt.difference(convertedAt),
          const Duration(milliseconds: BonusTiming.ignition),
        );
        ignitionTimes.add(ignitedAt);
        if (i > 0) {
          expect(
            transferTime.difference(transfers[i - 1].$1),
            conversionInterval,
          );
        }
      }
      final naturalClears = clears.where((event) => event.$2.naturalClear);
      expect(
        naturalClears.any((event) {
          final clearedAt = event.$1;
          final refillAt = clearedAt.add(MatchManager.clearAnimationDuration);
          return ignitionTimes.any(
            (time) => time.isAfter(clearedAt) && time.isBefore(refillAt),
          );
        }),
        isTrue,
      );
      // 至少一拍在自然消除或它引起的坠落中开始，不只是和主动引爆重叠。
      expect(
        naturalClears.any((event) {
          final clearedAt = event.$1;
          final (refillAt, _) = falls.firstWhere(
            (fall) => fall.$1.isAfter(clearedAt),
          );
          final landedAt = refillAt.add(MatchManager.fallAnimationDuration);
          return transfers.any(
            (transfer) =>
                !transfer.$1.isBefore(clearedAt) &&
                transfer.$1.isBefore(landedAt),
          );
        }),
        isTrue,
      );
      for (final (clearedAt, _) in naturalClears) {
        final (fallAt, _) = falls.lastWhere(
          (event) => event.$1.isBefore(clearedAt),
        );
        expect(
          clearedAt.difference(fallAt),
          const Duration(milliseconds: BonusTiming.fall),
        );
      }
      // 两波消除重叠时，按棋子身份找本波对应的补块帧。
      for (final (clearedAt, wave) in clears) {
        final ids = {for (final cell in wave.clearing) wave.pieces[cell]!.id};
        final (refillAt, _) = falls.firstWhere(
          (event) =>
              event.$1.isAfter(clearedAt) &&
              !event.$2.pieces.whereType<Piece>().any(
                (piece) => ids.contains(piece.id),
              ),
        );
        expect(
          refillAt.difference(clearedAt),
          MatchManager.clearAnimationDuration,
        );
      }
      expect(manager.roundSettled, isTrue);
      expect(manager.view.value!.movesLeft, 0);
      expect(manager.view.value!.score, manager.board!.score);
    });
  }

  testWidgets('完整坠落模式先落稳再扣步连线，连线结束后才转换', (tester) async {
    final data = _winningState();
    final expected = MatchBoard.fromJson(data)
      ..playSwap(10, 2, bonusPacing: BonusPacing.waitForFall);
    final manager = MatchManager(
      generate: false,
      bonusPacing: BonusPacing.waitForFall,
    )..loadState(data);
    addTearDown(manager.dispose);

    manager.swap(10, 2);
    for (var i = 0; i < 200; i++) {
      if (manager.bonusTime.value &&
          manager.view.value!.frame.phase == FramePhase.fall) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 20));
    }
    final fall = manager.view.value!.frame;
    expect(fall.phase, FramePhase.fall);
    expect(fall.spawnedPieceIds, isNotEmpty);
    expect(fall.movesLeft, 2);

    await tester.pump(MatchManager.fallAnimationDuration);
    expect(manager.view.value!.frame, same(fall));
    manager.finishBoardAnimation(fall);
    await tester.pump();
    final transfer = manager.view.value!.frame;
    expect(transfer.phase, FramePhase.transfer);
    expect(transfer.spawnedPieceIds, isEmpty);
    expect(transfer.movesLeft, 1);

    manager.finishBoardAnimation(fall);
    await tester.pump();
    expect(manager.view.value!.frame, same(transfer));
    manager.finishBoardAnimation(transfer);
    await tester.pump();
    final conversion = manager.view.value!.frame;
    expect(conversion.convertedPieceIds, transfer.transferringPieceIds);
    await tester.pump(const Duration(milliseconds: BonusTiming.ignition - 1));
    expect(manager.view.value!.frame, same(conversion));
    await tester.pump(const Duration(milliseconds: 1));
    expect(manager.view.value!.frame.phase, FramePhase.clear);

    // 没有界面回调时，后续动画仍会通过超时保护正常结算。
    for (var i = 0; i < 200 && manager.busy.value; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(manager.roundSettled, isTrue);
    expect(manager.view.value!.score, expected.score);
    expect(manager.saveState(), expected.toJson());
  });

  testWidgets('减少动画时彩虹转换仍保留展示状态，重开取消待触发的旧局', (tester) async {
    final manager = MatchManager(seed: 7)..reduceMotion = true;
    addTearDown(manager.dispose);
    final data = _rainbowState();
    manager.loadState(data);
    manager.swap(0, 1);
    expect(manager.busy.value, isTrue);
    expect(manager.view.value!.frame.phase, FramePhase.transform);
    expect(manager.view.value!.frame.convertedPieceIds, isNotEmpty);
    expect(manager.bonusTime.value, isFalse);
    expect(manager.canInteract, isFalse);

    await tester.pump(const Duration(seconds: 5));
    expect(manager.busy.value, isFalse);
    expect(manager.view.value!.frame.phase, FramePhase.settled);
    expect(manager.view.value!.score, manager.board!.score);
    expect(manager.canInteract, isTrue);

    manager.loadState(data);
    manager.swap(0, 1);
    expect(manager.busy.value, isTrue);
    manager.restart(seed: 9);
    await tester.pump(const Duration(seconds: 30));
    expect(manager.view.value!.seed, 9);
    expect(manager.view.value!.score, 0);
    expect(manager.busy.value, isFalse);
    expect(manager.bonusTime.value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
