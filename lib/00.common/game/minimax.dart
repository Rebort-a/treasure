import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════════════
// 通用 AI 搜索框架 — 难度配置 / 可搜索局面接口 / Minimax+Alpha-Beta+IDS
// 各棋（gobang/weiqi 等）实现 SearchableBoard + Evaluator，复用本框架的搜索算法。
// animal_chess 因翻牌期望值/Zobrist/同步 AI 的不同模式，不纳入本框架。
// ═══════════════════════════════════════════════════════════════════════════════

/// 难度配置：搜索深度 / 候选半径 / 候选数上限 / 随机性 / 时间预算。
/// 各游戏的 easy/normal/hard 实例化为该类的常量。
class DifficultyConfig {
  final int depth;
  final int radius;
  final int topK;
  final double randomness;
  final int timeBudgetMs;
  const DifficultyConfig(
    this.depth,
    this.radius,
    this.topK,
    this.randomness,
    this.timeBudgetMs,
  );
}

/// 可搜索局面接口。P 为玩家标识类型（gobang: int，weiqi: StoneState）。
abstract class SearchableBoard<P> {
  /// 棋盘边长（空盘天元 fallback 用）
  int get size;

  /// idx 处是否空（空盘 fallback 判断）
  bool isEmptyAt(int idx);

  /// 评估当前局面（self 视角）
  int evaluate(P self);

  /// do/undo：player 落 idx → 跑 fn → 撤回
  T withMove<T>(int idx, P player, T Function() fn);

  /// 对手
  P opponent(P p);

  /// 统一候选生成（接口方法）。
  /// - [player] 当前轮玩家（weiqi 用于合法性过滤；gobang 候选与颜色无关，可忽略）
  /// - [self] 评估视角（用于排序）
  /// - [cfg] 提供 radius/topK
  /// - [sort] true 精排（root），false 轻量热度排（minimax 内部）
  /// 各棋实现时委托给自身 generateCandidates。
  List<int> candidates(P player, P self, DifficultyConfig cfg, bool sort);
}

/// 通用搜索引擎：Minimax + Alpha-Beta 剪枝 + 迭代加深 IDS + 时间预算 deadline。
abstract final class Minimax {
  static final _rng = Random();

  /// 通用搜索入口。
  /// - [shortcuts] 游戏特定强制着法（如五子棋必胜必堵），返回非 null 即直接采用。
  /// 空盘返回天元；超时返回当前最佳；简单难度按概率随机失误。
  static int? search<P>(
    SearchableBoard<P> board,
    P self,
    DifficultyConfig cfg,
    int timeBudgetMs, {
    int? Function(List<int> rootCands)? shortcuts,
  }) {
    final deadline = DateTime.now().add(Duration(milliseconds: timeBudgetMs));

    final rootCands = board.candidates(self, self, cfg, true);

    // 空盘 → 天元（无候选时避免卡在 AI 回合）
    if (rootCands.isEmpty) {
      final c = (board.size ~/ 2) * board.size + board.size ~/ 2;
      return board.isEmptyAt(c) ? c : null;
    }

    // 游戏特定短路（如必胜必堵）
    final forced = shortcuts?.call(rootCands);
    if (forced != null) return forced;

    // 迭代加深：逐层加深至目标深度或超时，超时返回当前最佳
    int? best = rootCands.first;
    for (int depth = 1; depth <= cfg.depth; depth++) {
      final (move, score) = _rootSearch(board, depth, self, cfg, deadline);
      if (move != null) best = move;
      if (DateTime.now().isAfter(deadline)) break;
    }

    // 简单难度：按概率从前 3 候选随机（制造失误）
    if (cfg.randomness > 0 &&
        best != null &&
        _rng.nextDouble() < cfg.randomness) {
      final pool = rootCands.take(3).where((c) => c != best).toList();
      if (pool.isNotEmpty) best = pool[_rng.nextInt(pool.length)];
    }
    return best;
  }

  static (int?, int) _rootSearch<P>(
    SearchableBoard<P> board,
    int depth,
    P self,
    DifficultyConfig cfg,
    DateTime deadline,
  ) {
    final cands = board.candidates(self, self, cfg, true);
    if (cands.isEmpty) return (null, board.evaluate(self));

    int? bestMove;
    int bestScore = -0x7FFFFFFF;
    int alpha = -0x7FFFFFFF;
    const beta = 0x7FFFFFFF;
    for (final c in cands) {
      final v = board.withMove(
        c,
        self,
        () =>
            _minimax(board, depth - 1, alpha, beta, false, self, cfg, deadline),
      );
      if (v > bestScore) {
        bestScore = v;
        bestMove = c;
      }
      if (v > alpha) alpha = v;
      if (DateTime.now().isAfter(deadline)) break;
    }
    return (bestMove, bestScore);
  }

  static int _minimax<P>(
    SearchableBoard<P> board,
    int depth,
    int alpha,
    int beta,
    bool isMax,
    P self,
    DifficultyConfig cfg,
    DateTime deadline,
  ) {
    if (depth == 0 || DateTime.now().isAfter(deadline)) {
      return board.evaluate(self);
    }
    final player = isMax ? self : board.opponent(self);
    final cands = board.candidates(player, self, cfg, false);
    if (cands.isEmpty) return board.evaluate(self);

    int best = isMax ? -0x7FFFFFFF : 0x7FFFFFFF;
    for (final c in cands) {
      final v = board.withMove(
        c,
        player,
        () => _minimax(
          board,
          depth - 1,
          alpha,
          beta,
          !isMax,
          self,
          cfg,
          deadline,
        ),
      );
      if (isMax) {
        if (v > best) best = v;
        if (best > alpha) alpha = best;
      } else {
        if (v < best) best = v;
        if (best < beta) beta = best;
      }
      if (beta <= alpha) break; // Alpha-Beta 剪枝
      if (DateTime.now().isAfter(deadline)) break;
    }
    return best;
  }
}
