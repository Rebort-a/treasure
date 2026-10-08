import 'dart:math' as math;

enum PieceEffect { none, row, column, bomb, rainbow }

enum MatchStatus { playing, won, lost }

enum FramePhase { swap, clear, fall, settled }

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
  final Set<int> clearing;
  final FramePhase phase;

  BoardFrame(MatchBoard board, this.phase, [Set<int> clearing = const {}])
    : pieces = List.unmodifiable(board.pieces),
      ice = List.unmodifiable(board.ice),
      clearing = Set.unmodifiable(clearing);
}

class SwapResult {
  final List<BoardFrame> frames;
  final int cascades;
  final int scoreGained;
  final bool shuffled;

  const SwapResult(this.frames, this.cascades, this.scoreGained, this.shuffled);
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
  final int scoreTarget;
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
    required this.scoreTarget,
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
      scoreTarget: 1800 + value % 5 * 150,
      initialMoves: 28 + value % 7,
      movesLeft: 28 + value % 7,
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
    if (score >= scoreTarget &&
        ice.every((layer) => layer == 0) &&
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

  void _collapse() {
    for (var col = 0; col < side; col++) {
      var target = side - 1;
      for (var row = side - 1; row >= 0; row--) {
        final piece = pieces[row * side + col];
        if (piece != null) {
          pieces[target-- * side + col] = piece;
        }
      }
      while (target >= 0) {
        pieces[target-- * side + col] = _piece(_next(kinds));
      }
    }
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
    var forced = <int>{};
    if (special) {
      forced.addAll({a, b});
      final rainbowA = pieces[a]!.effect == PieceEffect.rainbow;
      final rainbowB = pieces[b]!.effect == PieceEffect.rainbow;
      if (rainbowA || rainbowB) {
        final kind = pieces[rainbowA ? b : a]!.kind;
        forced.addAll([
          for (var i = 0; i < cells; i++)
            if ((rainbowA && rainbowB) || pieces[i]?.kind == kind) i,
        ]);
      }
    }
    var cascades = 0;
    // 连锁设上限，避免恶意快照或极端随机序列造成无限结算。
    while (cascades < 64) {
      final runs = matchRuns();
      if (runs.isEmpty && forced.isEmpty) break;
      final created = forced.isEmpty
          ? _createEffects(runs, a, b)
          : <int, PieceEffect>{};
      final clear = _expandEffects(
        {...forced, for (final run in runs) ...run},
        created.keys.toSet(),
        consumedRainbows: cascades == 0 && special ? {a, b} : {},
      );
      forced = {};
      cascades++;
      for (final index in clear) {
        final piece = pieces[index];
        if (piece == null) continue;
        collected[piece.kind]++;
        if (ice[index] > 0) ice[index]--;
        score += 10 * cascades;
        if (piece.effect != PieceEffect.none) score += 40;
      }
      for (final entry in created.entries) {
        final old = pieces[entry.key]!;
        pieces[entry.key] = Piece(old.id, old.kind, entry.value);
      }
      frames.add(BoardFrame(this, FramePhase.clear, clear));
      for (final index in clear) {
        pieces[index] = null;
      }
      frames.add(BoardFrame(this, FramePhase.fall));
      _collapse();
      frames.add(BoardFrame(this, FramePhase.fall));
    }
    _ensurePlayable();
    frames.add(BoardFrame(this, FramePhase.settled));
    return SwapResult(
      List.unmodifiable(frames),
      cascades,
      score - previousScore,
      reshuffles != previousShuffles,
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
    'scoreTarget': scoreTarget,
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
            scoreTarget: number('scoreTarget', 1, 1000000),
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
