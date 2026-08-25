import 'dart:math';
import 'package:flutter/foundation.dart';

import 'base.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 评估参数 — 围棋启发式分量权重集中管理
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class GoEvalParams {
  static const captureWeight = 1000; // 提子价值（棋子数差）
  static const atariWeight = 200; // 打吃（棋链气=1）
  static const libertyWeight = 5; // 气安全（带上限）
  static const connectionWeight = 10; // 连接（棋链大小）
  static const positionWeight = 8; // 位置（边线-，三/四线+）
}

/// 围棋 AI 难度
enum GoAiDifficulty { easy, normal, hard }

/// 难度配置：搜索深度 / 候选半径 / 候选数上限 / 随机性 / 时间预算
class _DifficultyConfig {
  final int depth;
  final int radius;
  final int topK;
  final double randomness;
  final int timeBudgetMs;
  const _DifficultyConfig(
    this.depth,
    this.radius,
    this.topK,
    this.randomness,
    this.timeBudgetMs,
  );

  static const easy = _DifficultyConfig(1, 1, 12, 0.3, 600);
  static const normal = _DifficultyConfig(2, 2, 14, 0.0, 1500);
  static const hard = _DifficultyConfig(3, 2, 16, 0.0, 3000);
}

_DifficultyConfig _config(GoAiDifficulty d) => switch (d) {
  GoAiDifficulty.easy => _DifficultyConfig.easy,
  GoAiDifficulty.normal => _DifficultyConfig.normal,
  GoAiDifficulty.hard => _DifficultyConfig.hard,
};

// ═══════════════════════════════════════════════════════════════════════════════
// 搜索棋盘 — 纯数据，do/undo 含提子，规则逻辑委托 GoRules
// ═══════════════════════════════════════════════════════════════════════════════

class GoSearchBoard {
  final int size;
  final List<StoneState> cells;

  GoSearchBoard(this.cells, this.size);

  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  /// do/undo：落子（含提子）→ 跑 fn → 撤回（恢复落子位 + 提子位）
  T withMove<T>(int idx, StoneState player, T Function() fn) {
    final result = GoRules.tryPlace(cells, size, idx, player);
    if (!result.ok) return fn(); // 非法着法（generateCandidates 已过滤，兜底）
    final res = fn();
    // undo：恢复落子位为空、提子位为对方
    cells[idx] = StoneState.empty;
    final opp = GoRules.opponent(player);
    for (final c in result.captured) {
      cells[c] = opp;
    }
    return res;
  }

  /// 候选周围 1 格内的非空格数（轻量热度，用于 minimax 内 move ordering）
  int _heat(int idx) {
    final r = idx ~/ size, c = idx % size;
    int n = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr, nc = c + dc;
        if (inBounds(nr, nc) && cells[nr * size + nc] != StoneState.empty) n++;
      }
    }
    return n;
  }

  /// 生成候选：已有棋子周围 radius 格内空位，去重 + 合法过滤（非自杀）。
  /// player 用于合法判定，self 用于 scorePoint 排序（进攻+防守）。
  /// sort=true 用 scorePoint 精排（root），sort=false 用 _heat 轻排（minimax 内）
  List<int> generateCandidates(
    StoneState player,
    StoneState self, {
    int radius = 2,
    int topK = 16,
    bool sort = true,
  }) {
    final set = <int>{};
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] != StoneState.empty) continue;
      final r = i ~/ size, c = i % size;
      for (int dr = -radius; dr <= radius; dr++) {
        for (int dc = -radius; dc <= radius; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = r + dr, nc = c + dc;
          if (inBounds(nr, nc) && cells[nr * size + nc] == StoneState.empty) {
            set.add(nr * size + nc);
          }
        }
      }
    }

    // 合法过滤（tryPlace + 立即 undo）
    final legal = <int>[];
    final opp = GoRules.opponent(player);
    for (final i in set) {
      final result = GoRules.tryPlace(cells, size, i, player);
      if (result.ok) {
        legal.add(i);
        cells[i] = StoneState.empty;
        for (final c in result.captured) {
          cells[c] = opp;
        }
      }
    }

    if (sort) {
      final enemy = GoRules.opponent(self);
      legal.sort((a, b) {
        final sa = GoEvaluator.scorePoint(this, b, self) +
            GoEvaluator.scorePoint(this, b, enemy);
        final sb = GoEvaluator.scorePoint(this, a, self) +
            GoEvaluator.scorePoint(this, a, enemy);
        return sa - sb;
      });
    } else {
      legal.sort((a, b) => _heat(b) - _heat(a));
    }

    if (legal.length > topK) return legal.sublist(0, topK);
    return legal;
  }

  int evaluate(StoneState self) => GoEvaluator.evaluate(this, self);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 评估引擎 — 提子差 + 气安全/打吃 + 连接 + 位置（围棋启发式）
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class GoEvaluator {
  /// 全盘评估：己方分量 − 对方分量
  static int evaluate(GoSearchBoard board, StoneState self) {
    final enemy = GoRules.opponent(self);
    final cells = board.cells;
    final size = board.size;
    int score = 0;

    // 棋子数差（提子直接体现）
    int selfCount = 0, enemyCount = 0;
    for (final s in cells) {
      if (s == self) {
        selfCount++;
      } else if (s == enemy) {
        enemyCount++;
      }
    }
    score += (selfCount - enemyCount) * GoEvalParams.captureWeight;

    // 棋链：气安全 / 打吃 / 连接
    final visited = <int>{};
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == StoneState.empty || visited.contains(i)) continue;
      final g = GoRules.findGroup(cells, size, i);
      visited.addAll(g);
      final libs = GoRules.groupLiberties(cells, size, g);
      final sign = cells[i] == self ? 1 : -1;
      score += sign * (libs < 4 ? libs : 4) * GoEvalParams.libertyWeight;
      if (libs == 1) {
        score -= sign * GoEvalParams.atariWeight; // 己方被打吃扣，对方被打吃加
      }
      score += sign * (g.length - 1) * GoEvalParams.connectionWeight;
    }

    // 位置分
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == StoneState.empty) continue;
      final sign = cells[i] == self ? 1 : -1;
      score += sign * _positionScore(i, size) * GoEvalParams.positionWeight;
    }

    return score;
  }

  /// 单点评估（move ordering / 贪心用）：假设 player 落 idx 的价值
  static int scorePoint(GoSearchBoard board, int idx, StoneState player) {
    final size = board.size;
    final cells = List<StoneState>.of(board.cells); // 副本，不改原棋盘
    final result = GoRules.tryPlace(cells, size, idx, player);
    if (!result.ok) return -1;

    int score = result.captured.length * GoEvalParams.captureWeight;
    final enemy = GoRules.opponent(player);

    // 打吃：四邻对方棋链气=1
    for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final r = idx ~/ size + dr, c = idx % size + dc;
      if (r < 0 || r >= size || c < 0 || c >= size) continue;
      final ni = r * size + c;
      if (cells[ni] == enemy) {
        final g = GoRules.findGroup(cells, size, ni);
        if (GoRules.groupLiberties(cells, size, g) == 1) {
          score += GoEvalParams.atariWeight;
        }
      }
    }

    score += _positionScore(idx, size) * GoEvalParams.positionWeight;
    return score;
  }

  /// 位置分：一线 −2，二线 −1，三线 +1，四线及以上 +2
  static int _positionScore(int idx, int size) {
    final r = idx ~/ size, c = idx % size;
    int edge = r;
    if (c < edge) edge = c;
    if (size - 1 - r < edge) edge = size - 1 - r;
    if (size - 1 - c < edge) edge = size - 1 - c;
    if (edge == 0) return -2;
    if (edge == 1) return -1;
    if (edge == 2) return 1;
    return 2;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 搜索引擎 — Minimax + Alpha-Beta + 迭代加深 IDS
// 围棋无连五短路，靠 move ordering（提子/打吃优先）提升剪枝
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class GoSearchEngine {
  static final _rng = Random();

  static int? search(
    GoSearchBoard board,
    StoneState self,
    GoAiDifficulty diff,
    int timeBudgetMs,
  ) {
    final cfg = _config(diff);
    final deadline = DateTime.now().add(Duration(milliseconds: timeBudgetMs));

    final rootCands = board.generateCandidates(
      self,
      self,
      radius: cfg.radius,
      topK: cfg.topK,
      sort: true,
    );

    // 空盘 → 天元（无候选时避免卡在 AI 回合）
    if (rootCands.isEmpty) {
      final c = (board.size ~/ 2) * board.size + board.size ~/ 2;
      return board.cells[c] == StoneState.empty ? c : null;
    }

    // 迭代加深：逐层加深至目标深度或超时
    int? best = rootCands.first;
    for (int depth = 1; depth <= cfg.depth; depth++) {
      final (move, score) = _rootSearch(board, depth, self, cfg, deadline);
      if (move != null) best = move;
      _GoAiLog.d('depth=$depth best=$best score=$score');
      if (DateTime.now().isAfter(deadline)) break;
    }

    // 简单难度：按概率从前 3 候选随机
    if (cfg.randomness > 0 &&
        best != null &&
        _rng.nextDouble() < cfg.randomness) {
      final pool = rootCands.take(3).where((c) => c != best).toList();
      if (pool.isNotEmpty) best = pool[_rng.nextInt(pool.length)];
    }
    return best;
  }

  static (int?, int) _rootSearch(
    GoSearchBoard board,
    int depth,
    StoneState self,
    _DifficultyConfig cfg,
    DateTime deadline,
  ) {
    final cands = board.generateCandidates(
      self,
      self,
      radius: cfg.radius,
      topK: cfg.topK,
      sort: true,
    );
    if (cands.isEmpty) return (null, board.evaluate(self));

    int? bestMove;
    int bestScore = -0x7FFFFFFF;
    int alpha = -0x7FFFFFFF;
    const beta = 0x7FFFFFFF;
    for (final c in cands) {
      final v = board.withMove(
        c,
        self,
        () => _minimax(board, depth - 1, alpha, beta, false, self, cfg, deadline),
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

  static int _minimax(
    GoSearchBoard board,
    int depth,
    int alpha,
    int beta,
    bool isMax,
    StoneState self,
    _DifficultyConfig cfg,
    DateTime deadline,
  ) {
    if (depth == 0 || DateTime.now().isAfter(deadline)) {
      return board.evaluate(self);
    }
    final player = isMax ? self : GoRules.opponent(self);
    final cands = board.generateCandidates(
      player,
      self,
      radius: cfg.radius,
      topK: cfg.topK,
      sort: false,
    );
    if (cands.isEmpty) return board.evaluate(self);

    int best = isMax ? -0x7FFFFFFF : 0x7FFFFFFF;
    for (final c in cands) {
      final v = board.withMove(
        c,
        player,
        () =>
            _minimax(board, depth - 1, alpha, beta, !isMax, self, cfg, deadline),
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

// ═══════════════════════════════════════════════════════════════════════════════
// AI 控制器 — 对外接口，compute() 在后台 isolate 执行搜索
// ═══════════════════════════════════════════════════════════════════════════════

class GoAiController {
  final StoneState faction;
  final GoAiDifficulty difficulty;
  final int size;
  final ValueNotifier<bool> thinking = ValueNotifier(false);

  GoAiController({
    required this.size,
    required this.faction,
    this.difficulty = GoAiDifficulty.normal,
  });

  /// 异步获取最佳着法。每次接收当前局面快照（无内部状态）
  Future<int?> getAction(List<StoneState> rawSnapshot) async {
    thinking.value = true;
    try {
      return await compute(
        _goSearchEntry,
        _GoSearchArgs(
          board: [for (final s in rawSnapshot) s.index],
          size: size,
          self: faction.index,
          difficulty: difficulty.index,
          timeBudgetMs: _config(difficulty).timeBudgetMs,
        ),
      );
    } catch (e) {
      _GoAiLog.d('搜索异常 $e');
      return null;
    } finally {
      // 控制器可能已被替换/释放（重开、切难度、关 AI），设值容错
      try {
        thinking.value = false;
      } catch (_) {}
    }
  }

  void dispose() => thinking.dispose();
}

/// compute 入口参数（须可跨 isolate 序列化，用 int index 表示 StoneState）
class _GoSearchArgs {
  final List<int> board;
  final int size;
  final int self;
  final int difficulty;
  final int timeBudgetMs;
  const _GoSearchArgs({
    required this.board,
    required this.size,
    required this.self,
    required this.difficulty,
    required this.timeBudgetMs,
  });
}

/// isolate 入口：重建 GoSearchBoard 并搜索
@pragma('vm:entry-point')
int? _goSearchEntry(_GoSearchArgs args) {
  final cells = [for (final v in args.board) StoneState.values[v]];
  final board = GoSearchBoard(cells, args.size);
  return GoSearchEngine.search(
    board,
    StoneState.values[args.self],
    GoAiDifficulty.values[args.difficulty],
    args.timeBudgetMs,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 日志（默认关闭，调试时置 enabled = true）
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class _GoAiLog {
  static bool enabled = false;
  static void d(String msg) {
    if (enabled) debugPrint('[GoAI] $msg');
  }
}
