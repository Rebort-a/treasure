import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/18.match_three/base/match_board.dart';

MatchBoard _pattern(
  MatchTheme theme, {
  Map<int, int> ice = const {},
  bool four = false,
  int? moves,
  int seed = 7,
  bool winning = false,
}) {
  final data = MatchBoard.random(seed: seed, theme: theme).toJson();
  final overrides = {0: 0, 1: 0, 2: 1, 10: 0, if (four) 3: 0};
  data['pieces'] = [
    for (var i = 0; i < MatchBoard.cells; i++)
      [i + 1, overrides[i] ?? (i ~/ 8 * 2 + i % 8) % 6, 0],
  ];
  data['nextId'] = MatchBoard.cells + 1;
  data['ice'] = [for (var i = 0; i < MatchBoard.cells; i++) ice[i] ?? 0];
  data['targets'] = winning ? {'0': 1, '1': 1} : {'4': 1000, '5': 1000};
  if (winning) data['collected'] = [0, 1, 0, 0, 0, 0];
  if (moves != null) {
    data['movesLeft'] = moves;
    data['moveNumber'] = (data['initialMoves'] as int) - moves;
  }
  return MatchBoard.fromJson(data);
}

void main() {
  test('各主题开局可走，保存和恢复能确定性重演，旧快照默认经典', () {
    final classic = MatchBoard.random(seed: 7).toJson();
    expect(classic, isNot(contains('theme')));
    expect(MatchBoard.fromJson(classic).theme, MatchTheme.classic);
    expect(
      () => MatchBoard.fromJson({...classic, 'theme': 'unknown'}),
      throwsFormatException,
    );
    for (final theme in MatchTheme.values.skip(1)) {
      for (var seed = 1; seed <= 12; seed++) {
        final board = MatchBoard.random(seed: seed, theme: theme);
        expect(board.matchRuns(), isEmpty);
        expect(board.legalMoves, isNotEmpty);
        expect(board.toJson()['theme'], theme.name);
        final mirror = MatchBoard.fromJson(board.toJson());
        while (board.status == MatchStatus.playing) {
          final move = board.legalMoves.first;
          final result = board.playSwap(move.$1, move.$2)!;
          final replay = mirror.playSwap(move.$1, move.$2)!;
          expect(mirror.toJson(), board.toJson());
          expect(board.matchRuns(), isEmpty);
          expect(board.legalMoves, isNotEmpty);
          expect(
            replay.frames.map((frame) => frame.spreadingIce),
            result.frames.map((frame) => frame.spreadingIce),
          );
        }
      }
    }
  });

  test('厚冰每波只掉一层，剩余冰核为下一回合只生成一个相邻薄冰', () {
    final board = _pattern(MatchTheme.frost, ice: {8: 2, 63: 2});
    final result = board.playSwap(10, 2)!;
    final firstClear = result.frames.firstWhere(
      (f) => f.phase == FramePhase.clear,
    );
    expect(firstClear.ice[8], 1);
    final growth = result.frames.singleWhere(
      (f) => f.phase == FramePhase.freeze,
    );
    final previous = result.frames[result.frames.indexOf(growth) - 1];
    expect(growth.spreadingIce.values, [63]);
    final target = growth.spreadingIce.keys.single;
    expect(board.adjacent(target, 63), isTrue);
    expect(previous.ice[target], 0);
    expect(growth.ice[target], 1);
    expect(growth.score, previous.score);
    expect(growth.movesLeft, previous.movesLeft);
    expect(result.actionEndFrame.phase, FramePhase.settled);
    expect(result.hasBonus, isFalse);
  });

  test('厚冰四周都是薄冰时仅加厚一格，不会在同一回合继续扩散', () {
    final board = _pattern(MatchTheme.frost, ice: {55: 1, 62: 1, 63: 2});
    final result = board.playSwap(10, 2)!;
    final growth = result.frames.singleWhere(
      (f) => f.phase == FramePhase.freeze,
    );
    expect(growth.spreadingIce.values, [63]);
    final target = growth.spreadingIce.keys.single;
    expect(target, isIn([55, 62]));
    expect(growth.ice[target], 2);
    expect(growth.ice[target == 55 ? 62 : 55], 1);
    expect(growth.ice.where((layer) => layer > 0), hasLength(3));
  });

  test('无效交换和终局不发生扩散，奖励阶段也不扩散', () {
    final losing = _pattern(MatchTheme.frost, ice: {63: 2}, moves: 1);
    final snapshot = losing.toJson();
    expect(losing.playSwap(0, 63), isNull);
    expect(losing.toJson(), snapshot);
    final loss = losing.playSwap(10, 2)!;
    expect(losing.status, MatchStatus.lost);
    expect(loss.frames.map((f) => f.phase), isNot(contains(FramePhase.freeze)));
    expect(losing.iceLeft, 2);

    final winning = _pattern(
      MatchTheme.frost,
      ice: {8: 1},
      winning: true,
      moves: 2,
    );
    final win = winning.playSwap(10, 2)!;
    expect(win.hasBonus, isTrue);
    expect(winning.status, MatchStatus.won);
    expect(win.frames.map((f) => f.phase), isNot(contains(FramePhase.freeze)));
  });

  test('闪电三连生成直线特效，彩虹四连生成彩虹，经典保留原规则', () {
    BoardFrame firstClear(MatchTheme theme, {bool four = false}) => _pattern(
      theme,
      four: four,
    ).playSwap(10, 2)!.frames.firstWhere((f) => f.phase == FramePhase.clear);
    expect(firstClear(MatchTheme.classic).pieces[2]!.effect, PieceEffect.none);
    expect(firstClear(MatchTheme.lightning).pieces[2]!.effect, PieceEffect.row);
    expect(
      firstClear(MatchTheme.classic, four: true).pieces[2]!.effect,
      PieceEffect.row,
    );
    expect(
      firstClear(MatchTheme.rainbow, four: true).pieces[2]!.effect,
      PieceEffect.rainbow,
    );
    final lightning = MatchBoard.random(seed: 7, theme: MatchTheme.lightning);
    expect(lightning.iceLeft, 0);
    expect(
      lightning.pieces.map((p) => p!.effect),
      containsAll([PieceEffect.row, PieceEffect.column]),
    );
    final rainbow = MatchBoard.random(seed: 7, theme: MatchTheme.rainbow);
    expect([0, 7, 56, 63].map((i) => rainbow.ice[i]), everyElement(1));
    expect(rainbow.pieces.map((p) => p!.effect), contains(PieceEffect.rainbow));
  });
}
