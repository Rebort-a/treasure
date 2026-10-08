import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';

MatchBoard _pattern(
  Map<int, int> overrides, {
  Map<int, PieceEffect> effects = const {},
  Set<int> frozen = const {},
}) {
  final data = MatchBoard.random(seed: 7).toJson();
  data['pieces'] = [
    for (var i = 0; i < MatchBoard.cells; i++)
      [
        i + 1,
        overrides[i] ?? (i ~/ 8 * 2 + i % 8) % 6,
        (effects[i] ?? PieceEffect.none).index,
      ],
  ];
  data['nextId'] = 65;
  data['ice'] = [for (var i = 0; i < 64; i++) frozen.contains(i) ? 1 : 0];
  return MatchBoard.fromJson(data);
}

void main() {
  test('随机生成没有预消除，至少有一步可走，目标和棋盘随种子变化', () {
    final boards = <String>{};
    final goals = <String>{};
    for (var seed = 0; seed < 200; seed++) {
      final board = MatchBoard.random(seed: seed);
      expect(board.matchRuns(), isEmpty);
      expect(board.legalMoves, isNotEmpty);
      expect(board.pieces.whereType<Piece>().length, 64);
      expect(board.pieces.map((piece) => piece!.id).toSet().length, 64);
      expect(board.iceLeft, inInclusiveRange(10, 16));
      boards.add(jsonEncode(board.toJson()['pieces']));
      goals.add(jsonEncode(board.toJson()['targets']));
    }
    expect(boards.length, 200);
    expect(goals.length, greaterThan(20));
  });

  test('无效或越界交换不扣步数，不改变任何状态或随机序列', () {
    final board = MatchBoard.random(seed: 17);
    final before = jsonEncode(board.toJson());
    for (final swap in [(-1, 0), (0, 64), (7, 8), (0, 0), (0, 2)]) {
      expect(board.playSwap(swap.$1, swap.$2), isNull);
    }
    final invalid = [
      for (var i = 0; i < 63; i++)
        if (board.adjacent(i, i + 1) && !board.canSwap(i, i + 1)) (i, i + 1),
    ].first;
    expect(board.playSwap(invalid.$1, invalid.$2), isNull);
    expect(jsonEncode(board.toJson()), before);
  });

  test('所有连锁只消耗一步，棋盘完整、可继续，快照恢复后的随机序列一致', () {
    for (var seed = 1; seed <= 30; seed++) {
      final board = MatchBoard.random(seed: seed);
      for (
        var step = 0;
        step < 15 && board.status == MatchStatus.playing;
        step++
      ) {
        final mirror = MatchBoard.fromJson(
          jsonDecode(jsonEncode(board.toJson())),
        );
        final swap = board.legalMoves[(seed + step) % board.legalMoves.length];
        final previousMoves = board.movesLeft;
        final result = board.playSwap(swap.$1, swap.$2)!;
        mirror.playSwap(swap.$1, swap.$2);
        expect(board.movesLeft, previousMoves - 1);
        expect(result.cascades, greaterThanOrEqualTo(1));
        expect(result.scoreGained, greaterThan(0));
        expect(board.matchRuns(), isEmpty);
        expect(board.legalMoves, isNotEmpty);
        expect(board.pieces.every((piece) => piece != null), isTrue);
        expect(board.pieces.map((piece) => piece!.id).toSet().length, 64);
        expect(jsonEncode(board.toJson()), jsonEncode(mirror.toJson()));
      }
    }
  });

  test('四连在交换落点生成直线特效，消除动物并破除冰层', () {
    final board = _pattern({0: 0, 1: 0, 2: 1, 3: 0, 10: 0}, frozen: {4});
    expect(board.canSwap(4, 5), isFalse);
    expect(board.playSwap(4, 5), isNull);
    final result = board.playSwap(10, 2)!;
    final frame = result.frames.firstWhere(
      (frame) => frame.phase == FramePhase.clear,
    );
    expect(frame.pieces[2]!.effect, PieceEffect.row);
    expect(frame.clearing.contains(2), isFalse);
    expect(frame.clearing.containsAll({0, 1, 3}), isTrue);
    expect(frame.clearing.contains(4), isFalse);
    expect(frame.pieces[4], isNotNull);
    expect(frame.ice[4], 0);
    expect(board.collected[0], greaterThanOrEqualTo(3));
    expect(board.iceLeft, lessThan(64));
  });

  test('五连生成彩虹，T 形生成炸弹', () {
    final five = _pattern({0: 0, 1: 0, 2: 1, 3: 0, 4: 0, 10: 0});
    final rainbow = five.playSwap(10, 2)!;
    expect(
      rainbow.frames
          .firstWhere((frame) => frame.phase == FramePhase.clear)
          .pieces[2]!
          .effect,
      PieceEffect.rainbow,
    );
    final tee = _pattern({1: 0, 9: 0, 16: 0, 17: 1, 18: 0, 25: 0});
    final bomb = tee.playSwap(25, 17)!;
    expect(
      bomb.frames
          .firstWhere((frame) => frame.phase == FramePhase.clear)
          .pieces[17]!
          .effect,
      PieceEffect.bomb,
    );
  });

  test('彩虹与动物交换清除该种动物，双彩虹清全盘，两个特效可直接交换', () {
    final board = _pattern({}, effects: {0: PieceEffect.rainbow});
    final kind = board.pieces[1]!.kind;
    final expected = [
      for (var i = 0; i < 64; i++)
        if (board.pieces[i]!.kind == kind) i,
    ];
    final result = board.playSwap(0, 1)!;
    final clear = result.frames
        .firstWhere((frame) => frame.phase == FramePhase.clear)
        .clearing;
    expect(clear.containsAll(expected), isTrue);
    final doubleRainbow = _pattern(
      {},
      effects: {0: PieceEffect.rainbow, 1: PieceEffect.rainbow},
    );
    expect(
      doubleRainbow
          .playSwap(0, 1)!
          .frames
          .firstWhere((frame) => frame.phase == FramePhase.clear)
          .clearing
          .length,
      64,
    );
    final pair = _pattern(
      {},
      effects: {0: PieceEffect.bomb, 1: PieceEffect.row},
    );
    expect(pair.canSwap(0, 1), isTrue);
    expect(pair.playSwap(0, 1)!.scoreGained, greaterThan(0));
  });

  test('炸弹与直线特效交换时以炸弹为中心触发三条直线', () {
    final bombInMatch = _pattern(
      {0: 0, 1: 0, 2: 1, 3: 0, 10: 0},
      effects: {1: PieceEffect.bomb},
    );
    final bombClear = bombInMatch
        .playSwap(10, 2)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear)
        .clearing;
    expect(bombClear, containsAll({0, 1, 3, 8, 9, 10}));
    expect(bombClear, isNot(contains(17)));

    final columnPair = _pattern(
      {},
      effects: {0: PieceEffect.column, 1: PieceEffect.column},
    );
    final columnClear = columnPair
        .playSwap(0, 1)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear)
        .clearing;
    expect(
      columnClear,
      containsAll({
        for (var row = 0; row < 8; row++) ...{row * 8, row * 8 + 1},
      }),
    );

    final rowColumnPair = _pattern(
      {},
      effects: {0: PieceEffect.row, 1: PieceEffect.column},
    );
    final rowColumnClear = rowColumnPair
        .playSwap(0, 1)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear)
        .clearing;
    expect(
      rowColumnClear,
      containsAll({
        for (var col = 0; col < 8; col++) col,
        for (var row = 0; row < 8; row++) row * 8,
      }),
    );

    final lineBombPair = _pattern(
      {},
      effects: {27: PieceEffect.row, 35: PieceEffect.bomb},
    );
    final lineBombClear = lineBombPair
        .playSwap(27, 35)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear)
        .clearing;
    expect(
      lineBombClear,
      containsAll({
        for (var row = 2; row <= 4; row++)
          for (var col = 0; col < 8; col++) row * 8 + col,
      }),
    );
    expect(lineBombClear, isNot(contains(5 * 8)));

    final columnBombPair = _pattern(
      {},
      effects: {27: PieceEffect.column, 28: PieceEffect.bomb},
    );
    final columnBombClear = columnBombPair
        .playSwap(27, 28)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear)
        .clearing;
    expect(
      columnBombClear,
      containsAll({
        for (var row = 0; row < 8; row++)
          for (var col = 2; col <= 4; col++) row * 8 + col,
      }),
    );
    expect(columnBombClear, isNot(contains(3 * 8 + 5)));

    final doubleBomb = _pattern(
      {},
      effects: {27: PieceEffect.bomb, 28: PieceEffect.bomb},
    );
    final doubleBombClear = doubleBomb
        .playSwap(27, 28)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear)
        .clearing;
    expect(
      doubleBombClear,
      equals({
        for (var row = 2; row <= 4; row++)
          for (var col = 2; col <= 5; col++) row * 8 + col,
      }),
    );

    final rainbowLine = _pattern(
      {},
      effects: {0: PieceEffect.rainbow, 1: PieceEffect.row},
    );
    final rainbowLineFrame = rainbowLine
        .playSwap(0, 1)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear);
    final lineKind = rainbowLineFrame.pieces[0]!.kind;
    for (var index = 0; index < MatchBoard.cells; index++) {
      if (rainbowLineFrame.pieces[index]?.kind == lineKind) {
        expect(
          rainbowLineFrame.pieces[index]!.effect,
          anyOf(PieceEffect.row, PieceEffect.column),
        );
      }
    }

    final rainbowBomb = _pattern(
      {},
      effects: {0: PieceEffect.rainbow, 1: PieceEffect.bomb},
    );
    final rainbowBombFrame = rainbowBomb
        .playSwap(0, 1)!
        .frames
        .firstWhere((frame) => frame.phase == FramePhase.clear);
    final bombKind = rainbowBombFrame.pieces[0]!.kind;
    for (var index = 0; index < MatchBoard.cells; index++) {
      if (rainbowBombFrame.pieces[index]?.kind == bombKind) {
        expect(rainbowBombFrame.pieces[index]!.effect, PieceEffect.bomb);
      }
    }
  });

  test('通关后剩余步数进入 Bonus Time 并转成直线特效', () {
    final setup = _pattern({0: 0, 1: 0, 2: 1, 3: 0, 10: 0});
    final data = setup.toJson()
      ..['targets'] = {'0': 1, '1': 1}
      ..['collected'] = [0, 1, 0, 0, 0, 0]
      ..['ice'] = List.filled(MatchBoard.cells, 0)
      ..['score'] = setup.scoreTarget;
    data['movesLeft'] = 3;
    data['moveNumber'] = data['initialMoves'] - 3;
    final board = MatchBoard.fromJson(data);
    final mirror = MatchBoard.fromJson(jsonDecode(jsonEncode(data)));

    final result = board.playSwap(10, 2)!;
    mirror.playSwap(10, 2);

    expect(board.status, MatchStatus.won);
    expect(board.movesLeft, 0);
    expect(board.moveNumber, board.initialMoves);
    expect(jsonEncode(board.toJson()), jsonEncode(mirror.toJson()));
    expect(
      result.frames.any((frame) => frame.phase == FramePhase.bonus),
      isTrue,
    );
    expect(
      result.frames
          .where((frame) => frame.phase == FramePhase.bonus)
          .map((frame) => frame.movesLeft)
          .toList(),
      [1, 0],
    );
    expect(result.initialMatchCount, 4);
    expect(
      result.frames.any(
        (frame) =>
            frame.phase == FramePhase.bonus &&
            frame.pieces.any(
              (piece) =>
                  piece?.effect == PieceEffect.row ||
                  piece?.effect == PieceEffect.column,
            ),
      ),
      isTrue,
    );
  });

  test('步数归零结束，达成全部目标才获胜，结束后不再接受交换', () {
    final data = MatchBoard.random(seed: 15).toJson();
    data['movesLeft'] = 0;
    data['moveNumber'] = data['initialMoves'];
    final lost = MatchBoard.fromJson(data);
    expect(lost.status, MatchStatus.lost);
    final move = lost.legalMoves.first;
    expect(lost.playSwap(move.$1, move.$2), isNull);
    data['score'] = data['scoreTarget'];
    data['collected'] = List.filled(6, 100);
    data['ice'] = List.filled(64, 0);
    expect(MatchBoard.fromJson(data).status, MatchStatus.won);
  });

  test('拒绝坏尺寸、重复棋子 ID、异常计数和无效目标', () {
    final original = MatchBoard.random(seed: 1).toJson();
    Map<String, dynamic> copy() => jsonDecode(jsonEncode(original));
    final short = copy()..['ice'] = [1];
    final duplicate = copy();
    (duplicate['pieces'] as List)[1] = (duplicate['pieces'] as List)[0];
    final counters = copy()..['movesLeft'] = 100;
    final badTarget = copy()..['targets'] = {'6': 10, '0': 12};
    for (final data in [short, duplicate, counters, badTarget]) {
      expect(() => MatchBoard.fromJson(data), throwsFormatException);
    }
  });
}
