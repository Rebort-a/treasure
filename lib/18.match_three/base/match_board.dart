import 'dart:math' as math;

enum PieceEffect { none, row, column, bomb, rainbow }

enum MatchStatus { playing, won, lost }

enum FramePhase { swap, bonus, clear, fall, settled }

enum ComboPraise { good, great, excellent, amazing, unbelievable }

class Piece {
  final int id;
  final int kind;
  final PieceEffect effect;

  const Piece(this.id, this.kind, [this.effect = PieceEffect.none]);

  List<int> toJson() => [id, kind, effect.index];
}

/// 动画帧只保存展示数据，不参与联机判定。
class BoardFrame {
  final List<Piece?> pieces;
  final List<int> ice;

  /// 目标进度随消除帧更新，避免交换刚开始就展示整步结算后的结果。
  final List<int> collected;
  final Set<int> clearing;
  final Set<int> spawnedPieceIds;
  final int movesLeft;

  /// 分数快照，结算期间每触发一次消除就前进一格，而不是一次跳到总分。
  final int score;
  final FramePhase phase;

  BoardFrame(
    MatchBoard board,
    this.phase, [
    Set<int> clearing = const {},
    Set<int> spawnedPieceIds = const {},
    int? movesLeft,
    int? score,
  ]) : pieces = List.unmodifiable(board.pieces),
       ice = List.unmodifiable(board.ice),
       collected = List.unmodifiable(board.collected),
       clearing = Set.unmodifiable(clearing),
       spawnedPieceIds = Set.unmodifiable(spawnedPieceIds),
       movesLeft = movesLeft ?? board.movesLeft,
       score = score ?? board.score;

  /// 开局只清空展示帧，不修改内核棋盘或消耗随机数。
  BoardFrame.empty(MatchBoard board)
    : pieces = List.unmodifiable(List<Piece?>.filled(MatchBoard.cells, null)),
      ice = List.unmodifiable(board.ice),
      collected = List.unmodifiable(board.collected),
      clearing = const {},
      spawnedPieceIds = const {},
      movesLeft = board.movesLeft,
      score = board.score,
      phase = FramePhase.settled;
}

class SwapResult {
  final List<BoardFrame> frames;
  final int cascades;
  final int scoreGained;
  final bool shuffled;
  final int initialMatchCount;
  final int totalCleared;
  final int specialEffectsTriggered;

  const SwapResult(
    this.frames,
    this.cascades,
    this.scoreGained,
    this.shuffled,
    this.initialMatchCount,
    this.totalCleared,
    this.specialEffectsTriggered,
  );
}

/// 纯 Dart 三消内核。所有随机数均来自可序列化的同一条序列，动画不消耗随机数。
///
/// 稳定局面不含现成三连，且至少存在一步合法交换。无效交换不扣步数；
/// 一个合法交换的所有连锁、特效、补块和无解洗牌只算一步。
class MatchBoard {
  static const side = 8;
  static const cells = side * side;
  static const kinds = 6;
  static const _modulus = 2147483647;

  final int seed;
  int _randomState;
  int _nextId = 1;
  final List<Piece?> pieces;
  final List<int> ice;
  final Map<int, int> targets;
  final List<int> collected;
  final int initialMoves;
  int movesLeft;
  int score = 0;
  int moveNumber = 0;
  int reshuffles = 0;
  (int, int)? lastSwap;

  MatchBoard._({
    required this.seed,
    required int randomState,
    required this.pieces,
    required this.ice,
    required this.targets,
    required this.collected,
    required this.initialMoves,
    required this.movesLeft,
  }) : _randomState = randomState;

  factory MatchBoard.random({int? seed}) {
    final value = seed == null
        ? math.Random.secure().nextInt(_modulus - 1) + 1
        : (seed - 1) % (_modulus - 1) + 1;
    final board = MatchBoard._(
      seed: value,
      randomState: value,
      pieces: List.filled(cells, null),
      ice: List.filled(cells, 0),
      targets: {},
      collected: List.filled(kinds, 0),
      initialMoves: 20 + value % 5,
      movesLeft: 20 + value % 5,
    );
    final animals = List.generate(kinds, (i) => i);
    board._shuffle(animals);
    for (final kind in animals.take(2)) {
      board.targets[kind] = 14 + board._next(9);
    }
    final positions = List.generate(cells, (i) => i);
    board._shuffle(positions);
    for (final index in positions.take(10 + board._next(7))) {
      board.ice[index] = 1;
    }
    board._freshBoard();
    return board;
  }

  /// 使用乘积小于 2^53 的整数算法，Dart VM 与 Web 保持同一随机序列。
  int _next(int bound) {
    _randomState = _randomState * 16807 % _modulus;
    return _randomState % bound;
  }

  void _shuffle<T>(List<T> values) {
    for (var i = values.length - 1; i > 0; i--) {
      final other = _next(i + 1);
      final value = values[i];
      values[i] = values[other];
      values[other] = value;
    }
  }

  Piece _piece(int kind) => Piece(_nextId++, kind);

  MatchStatus get status {
    if (ice.every((layer) => layer == 0) &&
        targets.entries.every((entry) => collected[entry.key] >= entry.value)) {
      return MatchStatus.won;
    }
    return movesLeft == 0 ? MatchStatus.lost : MatchStatus.playing;
  }

  int get iceLeft => ice.fold(0, (sum, value) => sum + value);

  bool adjacent(int a, int b) =>
      a >= 0 &&
      b >= 0 &&
      a < cells &&
      b < cells &&
      ((a ~/ side - b ~/ side).abs() + (a % side - b % side).abs() == 1);

  void _swap(int a, int b) {
    final value = pieces[a];
    pieces[a] = pieces[b];
    pieces[b] = value;
  }

  bool _specialPair(int a, int b) =>
      pieces[a]?.effect == PieceEffect.rainbow ||
      pieces[b]?.effect == PieceEffect.rainbow ||
      (pieces[a]?.effect != PieceEffect.none &&
          pieces[b]?.effect != PieceEffect.none);

  bool canSwap(int a, int b) {
    if (!adjacent(a, b) || pieces[a] == null || pieces[b] == null) return false;
    if (ice[a] > 0 || ice[b] > 0) return false;
    if (_specialPair(a, b)) return true;
    _swap(a, b);
    final runs = matchRuns();
    _swap(a, b);
    return runs.any((run) => run.contains(a) || run.contains(b));
  }

  List<(int, int)> get legalMoves {
    final result = <(int, int)>[];
    for (var index = 0; index < cells; index++) {
      if (index % side < side - 1 && canSwap(index, index + 1)) {
        result.add((index, index + 1));
      }
      if (index < cells - side && canSwap(index, index + side)) {
        result.add((index, index + side));
      }
    }
    return result;
  }

  /// 横向与纵向分别扫描，交叉点会出现在两条线中，供炸弹判定使用。
  List<List<int>> matchRuns() {
    final runs = <List<int>>[];
    for (final vertical in [false, true]) {
      for (var line = 0; line < side; line++) {
        var start = 0;
        while (start < side) {
          int at(int position) =>
              vertical ? position * side + line : line * side + position;
          final kind = pieces[at(start)]?.kind;
          var end = start + 1;
          while (kind != null && end < side && pieces[at(end)]?.kind == kind) {
            end++;
          }
          if (kind != null && end - start >= 3) {
            runs.add([for (var i = start; i < end; i++) at(i)]);
          }
          start = end;
        }
      }
    }
    return runs;
  }

  void _freshBoard() {
    for (var attempt = 0; attempt < 200; attempt++) {
      for (var i = 0; i < cells; i++) {
        final available = [
          for (var kind = 0; kind < kinds; kind++)
            if (!(i % side >= 2 &&
                    pieces[i - 1]?.kind == kind &&
                    pieces[i - 2]?.kind == kind) &&
                !(i >= side * 2 &&
                    pieces[i - side]?.kind == kind &&
                    pieces[i - side * 2]?.kind == kind))
              kind,
        ];
        pieces[i] = _piece(available[_next(available.length)]);
      }
      if (legalMoves.isNotEmpty) return;
    }
    // 极端随机序列的有界兜底：该图案无三连，交换 1 与 9 必定形成三连。
    for (var i = 0; i < cells; i++) {
      pieces[i] = _piece((i ~/ side * 2 + i % side) % kinds);
    }
    pieces[0] = _piece(0);
    pieces[1] = _piece(1);
    pieces[2] = _piece(0);
    pieces[9] = _piece(0);
  }

  /// 洗牌保持已有棋子的身份/特效以及冰层、目标、分数和剩余步数。
  void _ensurePlayable() {
    if (matchRuns().isEmpty && legalMoves.isNotEmpty) return;
    reshuffles++;
    for (var attempt = 0; attempt < 100; attempt++) {
      _shuffle(pieces);
      if (matchRuns().isEmpty && legalMoves.isNotEmpty) return;
    }
    _freshBoard();
  }

  Map<int, PieceEffect> _createEffects(List<List<int>> runs, int a, int b) {
    final effects = <int, PieceEffect>{};
    final remaining = runs.toList();
    while (remaining.isNotEmpty) {
      final group = [remaining.removeAt(0)];
      final indices = group.first.toSet();
      var expanded = true;
      while (expanded) {
        expanded = false;
        for (final run in remaining.toList()) {
          if (run.any(indices.contains)) {
            group.add(run);
            indices.addAll(run);
            remaining.remove(run);
            expanded = true;
          }
        }
      }
      final longest = group.reduce((x, y) => x.length >= y.length ? x : y);
      final intersection = indices.where(
        (index) => group.where((run) => run.contains(index)).length > 1,
      );
      PieceEffect effect;
      Set<int> candidates;
      if (longest.length >= 5) {
        effect = PieceEffect.rainbow;
        candidates = longest.toSet();
      } else if (intersection.isNotEmpty) {
        effect = PieceEffect.bomb;
        candidates = intersection.toSet();
      } else if (longest.length >= 4) {
        effect = longest[0] ~/ side == longest[1] ~/ side
            ? PieceEffect.row
            : PieceEffect.column;
        candidates = longest.toSet();
      } else {
        continue;
      }
      final anchor = candidates.contains(b)
          ? b
          : candidates.contains(a)
          ? a
          : (candidates.toList()..sort()).first;
      // 已有特效应该被触发，不要用新特效覆盖它。
      if (pieces[anchor]?.effect == PieceEffect.none) effects[anchor] = effect;
    }
    return effects;
  }

  Set<int> _expandEffects(
    Set<int> initial,
    Set<int> protected, {
    Set<int> consumedRainbows = const {},
  }) {
    final clear = initial.difference(protected);
    final queue = clear.toList();
    for (var cursor = 0; cursor < queue.length; cursor++) {
      final index = queue[cursor];
      final piece = pieces[index];
      if (piece == null) continue;
      final affected = <int>[];
      switch (piece.effect) {
        case PieceEffect.row:
          affected.addAll(
            List.generate(side, (col) => index ~/ side * side + col),
          );
        case PieceEffect.column:
          affected.addAll(
            List.generate(side, (row) => row * side + index % side),
          );
        case PieceEffect.bomb:
          for (
            var row = math.max(0, index ~/ side - 1);
            row <= math.min(side - 1, index ~/ side + 1);
            row++
          ) {
            for (
              var col = math.max(0, index % side - 1);
              col <= math.min(side - 1, index % side + 1);
              col++
            ) {
              affected.add(row * side + col);
            }
          }
        case PieceEffect.rainbow:
          if (!consumedRainbows.contains(index)) {
            affected.addAll([
              for (var i = 0; i < cells; i++)
                if (pieces[i]?.kind == piece.kind) i,
            ]);
          }
        case PieceEffect.none:
          break;
      }
      for (final cell in affected) {
        if (!protected.contains(cell) &&
            pieces[cell] != null &&
            clear.add(cell)) {
          queue.add(cell);
        }
      }
    }
    return clear;
  }

  ({Set<int> cells, int specialEffectsTriggered}) _clearWave({
    required List<BoardFrame> frames,
    required Set<int> initial,
    required Set<int> protected,
    required int multiplier,
    Set<int> consumedRainbows = const {},
  }) {
    final clear = _expandEffects(
      initial,
      protected,
      consumedRainbows: consumedRainbows,
    );
    final crackedIce = <int>{};
    var specialEffectsTriggered = 0;
    for (final index in clear) {
      final piece = pieces[index];
      if (piece == null) continue;
      if (piece.effect != PieceEffect.none) specialEffectsTriggered++;
      collected[piece.kind]++;
      if (ice[index] > 0) crackedIce.add(index);
      final row = index ~/ side;
      final col = index % side;
      if (row > 0) crackedIce.add(index - side);
      if (row < side - 1) crackedIce.add(index + side);
      if (col > 0) crackedIce.add(index - 1);
      if (col < side - 1) crackedIce.add(index + 1);
      score += 10 * multiplier;
      if (piece.effect != PieceEffect.none) score += 40;
    }
    for (final index in crackedIce) {
      if (ice[index] > 0) ice[index]--;
    }
    frames.add(BoardFrame(this, FramePhase.clear, clear));
    for (final index in clear) {
      pieces[index] = null;
    }
    frames.add(BoardFrame(this, FramePhase.fall));
    final spawnedPieceIds = _collapse();
    frames.add(BoardFrame(this, FramePhase.fall, const {}, spawnedPieceIds));
    return (cells: clear, specialEffectsTriggered: specialEffectsTriggered);
  }

  Set<int> _collapse() {
    final spawnedPieceIds = <int>{};
    for (var col = 0; col < side; col++) {
      var target = side - 1;
      for (var row = side - 1; row >= 0; row--) {
        final piece = pieces[row * side + col];
        if (piece != null) {
          pieces[target-- * side + col] = piece;
        }
      }
      while (target >= 0) {
        final piece = _piece(_next(kinds));
        pieces[target-- * side + col] = piece;
        spawnedPieceIds.add(piece.id);
      }
    }
    return spawnedPieceIds;
  }

  /// 奖励期间的棋盘规则：每轮重新扫描所有特效，掉落连锁生成的特效也会在下一轮触发。
  /// 步数转换只生成特效，不负责指定触发对象；步数耗尽后仍结算到稳定。
  int _settleBonus({
    required List<BoardFrame> frames,
    required int a,
    required int b,
    required int multiplier,
  }) {
    var waves = 0;
    // 与普通连锁一致保留有界保护，防止异常随机序列无限结算。
    while (waves < 64) {
      final runs = matchRuns();
      final specials = {
        for (var index = 0; index < cells; index++)
          if (pieces[index] case final Piece piece
              when piece.effect != PieceEffect.none)
            index,
      };
      if (runs.isEmpty && specials.isEmpty) break;
      final created = _createEffects(runs, a, b);
      for (final entry in created.entries) {
        final old = pieces[entry.key]!;
        pieces[entry.key] = Piece(old.id, old.kind, entry.value);
      }
      _clearWave(
        frames: frames,
        initial: {...specials, for (final run in runs) ...run},
        // 新特效先保留一轮展示，下一轮由棋盘自动扫描触发。
        protected: created.keys.toSet(),
        multiplier: multiplier + waves,
      );
      waves++;
    }
    return waves;
  }

  SwapResult? playSwap(int a, int b) {
    if (status != MatchStatus.playing || !canSwap(a, b)) return null;
    final previousScore = score;
    final previousShuffles = reshuffles;
    final special = _specialPair(a, b);
    _swap(a, b);
    movesLeft--;
    moveNumber++;
    lastSwap = (a, b);
    final frames = <BoardFrame>[BoardFrame(this, FramePhase.swap)];
    final forced = <int>{};
    final transformedEffects = <int, PieceEffect>{};
    if (special) {
      final effectA = pieces[a]!.effect;
      final effectB = pieces[b]!.effect;
      final rainbowA = effectA == PieceEffect.rainbow;
      final rainbowB = effectB == PieceEffect.rainbow;
      if (rainbowA || rainbowB) {
        forced.addAll({a, b});
        if (rainbowA && rainbowB) {
          forced.addAll(List.generate(cells, (index) => index));
        } else {
          final rainbowIndex = rainbowA ? a : b;
          final partnerIndex = rainbowA ? b : a;
          final partnerEffect = pieces[partnerIndex]!.effect;
          final kind = pieces[partnerIndex]!.kind;
          final comboEffect =
              partnerEffect == PieceEffect.row ||
                  partnerEffect == PieceEffect.column ||
                  partnerEffect == PieceEffect.bomb
              ? partnerEffect
              : null;
          for (var index = 0; index < cells; index++) {
            final piece = pieces[index];
            if (piece?.kind != kind) continue;
            forced.add(index);
            if (comboEffect != null &&
                index != rainbowIndex &&
                piece!.effect != PieceEffect.rainbow) {
              transformedEffects[index] = comboEffect == PieceEffect.bomb
                  ? PieceEffect.bomb
                  : _next(2) == 0
                  ? PieceEffect.row
                  : PieceEffect.column;
            }
          }
        }
      } else if (effectA != PieceEffect.bomb && effectB != PieceEffect.bomb) {
        // 直线特效交换时，分别触发各自的直线效果。
        forced.add(a);
        forced.add(b);
      } else if ((effectA == PieceEffect.bomb) !=
          (effectB == PieceEffect.bomb)) {
        // 直线特效与炸弹联动时，沿直线方向额外清除四行或四列。
        final bombIndex = effectA == PieceEffect.bomb ? a : b;
        final lineIndex = effectA == PieceEffect.bomb ? b : a;
        final lineEffect = pieces[lineIndex]!.effect;
        final vertical = lineEffect == PieceEffect.column;
        for (var offset = -1; offset <= 1; offset++) {
          if (vertical) {
            final col = bombIndex % side + offset;
            if (col >= 0 && col < side) {
              for (var row = 0; row < side; row++) {
                forced.add(row * side + col);
              }
            }
          } else {
            final row = bombIndex ~/ side + offset;
            if (row >= 0 && row < side) {
              for (var col = 0; col < side; col++) {
                forced.add(row * side + col);
              }
            }
          }
        }
      } else {
        // 双炸弹扩大为以交换中心为中心的 7×7 爆炸。
        forced.addAll({a, b});
      }
    }
    for (final entry in transformedEffects.entries) {
      final piece = pieces[entry.key]!;
      pieces[entry.key] = Piece(piece.id, piece.kind, entry.value);
    }
    var cascades = 0;
    final initialMatchCount = matchRuns().expand((run) => run).toSet().length;
    var totalCleared = 0;
    var specialEffectsTriggered = 0;
    // 连锁设上限，避免恶意快照或极端随机序列造成无限结算。
    while (cascades < 64) {
      final runs = matchRuns();
      if (runs.isEmpty && forced.isEmpty) break;
      final created = forced.isEmpty
          ? _createEffects(runs, a, b)
          : <int, PieceEffect>{};
      for (final entry in created.entries) {
        final old = pieces[entry.key]!;
        pieces[entry.key] = Piece(old.id, old.kind, entry.value);
      }
      final wave = _clearWave(
        frames: frames,
        initial: {...forced, for (final run in runs) ...run},
        protected: created.keys.toSet(),
        multiplier: cascades + 1,
        consumedRainbows: cascades == 0 && special ? {a, b} : {},
      );
      forced.clear();
      cascades++;
      totalCleared += wave.cells.length;
      specialEffectsTriggered += wave.specialEffectsTriggered;
    }
    if (status == MatchStatus.won) {
      // 先进入奖励阶段，再触发已有特效；即使没有剩余步数也适用。
      frames.add(BoardFrame(this, FramePhase.bonus));
      var bonusCascade = _settleBonus(
        frames: frames,
        a: a,
        b: b,
        multiplier: cascades + 1,
      );
      while (movesLeft > 0) {
        final index = _next(cells);
        final piece = pieces[index]!;
        pieces[index] = Piece(
          piece.id,
          piece.kind,
          _next(2) == 0 ? PieceEffect.row : PieceEffect.column,
        );
        movesLeft--;
        moveNumber++;
        frames.add(BoardFrame(this, FramePhase.bonus));
        bonusCascade += _settleBonus(
          frames: frames,
          a: a,
          b: b,
          multiplier: cascades + bonusCascade + 1,
        );
      }
    }
    _ensurePlayable();
    frames.add(BoardFrame(this, FramePhase.settled));
    return SwapResult(
      List.unmodifiable(frames),
      cascades,
      score - previousScore,
      reshuffles != previousShuffles,
      initialMatchCount,
      totalCleared,
      specialEffectsTriggered,
    );
  }

  Map<String, dynamic> toJson() => {
    'format': 1,
    'seed': seed,
    'random': _randomState,
    'nextId': _nextId,
    'pieces': pieces.map((piece) => piece!.toJson()).toList(),
    'ice': ice.toList(),
    'targets': {
      for (final entry in targets.entries) '${entry.key}': entry.value,
    },
    'collected': collected.toList(),
    'initialMoves': initialMoves,
    'movesLeft': movesLeft,
    'score': score,
    'moveNumber': moveNumber,
    'reshuffles': reshuffles,
    'lastSwap': lastSwap == null ? null : [lastSwap!.$1, lastSwap!.$2],
  };

  /// 只接受完整、稳定且尺寸有界的局面，不让网络数据造成越界或重复棋子身份。
  factory MatchBoard.fromJson(Map<String, dynamic> data) {
    int number(String key, int min, int max) {
      final value = data[key];
      if (value is! int || value < min || value > max) {
        throw FormatException('Invalid $key');
      }
      return value;
    }

    List<int> integers(dynamic raw, int count, int max) {
      if (raw is! List ||
          raw.length != count ||
          raw.any((value) => value is! int || value < 0 || value > max)) {
        throw const FormatException('Invalid integer list');
      }
      return raw.cast<int>().toList();
    }

    if (data['format'] != 1 ||
        data['pieces'] is! List ||
        (data['pieces'] as List).length != cells ||
        data['targets'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid board format');
    }
    final ids = <int>{};
    final pieces = (data['pieces'] as List).map<Piece?>((raw) {
      if (raw is! List ||
          raw.length != 3 ||
          raw.any((value) => value is! int)) {
        throw const FormatException('Invalid piece');
      }
      final id = raw[0] as int;
      final kind = raw[1] as int;
      final effect = raw[2] as int;
      if (id <= 0 ||
          id > 10000000 ||
          kind < 0 ||
          kind >= kinds ||
          effect < 0 ||
          effect >= PieceEffect.values.length ||
          !ids.add(id)) {
        throw const FormatException('Invalid piece');
      }
      return Piece(id, kind, PieceEffect.values[effect]);
    }).toList();
    final targets = (data['targets'] as Map<String, dynamic>).map((key, value) {
      final kind = int.tryParse(key);
      if (kind == null ||
          kind < 0 ||
          kind >= kinds ||
          value is! int ||
          value < 1 ||
          value > 1000) {
        throw const FormatException('Invalid target');
      }
      return MapEntry(kind, value);
    });
    if (targets.length != 2) throw const FormatException('Invalid targets');
    final board =
        MatchBoard._(
            seed: number('seed', 1, _modulus - 1),
            randomState: number('random', 1, _modulus - 1),
            pieces: pieces,
            ice: integers(data['ice'], cells, 2),
            targets: targets,
            collected: integers(data['collected'], kinds, 10000000),
            initialMoves: number('initialMoves', 1, 1000),
            movesLeft: number('movesLeft', 0, 1000),
          )
          .._nextId = number('nextId', 1, 10000000)
          ..score = number('score', 0, 10000000)
          ..moveNumber = number('moveNumber', 0, 1000)
          ..reshuffles = number('reshuffles', 0, 10000);
    if (board.movesLeft + board.moveNumber != board.initialMoves ||
        ids.any((id) => id >= board._nextId)) {
      throw const FormatException('Inconsistent board counters');
    }
    if (data['lastSwap'] != null) {
      final swap = integers(data['lastSwap'], 2, cells - 1);
      if (!board.adjacent(swap[0], swap[1])) {
        throw const FormatException('Invalid last swap');
      }
      board.lastSwap = (swap[0], swap[1]);
    }
    if (board.matchRuns().isNotEmpty || board.legalMoves.isEmpty) {
      throw const FormatException('Unsettled or unplayable board');
    }
    return board;
  }
}
