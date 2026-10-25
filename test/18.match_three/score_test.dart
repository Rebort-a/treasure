import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/audio_preferences.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';
import 'package:treasure/18.match_three/upper/game_view.dart';

Map<String, dynamic> _winningState() {
  final data = MatchBoard.random(seed: 7).toJson()
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
    ..['movesLeft'] = 3
    ..['score'] = 0;
  data['moveNumber'] = data['initialMoves'] - 3;
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
    manager.swap(10, 2);
    expect(manager.busy.value, isTrue);
    for (var step = 0; step < 120 && manager.busy.value; step++) {
      expect(replay, findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
    }
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

  for (final scenario in [
    (name: '奖励', state: _winningState, swap: (10, 2), isBonus: true),
    (name: '彩虹', state: _rainbowState, swap: (0, 1), isBonus: false),
  ]) {
    testWidgets('${scenario.name}连线到达后才转换，重开取消旧连线通知', (tester) async {
      final manager = MatchManager(seed: 7);
      addTearDown(manager.dispose);
      final data = scenario.state();
      manager.loadState(data);
      manager.swap(scenario.swap.$1, scenario.swap.$2);
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
      expect(transfer.transferSourcePieceId, scenario.isBonus ? isNull : 1);
      for (final piece in transfer.pieces.whereType<Piece>()) {
        if (targets.contains(piece.id)) expect(piece.effect, PieceEffect.none);
      }
      expect(manager.canInteract, isFalse);
      await tester.pump();
      expect(manager.view.value!.frame, same(transfer));
      manager.finishConversionTransfer(transfer);
      await tester.pump();
      final converted = manager.view.value!.frame;
      expect(
        converted.phase,
        scenario.isBonus ? FramePhase.bonus : FramePhase.transform,
      );
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
      manager.swap(scenario.swap.$1, scenario.swap.$2);
      await reachTransfer();
      final newTransfer = manager.view.value!.frame;
      manager.finishConversionTransfer(transfer);
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
  }

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
