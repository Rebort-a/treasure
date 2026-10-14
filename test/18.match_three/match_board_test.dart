import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';

MatchBoard _pattern(
  Map<int, int> overrides, {
  Map<int, PieceEffect> effects = const {},
  Set<int> frozen = const {},
  int seed = 7,
}) {
  final data = MatchBoard.random(seed: seed).toJson();
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

void _expectSpecialsPreservedOrTriggered(List<BoardFrame> frames) {
  for (var i = 0; i < frames.length - 1; i++) {
    final before = frames[i];
    final after = {
      for (final piece in frames[i + 1].pieces.whereType<Piece>())
        piece.id: piece,
    };
    for (var index = 0; index < before.pieces.length; index++) {
      final piece = before.pieces[index];
      if (piece == null || piece.effect == PieceEffect.none) continue;
      final next = after[piece.id];
      if (next == null) {
        expect(before.phase, FramePhase.clear);
        expect(before.clearing, contains(index));
      } else {
        expect(next.effect, piece.effect);
      }
    }
  }
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
        _expectSpecialsPreservedOrTriggered(result.frames);
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

  test('彩虹吸收同色特效时仍触发行列、炸弹和彩虹，并继续展开波及的特效', () {
    for (final effect in [
      PieceEffect.row,
      PieceEffect.column,
      PieceEffect.bomb,
      PieceEffect.rainbow,
    ]) {
      final board = _pattern({}, effects: {0: PieceEffect.rainbow, 31: effect});
      final result = board.playSwap(0, 1)!;
      final clear = result.frames.firstWhere(
        (frame) => frame.phase == FramePhase.clear,
      );
      final affected = switch (effect) {
        PieceEffect.row => {for (var col = 0; col < 8; col++) 24 + col},
        PieceEffect.column => {for (var row = 0; row < 8; row++) row * 8 + 7},
        PieceEffect.bomb => {22, 23, 30, 31, 38, 39},
        _ => {
          for (var index = 0; index < MatchBoard.cells; index++)
            if (clear.pieces[index]?.kind == clear.pieces[31]!.kind) index,
        },
      };
      expect(clear.clearing, containsAll(affected));
      expect(result.specialEffectsTriggered, greaterThanOrEqualTo(2));
    }
    final chained = _pattern(
      {},
      effects: {
        0: PieceEffect.rainbow,
        31: PieceEffect.row,
        30: PieceEffect.rainbow,
      },
    ).playSwap(0, 1)!;
    final clear = chained.frames.firstWhere(
      (frame) => frame.phase == FramePhase.clear,
    );
    expect(
      clear.clearing,
      containsAll({
        for (var index = 0; index < MatchBoard.cells; index++)
          if (clear.pieces[index]?.kind == clear.pieces[30]!.kind) index,
      }),
    );
    expect(chained.specialEffectsTriggered, greaterThanOrEqualTo(3));
  });

  test('彩虹组合只转换同色普通动物，保留已有特效，炸弹和混合直线规则确定', () {
    final lines = <PieceEffect>{};
    var retainedNaturalSpecial = false;
    for (final partner in [
      PieceEffect.bomb,
      PieceEffect.row,
      PieceEffect.column,
    ]) {
      for (var seed = 1; seed <= 6; seed++) {
        final board = _pattern(
          {},
          seed: seed,
          effects: {
            0: PieceEffect.rainbow,
            1: partner,
            7: PieceEffect.row,
            31: PieceEffect.bomb,
          },
        );
        final original = board.pieces.whereType<Piece>().toList();
        final kind = board.pieces[1]!.kind;
        final expected = {
          for (final piece in original)
            if (piece.kind == kind && piece.effect == PieceEffect.none)
              piece.id,
        };
        final mirror = MatchBoard.fromJson(
          jsonDecode(jsonEncode(board.toJson())),
        );
        final result = board.playSwap(0, 1)!;
        mirror.playSwap(0, 1);
        _expectSpecialsPreservedOrTriggered(result.frames);
        expect(jsonEncode(board.toJson()), jsonEncode(mirror.toJson()));
        final converted = result.frames.singleWhere(
          (frame) => frame.phase == FramePhase.transform,
        );
        expect(converted.convertedPieceIds, expected);
        for (final piece in converted.pieces.whereType<Piece>()) {
          if (expected.contains(piece.id)) {
            if (partner == PieceEffect.bomb) {
              expect(piece.effect, PieceEffect.bomb);
            } else {
              expect(piece.effect, anyOf(PieceEffect.row, PieceEffect.column));
              lines.add(piece.effect);
            }
          } else {
            expect(
              piece.effect,
              original.singleWhere((old) => old.id == piece.id).effect,
            );
          }
        }
        final initialSpecialIds = {
          for (final piece in original)
            if (piece.effect != PieceEffect.none) piece.id,
        };
        retainedNaturalSpecial |= board.pieces.whereType<Piece>().any(
          (piece) =>
              piece.effect != PieceEffect.none &&
              !expected.contains(piece.id) &&
              !initialSpecialIds.contains(piece.id),
        );
      }
    }
    expect(lines, {PieceEffect.row, PieceEffect.column});
    // 自然连锁生成的特效不属于彩虹转换队列，可以留在稳定棋盘上。
    expect(retainedNaturalSpecial, isTrue);
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

  test('通关后剩余步数进入 Bonus Time，可转换直线或炸弹并保持确定性', () {
    final generatedEffects = <PieceEffect>{};
    for (var seed = 1; seed <= 12; seed++) {
      final setup = _pattern({0: 0, 1: 0, 2: 1, 3: 0, 10: 0}, seed: seed);
      final data = setup.toJson()
        ..['targets'] = {'0': 1, '1': 1}
        ..['collected'] = [0, 1, 0, 0, 0, 0]
        ..['ice'] = List.filled(MatchBoard.cells, 0)
        ..['score'] = 0;
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
        [2, 1, 0],
      );
      expect(result.initialMatchCount, 4);
      expect(
        result.frames.any(
          (frame) =>
              frame.phase == FramePhase.bonus &&
              frame.pieces.any(
                (piece) =>
                    piece?.effect == PieceEffect.row ||
                    piece?.effect == PieceEffect.column ||
                    piece?.effect == PieceEffect.bomb,
              ),
        ),
        isTrue,
      );
      for (final frame in result.frames.where(
        (frame) => frame.convertedPieceIds.isNotEmpty,
      )) {
        expect(frame.convertedPieceIds.length, 1);
        final converted = frame.pieces.whereType<Piece>().singleWhere(
          (piece) => frame.convertedPieceIds.contains(piece.id),
        );
        expect(
          converted.effect,
          anyOf(PieceEffect.row, PieceEffect.column, PieceEffect.bomb),
        );
        generatedEffects.add(converted.effect);
        final previous = result.frames[result.frames.indexOf(frame) - 1];
        expect(previous.phase, FramePhase.bonusTransfer);
        expect(previous.transferringPieceIds, frame.convertedPieceIds);
        expect(
          previous.pieces
              .whereType<Piece>()
              .singleWhere((piece) => piece.id == converted.id)
              .effect,
          PieceEffect.none,
        );
        expect(previous.movesLeft, frame.movesLeft);
        expect(previous.score, frame.score);
      }
    }
    expect(generatedEffects, {
      PieceEffect.row,
      PieceEffect.column,
      PieceEffect.bomb,
    });
  });

  test('彩虹炸弹组合先转换再交错触发，按棋子身份追踪目标且最后恢复稳定', () {
    final board = _pattern(
      {},
      effects: {0: PieceEffect.rainbow, 1: PieceEffect.bomb},
    );
    final mirror = MatchBoard.fromJson(jsonDecode(jsonEncode(board.toJson())));
    final result = board.playSwap(0, 1)!;
    mirror.playSwap(0, 1);
    expect(jsonEncode(board.toJson()), jsonEncode(mirror.toJson()));
    final converted = result.frames.singleWhere(
      (frame) => frame.phase == FramePhase.transform,
    );
    expect(converted.convertedPieceIds.length, greaterThan(1));
    final clearFrames = result.frames
        .where((frame) => frame.phase == FramePhase.clear)
        .toList();
    // 彩虹只消耗自己，不提前触发刚转换的全部动物。
    expect(clearFrames.first.clearing, {1});
    final firstTrigger = clearFrames[1];
    expect(firstTrigger.clearing, {0, 1, 8, 9});
    expect(
      firstTrigger.clearing
          .where(
            (index) => firstTrigger.pieces[index]!.effect != PieceEffect.none,
          )
          .length,
      1,
    );
    final triggeredIds = {
      for (final frame in clearFrames)
        for (final index in frame.clearing) frame.pieces[index]!.id,
    };
    expect(triggeredIds, containsAll(converted.convertedPieceIds));
    expect(result.frames.any((frame) => frame.staggeredFall), isTrue);
    expect(
      result.frames
          .where((frame) => frame.phase == FramePhase.fall)
          .last
          .staggeredFall,
      isFalse,
    );
    expect(board.matchRuns(), isEmpty);
    final clearPositions = [
      for (var index = 0; index < result.frames.length; index++)
        if (result.frames[index].phase == FramePhase.clear) index,
    ];
    for (var index = 1; index < clearPositions.length; index++) {
      final falls = result.frames
          .sublist(clearPositions[index - 1] + 1, clearPositions[index])
          .where((frame) => frame.phase == FramePhase.fall);
      expect(falls, isNotEmpty);
      expect(falls.last.pieces.every((piece) => piece != null), isTrue);
    }
  });

  test('自动触发的一只特效波及其他特效时，仍在同一波完整连锁', () {
    final board = _pattern(
      {},
      effects: {
        0: PieceEffect.rainbow,
        1: PieceEffect.bomb,
        8: PieceEffect.bomb,
      },
    );
    final clears = board
        .playSwap(0, 1)!
        .frames
        .where((frame) => frame.phase == FramePhase.clear)
        .toList();
    final firstTrigger = clears[1];
    expect(firstTrigger.clearing, containsAll([0, 8, 16, 17]));
    expect(firstTrigger.pieces[0]!.effect, PieceEffect.bomb);
    expect(firstTrigger.pieces[8]!.effect, PieceEffect.bomb);
  });

  test('双彩虹先结算其他特效及自然连锁，保护交换双方直到稳定后的全盘消除', () {
    final scenarios = [
      (
        overrides: <int, int>{},
        effects: {8: PieceEffect.column, 63: PieceEffect.bomb},
      ),
      (
        overrides: <int, int>{},
        effects: {8: PieceEffect.bomb, 50: PieceEffect.rainbow},
      ),
      (overrides: {2: 0, 3: 0}, effects: <int, PieceEffect>{}),
    ];
    for (final scenario in scenarios) {
      final setup = _pattern(
        scenario.overrides,
        effects: {
          0: PieceEffect.rainbow,
          1: PieceEffect.rainbow,
          ...scenario.effects,
        },
      );
      final data = setup.toJson()..['targets'] = {'0': 1000, '1': 1000};
      final board = MatchBoard.fromJson(data);
      final mirror = MatchBoard.fromJson(jsonDecode(jsonEncode(data)));
      final pairedIds = {board.pieces[0]!.id, board.pieces[1]!.id};
      final otherIds = {
        for (final index in scenario.effects.keys) board.pieces[index]!.id,
      };
      final previousMoves = board.movesLeft;
      final result = board.playSwap(0, 1)!;
      mirror.playSwap(0, 1);
      expect(jsonEncode(board.toJson()), jsonEncode(mirror.toJson()));
      expect(board.movesLeft, previousMoves - 1);
      final fullIndex = result.frames.indexWhere(
        (frame) =>
            frame.phase == FramePhase.clear &&
            frame.clearing.length == MatchBoard.cells,
      );
      expect(fullIndex, greaterThan(1));
      final priorClears = result.frames
          .take(fullIndex)
          .where((frame) => frame.phase == FramePhase.clear)
          .toList();
      expect(priorClears, isNotEmpty);
      final triggeredIds = {
        for (final frame in priorClears)
          for (final index in frame.clearing) frame.pieces[index]!.id,
      };
      expect(triggeredIds, containsAll(otherIds));
      expect(triggeredIds.intersection(pairedIds), isEmpty);

      final full = result.frames[fullIndex];
      // 最终全盘消除前，场上仅剩保留的两只彩虹特效，且已经没有自然匹配。
      expect({
        for (final piece in full.pieces.whereType<Piece>())
          if (piece.effect != PieceEffect.none) piece.id,
      }, pairedIds);
      final stable = MatchBoard.fromJson({
        ...board.toJson(),
        'pieces': full.pieces.map((piece) => piece!.toJson()).toList(),
      });
      expect(stable.matchRuns(), isEmpty);
      expect(result.frames[fullIndex - 1].phase, FramePhase.fall);
      expect(
        result.frames[fullIndex - 1].pieces.every((piece) => piece != null),
        isTrue,
      );
      expect(board.pieces.every((piece) => piece != null), isTrue);
      expect(board.matchRuns(), isEmpty);
    }
  });

  test('Bonus 每次主动触发一只特效，未波及的特效保留到后续波次', () {
    final setup = _pattern(
      {0: 0, 1: 0, 2: 1, 3: 0, 10: 0},
      effects: {50: PieceEffect.bomb, 60: PieceEffect.rainbow},
    );
    final data = setup.toJson()
      ..['targets'] = {'0': 1, '1': 1}
      ..['collected'] = [0, 1, 0, 0, 0, 0]
      ..['movesLeft'] = 1;
    data['moveNumber'] = data['initialMoves'] - 1;
    final board = MatchBoard.fromJson(data);
    final result = board.playSwap(10, 2)!;
    final bonusFrames = result.frames
        .skipWhile((frame) => frame.phase != FramePhase.bonus)
        .toList();
    final firstTrigger = bonusFrames.firstWhere(
      (frame) => frame.phase == FramePhase.clear,
    );
    // 开局四连留下的直线特效先触发，底部两只特效不应被同时主动触发。
    expect(firstTrigger.clearing, {0, 1, 2, 3, 4, 5, 6, 7});
    expect(firstTrigger.pieces[50]!.effect, PieceEffect.bomb);
    expect(firstTrigger.pieces[60]!.effect, PieceEffect.rainbow);
    expect(
      bonusFrames
          .where((frame) => frame.phase == FramePhase.clear)
          .skip(1)
          .any(
            (frame) => frame.clearing.any(
              (index) => frame.pieces[index]!.id == firstTrigger.pieces[60]!.id,
            ),
          ),
      isTrue,
    );
    expect(
      board.pieces.whereType<Piece>().every(
        (piece) => piece.effect == PieceEffect.none,
      ),
      isTrue,
    );
  });

  test('结算期间分数逐帧累加，且只由消除动物产生', () {
    final setup = _pattern({0: 0, 1: 0, 2: 1, 3: 0, 10: 0});
    final data = setup.toJson()
      ..['targets'] = {'0': 1, '1': 1}
      ..['collected'] = [0, 1, 0, 0, 0, 0]
      ..['ice'] = List.filled(MatchBoard.cells, 0)
      ..['score'] = 0;
    data['movesLeft'] = 3;
    data['moveNumber'] = data['initialMoves'] - 3;
    final board = MatchBoard.fromJson(data);

    final result = board.playSwap(10, 2)!;

    // 首帧是玩家交换，分数仍是结算前的分数。
    expect(result.frames.first.score, 0);
    var previous = result.frames.first.score;
    var increases = 0;
    for (final frame in result.frames) {
      expect(frame.score, greaterThanOrEqualTo(previous));
      if (frame.score != previous) {
        increases++;
        // 分数只在消除帧增加，特效生成帧不直接加分。
        expect(frame.phase, FramePhase.clear);
      }
      previous = frame.score;
    }
    expect(previous, board.score);
    expect(previous, result.scoreGained);
    expect(increases, greaterThan(1));
    // 每个剩余步数生成的特效都触发一次消除，逐步加分而非一次结清。
    final bonusIndex = result.frames.indexWhere(
      (frame) => frame.phase == FramePhase.bonus,
    );
    // 首个 bonus 帧只标记进入奖励阶段，其余才是步数转换。
    final bonusCount =
        result.frames.where((frame) => frame.phase == FramePhase.bonus).length -
        1;
    expect(bonusIndex, greaterThanOrEqualTo(0));
    final bonusScores = <int>{};
    for (final frame in result.frames.skip(bonusIndex)) {
      if (!bonusScores.contains(frame.score)) bonusScores.add(frame.score);
    }
    expect(bonusScores.length, greaterThanOrEqualTo(bonusCount + 1));
  });

  test('Bonus 自动触发已有和掉落连锁生成的所有特效，步数耗尽仍继续结算', () {
    var sawExistingSpecial = false;
    var sawCascadeSpecial = false;
    var sawCascadeSpecialWithoutMoves = false;
    for (var seed = 1; seed <= 50; seed++) {
      final setup = _pattern(
        {0: 0, 1: 0, 2: 1, 3: 0, 10: 0},
        effects: {50: PieceEffect.bomb, 60: PieceEffect.rainbow},
        seed: seed,
      );
      final data = setup.toJson()
        ..['targets'] = {'0': 1, '1': 1}
        ..['collected'] = [0, 1, 0, 0, 0, 0]
        ..['movesLeft'] = seed.isEven ? 1 : 3;
      data['moveNumber'] = data['initialMoves'] - data['movesLeft'];
      final board = MatchBoard.fromJson(data);
      final mirror = MatchBoard.fromJson(jsonDecode(jsonEncode(data)));
      final result = board.playSwap(10, 2)!;
      mirror.playSwap(10, 2);
      expect(jsonEncode(board.toJson()), jsonEncode(mirror.toJson()));
      final bonusIndex = result.frames.indexWhere(
        (frame) => frame.phase == FramePhase.bonus,
      );
      expect(bonusIndex, greaterThanOrEqualTo(0));
      final bonusFrames = result.frames.skip(bonusIndex).toList();
      final initialSpecialIds = {
        for (final piece in bonusFrames.first.pieces.whereType<Piece>())
          if (piece.effect != PieceEffect.none) piece.id,
      };
      sawExistingSpecial |= initialSpecialIds.isNotEmpty;
      final triggeredIds = <int>{};
      final cascadeSpecialIds = <int>{};
      for (var i = 0; i < bonusFrames.length; i++) {
        final frame = bonusFrames[i];
        if (frame.phase != FramePhase.clear) continue;
        triggeredIds.addAll({
          for (final index in frame.clearing)
            if (frame.pieces[index] case final Piece piece
                when piece.effect != PieceEffect.none)
              piece.id,
        });
        // 消除帧中保留下来的特效由连锁匹配生成，而非步数转换。
        for (var index = 0; index < MatchBoard.cells; index++) {
          final piece = frame.pieces[index];
          if (piece == null ||
              piece.effect == PieceEffect.none ||
              frame.clearing.contains(index)) {
            continue;
          }
          cascadeSpecialIds.add(piece.id);
          if (frame.movesLeft == 0) sawCascadeSpecialWithoutMoves = true;
          // 逐只触发后不要求紧接的下一波就轮到它，但最终必须按棋子身份触发。
          final laterClearedIds = bonusFrames
              .skip(i + 1)
              .where((next) => next.phase == FramePhase.clear)
              .expand(
                (next) => next.clearing.map((cell) => next.pieces[cell]!.id),
              );
          expect(
            laterClearedIds,
            contains(piece.id),
            reason: 'seed=$seed, piece=${piece.id}',
          );
        }
      }
      sawCascadeSpecial |= cascadeSpecialIds.isNotEmpty;
      expect(triggeredIds, containsAll(initialSpecialIds));
      expect(triggeredIds, containsAll(cascadeSpecialIds));
      expect(board.movesLeft, 0);
      expect(board.status, MatchStatus.won);
      expect(board.matchRuns(), isEmpty);
      expect(
        board.pieces.whereType<Piece>().every(
          (piece) => piece.effect == PieceEffect.none,
        ),
        isTrue,
      );
    }
    // 避免只验证没有产生新特效的局面，确保三种情况都实际发生。
    expect(sawExistingSpecial, isTrue);
    expect(sawCascadeSpecial, isTrue);
    expect(sawCascadeSpecialWithoutMoves, isTrue);
  });

  test('步数归零结束，达成全部目标才获胜，结束后不再接受交换', () {
    final data = MatchBoard.random(seed: 15).toJson();
    data['movesLeft'] = 0;
    data['moveNumber'] = data['initialMoves'];
    final lost = MatchBoard.fromJson(data);
    expect(lost.status, MatchStatus.lost);
    final move = lost.legalMoves.first;
    expect(lost.playSwap(move.$1, move.$2), isNull);
    data['score'] = 0;
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

  test('胜利只取决于三项目标，不受分数影响，快照不包含分数目标', () {
    final data = MatchBoard.random(seed: 15).toJson();
    expect(data.keys, isNot(contains('scoreTarget')));
    data['score'] = 0;
    data['collected'] = List.filled(MatchBoard.kinds, 100);
    data['ice'] = List.filled(MatchBoard.cells, 0);
    expect(MatchBoard.fromJson(data).status, MatchStatus.won);
    data['score'] = 1000000;
    (data['ice'] as List)[0] = 1;
    expect(MatchBoard.fromJson(data).status, MatchStatus.playing);
    data['movesLeft'] = 0;
    data['moveNumber'] = data['initialMoves'];
    expect(MatchBoard.fromJson(data).status, MatchStatus.lost);
  });
}
