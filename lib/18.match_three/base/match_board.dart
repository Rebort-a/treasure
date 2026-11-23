import 'dart:math' as math;

enum PieceEffect { none, row, column, bomb, rainbow }

enum MatchStatus { playing, won, lost }

enum FramePhase { swap, bonus, clear, fall, settled, transform, transfer }

enum ComboPraise { good, great, excellent, amazing, unbelievable }

enum BonusPacing { fixedBeat, waitForFall }

/// 奖励时间线使用整数毫秒，联机重演不依赖客户端的动画或系统时钟。
abstract final class BonusTiming {
  static const firstTransfer = 500;
  static const transferInterval = 900;
  static const transfer = 300;
  static const ignition = 500;
  static const autoIgnition = 650;
  static const clear = 180;
  static const fall = 220;
}

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

  /// 本帧转换为特效的棋子身份，仅用于展示，不参与结算或随机数生成。
  final Set<int> convertedPieceIds;

  /// 连线到达前保持原状的转换目标；来源为空时从步数面板方向进入棋盘。
  final Set<int> transferringPieceIds;
  final int? transferSourcePieceId;

  /// 彩虹转换轮询允许下一次引爆与本帧坠落动画重叠。
  final bool staggeredFall;

  /// 本波由自然匹配发起，不是主动引爆；波及的特效仍在同一波消除。
  final bool naturalClear;
  final int movesLeft;

  /// 目标首次达成的消除帧可触发庆祝，不必等本次行动的后续坠落。
  final bool goalsMet;

  /// 分数快照，随消除、特效生成和目标进度更新，而不是一次跳到总分。
  final int score;
  final FramePhase phase;

  /// 相对奖励开场的时间；普通模式仍依动画帧顺序播放。
  final int? bonusAt;

  /// 奖励连线进行中跟踪的棋子；目标被清除时可换到另一只普通动物。
  final int? bonusTransferTargetId;

  /// 奖励期间可并行播放多波消除；用棋子身份跟踪仍在消失的棋子。
  final List<BoardFrame> activeClears;
  final Set<int> clearingPieceIds;
  final Set<int>? crackedIce;
  final bool bonusFalling;
  final int? bonusTransferStartedAt;

  BoardFrame(
    MatchBoard board,
    this.phase, {
    Set<int> clearing = const {},
    Set<int> spawnedPieceIds = const {},
    int? movesLeft,
    int? score,
    Set<int> convertedPieceIds = const {},
    Set<int> transferringPieceIds = const {},
    this.transferSourcePieceId,
    this.staggeredFall = false,
    this.naturalClear = false,
    this.bonusAt,
    this.bonusTransferTargetId,
    List<BoardFrame> activeClears = const [],
    Set<int>? clearingPieceIds,
    this.crackedIce,
    this.bonusFalling = false,
    this.bonusTransferStartedAt,
  }) : pieces = List.unmodifiable(board.pieces),
       ice = List.unmodifiable(board.ice),
       collected = List.unmodifiable(board.collected),
       clearing = Set.unmodifiable(clearing),
       clearingPieceIds = Set.unmodifiable(
         clearingPieceIds ??
             {
               for (final index in clearing)
                 if (board.pieces[index] case final Piece piece) piece.id,
             },
       ),
       activeClears = List.unmodifiable(activeClears),
       spawnedPieceIds = Set.unmodifiable(spawnedPieceIds),
       convertedPieceIds = Set.unmodifiable(convertedPieceIds),
       transferringPieceIds = Set.unmodifiable(transferringPieceIds),
       movesLeft = movesLeft ?? board.movesLeft,
       goalsMet = board.goalsMet,
       score = score ?? board.score;

  BoardFrame.conversion(
    MatchBoard board, {
    required Set<int> pieceIds,
    FramePhase phase = FramePhase.transform,
  }) : this(board, phase, convertedPieceIds: pieceIds);

  BoardFrame.transfer(
    MatchBoard board, {
    required Set<int> pieceIds,
    int? sourcePieceId,
  }) : this(
         board,
         FramePhase.transfer,
         transferringPieceIds: pieceIds,
         transferSourcePieceId: sourcePieceId,
       );

  /// 开局只清空展示帧，不修改内核棋盘或消耗随机数。
  BoardFrame.empty(MatchBoard board)
    : pieces = List.unmodifiable(List<Piece?>.filled(MatchBoard.cells, null)),
      ice = List.unmodifiable(board.ice),
      collected = List.unmodifiable(board.collected),
      clearing = const {},
      spawnedPieceIds = const {},
      convertedPieceIds = const {},
      transferringPieceIds = const {},
      transferSourcePieceId = null,
      staggeredFall = false,
      naturalClear = false,
      bonusAt = null,
      bonusTransferTargetId = null,
      activeClears = const [],
      clearingPieceIds = const {},
      crackedIce = null,
      bonusFalling = false,
      bonusTransferStartedAt = null,
      movesLeft = board.movesLeft,
      goalsMet = board.goalsMet,
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

  /// 行动结算帧之后才是奖励帧；没有奖励时它就是最后一帧。
  final int actionEndIndex;

  const SwapResult(
    this.frames,
    this.cascades,
    this.scoreGained,
    this.shuffled,
    this.initialMatchCount,
    this.totalCleared,
    this.specialEffectsTriggered, {
    required this.actionEndIndex,
  });

  BoardFrame get actionEndFrame => frames[actionEndIndex];
  Iterable<BoardFrame> get actionFrames => frames.take(actionEndIndex + 1);
  bool get hasBonus => actionEndIndex < frames.length - 1;
}

/// 纯 Dart 三消内核。所有随机数均来自可序列化的同一条序列，动画不消耗随机数。
///
/// 稳定局面不含现成三连，且至少存在一步合法交换。无效交换不扣步数；
/// 一个合法交换的所有连锁、特效、补块和无解洗牌只算一步。
class MatchBoard {
  static const side = 8;
  static const cells = side * side;
  static const kinds = 6;

  /// 基础消除分参与波次倍率，生成特效、收集目标和破冰的奖励固定不放大。
  static const baseAnimalScore = 10;
  static const specialCreationBonus = 40;
  static const targetAnimalBonus = 10;
  static const iceLayerBonus = 20;
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

  bool get goalsMet =>
      ice.every((layer) => layer == 0) &&
      targets.entries.every((entry) => collected[entry.key] >= entry.value);

  MatchStatus get status => goalsMet
      ? MatchStatus.won
      : movesLeft == 0
      ? MatchStatus.lost
      : MatchStatus.playing;

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
  List<List<int>> matchRuns() => _matchRuns(const {});

  List<List<int>> _matchRuns(Set<int> excluded) {
    int? kindAt(int index) =>
        excluded.contains(index) ? null : pieces[index]?.kind;
    final runs = <List<int>>[];
    for (final vertical in [false, true]) {
      for (var line = 0; line < side; line++) {
        var start = 0;
        while (start < side) {
          int at(int position) =>
              vertical ? position * side + line : line * side + position;
          final kind = kindAt(at(start));
          var end = start + 1;
          while (kind != null && end < side && kindAt(at(end)) == kind) {
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
    // 洗牌的极端兜底可以重排颜色，但不能悄悄丢弃已有特效及其身份。
    final retained = {
      for (var i = 0; i < cells; i++)
        if (pieces[i] case final Piece piece
            when piece.effect != PieceEffect.none)
          i: piece,
    };
    Piece fresh(int index, int kind) {
      final old = retained[index];
      return old == null ? _piece(kind) : Piece(old.id, kind, old.effect);
    }

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
        pieces[i] = fresh(i, available[_next(available.length)]);
      }
      if (legalMoves.isNotEmpty) return;
    }
    // 极端随机序列的有界兜底：该图案无三连，交换 1 与 9 必定形成三连。
    for (var i = 0; i < cells; i++) {
      pieces[i] = fresh(i, (i ~/ side * 2 + i % side) % kinds);
    }
    pieces[0] = fresh(0, 0);
    pieces[1] = fresh(1, 1);
    pieces[2] = fresh(2, 0);
    pieces[9] = fresh(9, 0);
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

  /// 只有普通动物首次生成特效时奖励，已有特效不覆盖，也不重复计分。
  void _createSpecial(int index, PieceEffect effect) {
    final piece = pieces[index]!;
    if (piece.effect != PieceEffect.none || effect == PieceEffect.none) return;
    pieces[index] = Piece(piece.id, piece.kind, effect);
    score += specialCreationBonus;
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
    Set<int>? staggeredPieceIds,
    bool compactFall = false,
    bool naturalClear = false,
  }) {
    final wave = _scoreWave(initial, protected, multiplier, consumedRainbows);
    frames.add(
      BoardFrame(
        this,
        FramePhase.clear,
        clearing: wave.cells,
        naturalClear: naturalClear,
      ),
    );
    for (final index in wave.cells) {
      pieces[index] = null;
    }
    // 交错演出直接展示补齐后的坠落目标，不插入额外的空格帧。
    if (!compactFall && staggeredPieceIds == null) {
      frames.add(BoardFrame(this, FramePhase.fall));
    }
    final spawnedPieceIds = _collapse();
    frames.add(
      BoardFrame(
        this,
        FramePhase.fall,
        spawnedPieceIds: spawnedPieceIds,
        staggeredFall:
            staggeredPieceIds != null &&
            _nextSpecial(staggeredPieceIds, const {}) != null,
      ),
    );
    return wave;
  }

  ({Set<int> cells, int specialEffectsTriggered}) _scoreWave(
    Set<int> initial,
    Set<int> protected,
    int multiplier, [
    Set<int> consumedRainbows = const {},
  ]) {
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
      // 目标奖励只覆盖尚未收集的配额，超额消除仍获得正常基础分。
      if (collected[piece.kind] < (targets[piece.kind] ?? 0)) {
        score += targetAnimalBonus;
      }
      collected[piece.kind]++;
      if (ice[index] > 0) crackedIce.add(index);
      final row = index ~/ side;
      final col = index % side;
      if (row > 0) crackedIce.add(index - side);
      if (row < side - 1) crackedIce.add(index + side);
      if (col > 0) crackedIce.add(index - 1);
      if (col < side - 1) crackedIce.add(index + 1);
      score += baseAnimalScore * multiplier;
    }
    for (final index in crackedIce) {
      if (ice[index] > 0) {
        ice[index]--;
        score += iceLayerBonus;
      }
    }
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

  int? _nextSpecial(Set<int>? pieceIds, Set<int> protectedPieceIds) {
    for (var index = 0; index < cells; index++) {
      final piece = pieces[index];
      if (piece != null &&
          piece.effect != PieceEffect.none &&
          !protectedPieceIds.contains(piece.id) &&
          (pieceIds == null || pieceIds.contains(piece.id))) {
        return index;
      }
    }
    return null;
  }

  /// 彩虹组合只轮询本次转换的动物和交换搭档，不把补块自然生成的特效加入队列。
  /// 每次仍完整展开波及特效和已有自然匹配；队列耗尽后恢复普通连锁结算。
  ({int waves, int totalCleared, int specialEffectsTriggered})
  _triggerRainbowConversions({
    required List<BoardFrame> frames,
    required Set<int> initial,
    required Set<int> consumedRainbows,
    required Set<int> pieceIds,
  }) {
    var waves = 0;
    var totalCleared = 0;
    var specialEffectsTriggered = 0;
    var forced = initial;
    while (forced.isNotEmpty) {
      final runs = waves == 0 ? <List<int>>[] : matchRuns();
      final created = _createEffects(runs, -1, -1);
      for (final entry in created.entries) {
        _createSpecial(entry.key, entry.value);
      }
      final wave = _clearWave(
        frames: frames,
        initial: {...forced, for (final run in runs) ...run},
        protected: created.keys.toSet(),
        multiplier: waves + 1,
        consumedRainbows: waves == 0 ? consumedRainbows : const {},
        staggeredPieceIds: pieceIds,
      );
      waves++;
      totalCleared += wave.cells.length;
      specialEffectsTriggered += wave.specialEffectsTriggered;
      final next = _nextSpecial(pieceIds, const {});
      forced = next == null ? const {} : {next};
    }
    return (
      waves: waves,
      totalCleared: totalCleared,
      specialEffectsTriggered: specialEffectsTriggered,
    );
  }

  /// 自然连锁与自动触发共用逐波结算；每次只主动选择一只特效。
  /// 波及其他特效时仍在同波连锁，补齐逻辑棋盘后按新位置重新扫描。
  ({int waves, int totalCleared, int specialEffectsTriggered}) _settleCascades({
    required List<BoardFrame> frames,
    required int a,
    required int b,
    required int multiplier,
    Set<int> initial = const {},
    Set<int> consumedRainbows = const {},
    Set<int> protectedPieceIds = const {},
    bool automaticAll = false,
    bool compactFall = false,
  }) {
    var waves = 0;
    var totalCleared = 0;
    var specialEffectsTriggered = 0;
    final forced = {...initial};
    final automatic = automaticAll;
    // 与普通连锁一致保留有界保护，防止异常随机序列无限结算。
    // 自动逐只触发可能有更多波次，不能沿用批量触发时的较小上限。
    while (waves < (automatic ? cells * 4 : 64)) {
      final runs = matchRuns();
      if (runs.isEmpty && forced.isEmpty) {
        final index = automatic ? _nextSpecial(null, protectedPieceIds) : null;
        if (index == null) break;
        forced.add(index);
      }
      final created = forced.isEmpty
          ? _createEffects(runs, a, b)
          : <int, PieceEffect>{};
      for (final entry in created.entries) {
        _createSpecial(entry.key, entry.value);
      }
      final wave = _clearWave(
        frames: frames,
        initial: {
          ...forced,
          if (!automatic || forced.isEmpty)
            for (final run in runs) ...run,
        },
        // 自然匹配生成的特效先保留，之后才参与自动扫描。
        protected: {
          ...created.keys,
          for (var index = 0; index < cells; index++)
            if (protectedPieceIds.contains(pieces[index]?.id)) index,
        },
        multiplier: multiplier + waves,
        consumedRainbows: waves == 0 ? consumedRainbows : const {},
        compactFall: compactFall,
        naturalClear: forced.isEmpty,
      );
      forced.clear();
      waves++;
      totalCleared += wave.cells.length;
      specialEffectsTriggered += wave.specialEffectsTriggered;
    }
    return (
      waves: waves,
      totalCleared: totalCleared,
      specialEffectsTriggered: specialEffectsTriggered,
    );
  }

  void _playBonus(List<BoardFrame> frames, int a, int b, int multiplier) {
    frames.add(BoardFrame(this, FramePhase.bonus));
    int settleBonus(int multiplier) => _settleCascades(
      frames: frames,
      a: a,
      b: b,
      multiplier: multiplier,
      automaticAll: true,
      compactFall: true,
    ).waves;

    // 先处理已有特效，每次引爆后总是优先结算自然连锁。
    multiplier += settleBonus(multiplier);
    while (movesLeft > 0) {
      final ordinary = [
        for (var i = 0; i < cells; i++)
          if (pieces[i] case Piece(effect: PieceEffect.none)) i,
      ];
      final index = ordinary[_next(ordinary.length)];
      final pieceId = pieces[index]!.id;
      movesLeft--;
      moveNumber++;
      frames.add(BoardFrame.transfer(this, pieceIds: {pieceId}));
      _createSpecial(
        index,
        const [PieceEffect.row, PieceEffect.column, PieceEffect.bomb][_next(3)],
      );
      frames.add(
        BoardFrame.conversion(
          this,
          pieceIds: {pieceId},
          phase: FramePhase.bonus,
        ),
      );
      _clearWave(
        frames: frames,
        initial: {index},
        protected: const {},
        multiplier: multiplier++,
        compactFall: true,
      );
      // 自然匹配独立消除，连锁留下的特效也不必等剩余步数耗尽才自动引爆。
      multiplier += settleBonus(multiplier);
    }
  }

  int _playFixedBonus(List<BoardFrame> frames, int a, int b, int multiplier) {
    const never = 1 << 30;
    frames.add(BoardFrame(this, FramePhase.bonus, bonusAt: 0));
    var waitingForOpeningClear =
        movesLeft > 0 && _nextSpecial(null, const {}) != null;
    var transferAt = movesLeft > 0 && !waitingForOpeningClear
        ? BonusTiming.firstTransfer
        : never;
    var convertedAt = never;
    var scanAt = 0;
    var autoAt = BonusTiming.autoIgnition;
    var boardReadyAt = 0;
    var now = 0;
    int? startedAt;
    int? targetId;
    final activeClears = <({int fallAt, BoardFrame frame})>[];
    final clearingIds = <int>{};
    final landsAt = <int, int>{};
    var spawned = const <int>{};
    final convertedIgnitionAt = <int, int>{};
    final cascadeIgnitionAt = <int, int>{};

    int nextFallAt() =>
        activeClears.isEmpty ? never : activeClears.first.fallAt;
    int autoIgnitionAt(int id) => math.max(autoAt, cascadeIgnitionAt[id] ?? 0);

    int pickTarget() {
      final candidates = [
        for (var i = 0; i < cells; i++)
          if (pieces[i] case Piece(:final id, effect: PieceEffect.none)
              when !clearingIds.contains(id))
            i,
      ];
      return candidates.isEmpty ? -1 : candidates[_next(candidates.length)];
    }

    void retarget() {
      final index = pickTarget();
      targetId = index < 0 ? null : pieces[index]!.id;
    }

    void present(
      FramePhase phase, {
      Set<int> converted = const {},
      BoardFrame? wave,
    }) {
      frames.add(
        BoardFrame(
          this,
          phase,
          bonusAt: now,
          clearing: wave?.clearing ?? const {},
          naturalClear: wave?.naturalClear ?? false,
          spawnedPieceIds: spawned,
          transferringPieceIds: {
            if (phase == FramePhase.transfer && targetId != null) targetId!,
          },
          convertedPieceIds: converted,
          activeClears: [for (final clear in activeClears) clear.frame],
          clearingPieceIds: clearingIds,
          crackedIce: wave?.crackedIce,
          bonusFalling: now < boardReadyAt,
          bonusTransferTargetId: targetId,
          bonusTransferStartedAt: startedAt,
        ),
      );
    }

    var waves = 0;
    void beginClear(Set<int> initial, {Map<int, PieceEffect>? created}) {
      final protected = {
        for (var i = 0; i < cells; i++)
          if (clearingIds.contains(pieces[i]?.id)) i,
        ...?created?.keys,
      };
      final iceBefore = List<int>.of(ice);
      final wave = _scoreWave(initial, protected, multiplier++);
      waves++;
      final frame = BoardFrame(
        this,
        FramePhase.clear,
        bonusAt: now,
        clearing: wave.cells,
        naturalClear: created != null,
        crackedIce: {
          for (var i = 0; i < cells; i++)
            if (ice[i] < iceBefore[i]) i,
        },
      );
      clearingIds.addAll(frame.clearingPieceIds);
      for (final id in frame.clearingPieceIds) {
        convertedIgnitionAt.remove(id);
        cascadeIgnitionAt.remove(id);
        landsAt.remove(id);
      }
      activeClears.add((fallAt: now + BonusTiming.clear, frame: frame));
      if (targetId != null &&
          (clearingIds.contains(targetId) ||
              (created?.keys.any((i) => pieces[i]?.id == targetId) ?? false))) {
        retarget();
      }
      present(FramePhase.clear, wave: frame);
    }

    // 转换特效的到期事件独立于棋盘扫描，可在另一波消除或坠落中引爆。
    while (true) {
      final fallAt = nextFallAt();
      final ignitionAt = convertedIgnitionAt.values.fold(never, math.min);
      final at = math.min(
        math.min(transferAt, convertedAt),
        math.min(math.min(fallAt, scanAt), ignitionAt),
      );
      if (at == never) break;
      if (at != now) spawned = const {};
      now = at;
      if (now == fallAt) {
        // 同一时刻完成的消除一起补块；其他波仍按各自的棋子身份继续播放。
        final finished = <int>{};
        while (nextFallAt() == now) {
          finished.addAll(activeClears.removeAt(0).frame.clearingPieceIds);
        }
        for (var i = 0; i < cells; i++) {
          if (finished.contains(pieces[i]?.id)) pieces[i] = null;
        }
        clearingIds.removeAll(finished);
        final before = List<Piece?>.of(pieces);
        spawned = _collapse();
        boardReadyAt = now + BonusTiming.fall;
        for (var i = 0; i < cells; i++) {
          final piece = pieces[i]!;
          if (piece.id != before[i]?.id && !clearingIds.contains(piece.id)) {
            landsAt[piece.id] = boardReadyAt;
          }
        }
        if (startedAt != null && targetId == null) {
          retarget();
          if (convertedAt == never) convertedAt = now;
        }
        scanAt = math.min(scanAt, boardReadyAt);
        present(FramePhase.fall);
      } else if (now == scanAt) {
        landsAt.removeWhere((_, at) => at <= now);
        // 后一次补块不会推迟已经落地的棋子参与自然匹配。
        scanAt = landsAt.values.fold(never, math.min);
        if (now < boardReadyAt) scanAt = math.min(scanAt, boardReadyAt);
        // 极端随机序列由最终洗牌兜底；达到上限后不再生成新的连锁特效。
        final runs = waves < (initialMoves + 1) * cells * 4
            ? _matchRuns({
                for (var i = 0; i < cells; i++)
                  if (clearingIds.contains(pieces[i]?.id) ||
                      landsAt.containsKey(pieces[i]?.id))
                    i,
              })
            : const <List<int>>[];
        if (runs.isNotEmpty) {
          final created = _createEffects(runs, a, b);
          for (final entry in created.entries) {
            _createSpecial(entry.key, entry.value);
            cascadeIgnitionAt[pieces[entry.key]!.id] =
                now + BonusTiming.autoIgnition;
          }
          beginClear({for (final run in runs) ...run}, created: created);
        } else if (activeClears.isEmpty &&
            now >= boardReadyAt &&
            now != ignitionAt) {
          final due = pieces.indexWhere(
            (piece) =>
                piece != null &&
                piece.effect != PieceEffect.none &&
                !convertedIgnitionAt.containsKey(piece.id) &&
                autoIgnitionAt(piece.id) <= now,
          );
          if (due >= 0) {
            autoAt =
                now +
                BonusTiming.clear +
                BonusTiming.fall +
                BonusTiming.autoIgnition;
            beginClear({due});
          } else {
            for (final piece in pieces.whereType<Piece>()) {
              if (piece.effect != PieceEffect.none &&
                  !convertedIgnitionAt.containsKey(piece.id)) {
                scanAt = math.min(scanAt, autoIgnitionAt(piece.id));
              }
            }
            // 开场特效和后续连锁全部结算、棋盘落稳后，才启动第一次转换。
            if (waitingForOpeningClear && scanAt == never) {
              waitingForOpeningClear = false;
              transferAt = now;
            }
          }
        }
      } else if (now == ignitionAt) {
        beginClear({
          for (var i = 0; i < cells; i++)
            if (convertedIgnitionAt[pieces[i]?.id] == now) i,
        });
      } else if (now == convertedAt) {
        convertedAt = never;
        if (targetId == null ||
            !pieces.any(
              (piece) =>
                  piece?.id == targetId && piece?.effect == PieceEffect.none,
            )) {
          retarget();
        }
        if (targetId == null) {
          // 全盘消除期间没有普通动物，将这次落点放到补块之后。
          convertedAt = nextFallAt();
          continue;
        }
        final id = targetId!;
        final index = pieces.indexWhere((piece) => piece?.id == id);
        _createSpecial(
          index,
          const [PieceEffect.row, PieceEffect.column, PieceEffect.bomb][_next(
            3,
          )],
        );
        convertedIgnitionAt[id] = now + BonusTiming.ignition;
        startedAt = null;
        targetId = null;
        present(FramePhase.bonus, converted: {id});
      } else {
        assert(now == transferAt && convertedAt == never);
        movesLeft--;
        moveNumber++;
        transferAt = movesLeft > 0 ? now + BonusTiming.transferInterval : never;
        startedAt = now;
        convertedAt = now + BonusTiming.transfer;
        retarget();
        present(FramePhase.transfer);
      }
    }
    return now;
  }

  SwapResult? playSwap(
    int a,
    int b, {
    BonusPacing bonusPacing = BonusPacing.fixedBeat,
  }) {
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
    int? conversionSourcePieceId;
    final rainbowActivationIds = <int>{};
    final pairedRainbowIds = <int>{};
    if (special) {
      final effectA = pieces[a]!.effect;
      final effectB = pieces[b]!.effect;
      final rainbowA = effectA == PieceEffect.rainbow;
      final rainbowB = effectB == PieceEffect.rainbow;
      if (rainbowA || rainbowB) {
        forced.addAll({a, b});
        if (rainbowA && rainbowB) {
          // 双彩虹保留到最终全盘消除；先自动处理其余特效，避免它们提前被波及触发。
          pairedRainbowIds.addAll({pieces[a]!.id, pieces[b]!.id});
          forced.clear();
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
          if (comboEffect != null) {
            // 彩虹只消耗自己，转换后的动物随后逐只触发，而不是同时加入消除集合。
            forced
              ..clear()
              ..add(rainbowIndex);
            rainbowActivationIds.add(pieces[partnerIndex]!.id);
            conversionSourcePieceId = pieces[rainbowIndex]!.id;
          }
          for (var index = 0; index < cells; index++) {
            final piece = pieces[index];
            if (piece?.kind != kind) continue;
            if (comboEffect == null) forced.add(index);
            if (comboEffect != null &&
                index != rainbowIndex &&
                piece!.effect == PieceEffect.none) {
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
    final convertedIds = {
      for (final index in transformedEffects.keys) pieces[index]!.id,
    };
    if (convertedIds.isNotEmpty) {
      frames.add(
        BoardFrame.transfer(
          this,
          pieceIds: convertedIds,
          sourcePieceId: conversionSourcePieceId,
        ),
      );
      for (final entry in transformedEffects.entries) {
        _createSpecial(entry.key, entry.value);
      }
      frames.add(BoardFrame.conversion(this, pieceIds: convertedIds));
    }
    final initialMatchCount = matchRuns().expand((run) => run).toSet().length;
    final rainbowResolution = rainbowActivationIds.isEmpty
        ? (waves: 0, totalCleared: 0, specialEffectsTriggered: 0)
        : _triggerRainbowConversions(
            frames: frames,
            initial: forced,
            consumedRainbows: {a, b},
            pieceIds: {...rainbowActivationIds, ...convertedIds},
          );
    var resolution = _settleCascades(
      frames: frames,
      a: a,
      b: b,
      multiplier: rainbowResolution.waves + 1,
      initial: rainbowActivationIds.isEmpty ? forced : const {},
      consumedRainbows: special ? {a, b} : {},
      automaticAll: pairedRainbowIds.isNotEmpty,
      protectedPieceIds: pairedRainbowIds,
    );
    resolution = (
      waves: rainbowResolution.waves + resolution.waves,
      totalCleared: rainbowResolution.totalCleared + resolution.totalCleared,
      specialEffectsTriggered:
          rainbowResolution.specialEffectsTriggered +
          resolution.specialEffectsTriggered,
    );
    if (pairedRainbowIds.isNotEmpty) {
      // 此时所有其他特效、坠落和自然连锁均已处理，最后再清空整个稳定棋盘。
      final finalClear = _settleCascades(
        frames: frames,
        a: a,
        b: b,
        multiplier: resolution.waves + 1,
        initial: {for (var index = 0; index < cells; index++) index},
      );
      resolution = (
        waves: resolution.waves + finalClear.waves,
        totalCleared: resolution.totalCleared + finalClear.totalCleared,
        specialEffectsTriggered:
            resolution.specialEffectsTriggered +
            finalClear.specialEffectsTriggered,
      );
    }
    final cascades = resolution.waves;
    final actionEndIndex = frames.length;
    int? bonusEnd;
    if (goalsMet && movesLeft > 0) {
      // 只有剩余步数才开启奖励；本次行动的棋盘先单独保留一帧。
      frames.add(BoardFrame(this, FramePhase.settled));
      switch (bonusPacing) {
        case BonusPacing.fixedBeat:
          bonusEnd = _playFixedBonus(frames, a, b, cascades + 1);
        case BonusPacing.waitForFall:
          _playBonus(frames, a, b, cascades + 1);
      }
    }
    _ensurePlayable();
    frames.add(BoardFrame(this, FramePhase.settled, bonusAt: bonusEnd));
    return SwapResult(
      List.unmodifiable(frames),
      cascades,
      score - previousScore,
      reshuffles != previousShuffles,
      initialMatchCount,
      resolution.totalCleared,
      resolution.specialEffectsTriggered,
      actionEndIndex: actionEndIndex,
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
