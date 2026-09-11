import 'package:flutter/foundation.dart';

import '../00.common/game/gamer.dart';
import '../00.common/game/search/minimax.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 评估参数 — 棋型分值与难度配置集中管理
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class EvalParams {
  static const boardSize = 15;
  static const winLen = 5;

  static const winScore = 100000; // 连五
  static const liveFour = 10000; // 活四
  static const rushFour = 1000; // 冲四（含跳冲四）
  static const liveThree = 1000; // 活三（含跳活三）
  static const sleepThree = 100; // 眠三
  static const liveTwo = 100; // 活二
  static const sleepTwo = 10; // 眠二
}

/// AI 难度
enum AiDifficulty { easy, normal, hard }

/// 难度配置（复用通用 DifficultyConfig）
DifficultyConfig _config(AiDifficulty d) => switch (d) {
  AiDifficulty.easy => const DifficultyConfig(2, 1, 12, 0.3, 600),
  AiDifficulty.normal => const DifficultyConfig(4, 2, 10, 0.0, 1500),
  AiDifficulty.hard => const DifficultyConfig(6, 2, 12, 0.0, 3000),
};

// ═══════════════════════════════════════════════════════════════════════════════
// 棋型模式表 — 字符串模式匹配（1=己方 0=空 2=阻挡/边界）
// 按分值降序排列，消费法保证高分棋型优先匹配，避免低分模式抢占子串
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class _PatternTable {
  static const patterns = <(String, int)>[
    // 连五
    ('11111', EvalParams.winScore),
    // 活四（两端开放）
    ('011110', EvalParams.liveFour),
    // 冲四（四连一端封 + 跳冲四）
    ('211110', EvalParams.rushFour),
    ('011112', EvalParams.rushFour),
    ('11011', EvalParams.rushFour),
    ('10111', EvalParams.rushFour),
    ('11101', EvalParams.rushFour),
    // 活三（连续 + 跳活三）
    ('01110', EvalParams.liveThree),
    ('010110', EvalParams.liveThree),
    ('011010', EvalParams.liveThree),
    // 眠三
    ('211100', EvalParams.sleepThree),
    ('001112', EvalParams.sleepThree),
    ('010112', EvalParams.sleepThree),
    ('211010', EvalParams.sleepThree),
    ('011012', EvalParams.sleepThree),
    ('210110', EvalParams.sleepThree),
    ('10011', EvalParams.sleepThree),
    ('11001', EvalParams.sleepThree),
    ('10101', EvalParams.sleepThree),
    // 活二（连续 + 跳活二）
    ('01100', EvalParams.liveTwo),
    ('00110', EvalParams.liveTwo),
    ('01010', EvalParams.liveTwo),
    ('010010', EvalParams.liveTwo),
    // 眠二
    ('211000', EvalParams.sleepTwo),
    ('000112', EvalParams.sleepTwo),
    ('00100', EvalParams.sleepTwo),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// 评估引擎 — 全盘评估（minimax 叶子）+ 单点评估（move ordering / 贪心）
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class Evaluator {
  /// 全盘评估：己方棋型总分 - 对方棋型总分
  static int evaluate(SearchBoard board, int self) {
    final enemy = self == 1 ? 2 : 1;
    int score = 0;
    for (final (dr, dc) in SearchBoard.directions) {
      for (final line in board.lines(dr, dc)) {
        score += _evaluateLine(_buildLine(line, self));
        score -= _evaluateLine(_buildLine(line, enemy));
      }
    }
    return score;
  }

  /// 单点评估：假设 player 落 idx，4 方向局部棋型分之和
  static int scorePoint(SearchBoard board, int idx, int player) {
    final size = board.size;
    final row = idx ~/ size, col = idx % size;
    int total = 0;
    board.cells[idx] = player;
    for (final (dr, dc) in SearchBoard.directions) {
      final line = <int>[];
      for (int k = -4; k <= 4; k++) {
        final r = row + dr * k, c = col + dc * k;
        line.add(board.inBounds(r, c) ? board.cells[r * size + c] : -1);
      }
      total += _evaluateLine(_buildLine(line, player));
    }
    board.cells[idx] = 0;
    return total;
  }

  /// 消费法逐模式匹配：命中即替换为 '#' 防止重叠重复计分
  static int _evaluateLine(String line) {
    int total = 0;
    for (final (pattern, value) in _PatternTable.patterns) {
      int start = 0;
      while (true) {
        final i = line.indexOf(pattern, start);
        if (i < 0) break;
        total += value;
        line = line.replaceRange(i, i + pattern.length, '#' * pattern.length);
        start = i + 1;
      }
    }
    return total;
  }

  /// 线 → 模式串：player→'1'，空→'0'，其他(含越界 -1)→'2'，两端补哨兵 '2'
  static String _buildLine(List<int> line, int player) {
    final sb = StringBuffer('2');
    for (final v in line) {
      sb.write(v == player ? '1' : (v == 0 ? '0' : '2'));
    }
    sb.write('2');
    return sb.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 搜索棋盘 — 可变副本，do/undo + 候选生成 + 连五检测
// 编码：0=空 1=己 2=敌（视角化，构造时由 AiController 转换）
// 实现 SearchableBoard<int>，候选/评估算法由通用 Minimax 调度。
// ═══════════════════════════════════════════════════════════════════════════════

class SearchBoard implements SearchableBoard<int> {
  @override
  final int size;
  final List<int> cells;

  SearchBoard(this.cells, this.size);

  static const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  /// 连五检测
  bool checkWin(int idx, int player) {
    final row = idx ~/ size, col = idx % size;
    for (final (dr, dc) in directions) {
      int count = 1;
      for (int d = -1; d <= 1; d += 2) {
        int r = row + dr * d, c = col + dc * d;
        while (inBounds(r, c) && cells[r * size + c] == player) {
          count++;
          r += dr * d;
          c += dc * d;
        }
      }
      if (count >= EvalParams.winLen) return true;
    }
    return false;
  }

  /// 假设 player 落 idx 能否成五（不改棋盘状态）
  bool canWin(int idx, int player) {
    if (cells[idx] != 0) return false;
    cells[idx] = player;
    final win = checkWin(idx, player);
    cells[idx] = 0;
    return win;
  }

  /// do/undo：落子 → 跑 fn → 撤回（五子棋落子单点，undo 仅置空）
  @override
  T withMove<T>(int idx, int player, T Function() fn) {
    cells[idx] = player;
    final result = fn();
    cells[idx] = 0;
    return result;
  }

  /// 提取某方向的所有线（每条 ≥ winLen 格），用于全盘模式匹配
  List<List<int>> lines(int dr, int dc) {
    final result = <List<int>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (inBounds(r - dr, c - dc)) continue; // 非起点
        final line = <int>[];
        int cr = r, cc = c;
        while (inBounds(cr, cc)) {
          line.add(cells[cr * size + cc]);
          cr += dr;
          cc += dc;
        }
        if (line.length >= EvalParams.winLen) result.add(line);
      }
    }
    return result;
  }

  /// 候选周围 1 格内的非空格数（轻量热度，用于 minimax 内部 move ordering）
  int _heat(int idx) {
    final row = idx ~/ size, col = idx % size;
    int n = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr, c = col + dc;
        if (inBounds(r, c) && cells[r * size + c] != 0) n++;
      }
    }
    return n;
  }

  /// 生成候选：已有棋子周围 radius 格内空位，去重。
  /// sort=true 用 scorePoint 精排（root），sort=false 用 _heat 轻排（minimax 内部）
  List<int> generateCandidates(
    int self, {
    int radius = 2,
    int topK = 16,
    bool sort = true,
  }) {
    final enemy = self == 1 ? 2 : 1;
    final set = <int>{};
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == 0) continue;
      final row = i ~/ size, col = i % size;
      for (int dr = -radius; dr <= radius; dr++) {
        for (int dc = -radius; dc <= radius; dc++) {
          if (dr == 0 && dc == 0) continue;
          final r = row + dr, c = col + dc;
          if (!inBounds(r, c)) continue;
          final ni = r * size + c;
          if (cells[ni] == 0) set.add(ni);
        }
      }
    }
    final list = set.toList();
    if (sort) {
      list.sort((a, b) {
        final sa =
            Evaluator.scorePoint(this, a, self) +
            Evaluator.scorePoint(this, a, enemy);
        final sb =
            Evaluator.scorePoint(this, b, self) +
            Evaluator.scorePoint(this, b, enemy);
        return sb - sa;
      });
    } else {
      list.sort((a, b) => _heat(b) - _heat(a));
    }
    if (list.length > topK) return list.sublist(0, topK);
    return list;
  }

  @override
  int evaluate(int self) => Evaluator.evaluate(this, self);

  // ── SearchableBoard<int> 实现 ──
  @override
  bool isEmptyAt(int idx) => cells[idx] == 0;

  @override
  int opponent(int p) => p == 1 ? 2 : 1;

  /// 统一候选入口（委托 generateCandidates；gobang 候选与颜色无关，忽略 player）
  @override
  List<int> candidates(int player, int self, DifficultyConfig cfg, bool sort) =>
      generateCandidates(self, radius: cfg.radius, topK: cfg.topK, sort: sort);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 搜索引擎 — 委托通用 Minimax（IDS/Alpha-Beta/deadline 在 00.common），仅保留
// 五子棋特有的必胜必堵短路
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class SearchEngine {
  static int? search(
    SearchBoard board,
    int self,
    AiDifficulty diff,
    int timeBudgetMs,
  ) {
    final cfg = _config(diff);
    return Minimax.search(
      board,
      self,
      cfg,
      timeBudgetMs,
      shortcuts: (rootCands) => _shortcuts(board, self, rootCands),
    );
  }

  /// 必胜必堵短路：AI 一步成五 → 必胜；对方一步成五 → 必堵
  static int? _shortcuts(SearchBoard board, int self, List<int> rootCands) {
    final enemy = self == 1 ? 2 : 1;
    for (final c in rootCands) {
      if (board.canWin(c, self)) return c;
    }
    for (int i = 0; i < board.cells.length; i++) {
      if (board.cells[i] != 0) continue;
      if (board.canWin(i, enemy)) return i;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AI 控制器 — 对外接口，compute() 在后台 isolate 执行搜索
// ═══════════════════════════════════════════════════════════════════════════════

class AiController {
  final TurnGamerType faction;
  final AiDifficulty difficulty;
  final int size;
  final ValueNotifier<bool> thinking = ValueNotifier(false);

  AiController({
    required this.size,
    required this.faction,
    this.difficulty = AiDifficulty.normal,
  });

  /// 异步获取最佳着法。每次接收当前局面快照（无内部状态，避免与 UI 不同步）
  Future<int?> getAction(List<int> rawSnapshot) async {
    thinking.value = true;
    try {
      return await compute(
        _searchEntry,
        _SearchArgs(
          board: _toSelfView(rawSnapshot, faction),
          size: size,
          self: 1,
          difficulty: difficulty.index,
          timeBudgetMs: _config(difficulty).timeBudgetMs,
        ),
      );
    } catch (e) {
      _AiLog.d('搜索异常 $e');
      return null;
    } finally {
      // 控制器可能已被替换/释放（重开、切难度、关 AI），设值容错
      try {
        thinking.value = false;
      } catch (_) {}
    }
  }

  /// 原始快照(0空/1黑/2白) → self 视角(0空/1己/2敌)
  static List<int> _toSelfView(List<int> raw, TurnGamerType faction) {
    final selfRaw = faction == TurnGamerType.front ? 1 : 2;
    return [for (final v in raw) v == 0 ? 0 : (v == selfRaw ? 1 : 2)];
  }

  void dispose() => thinking.dispose();
}

/// compute 入口参数（须可跨 isolate 序列化）
class _SearchArgs {
  final List<int> board;
  final int size;
  final int self;
  final int difficulty;
  final int timeBudgetMs;
  const _SearchArgs({
    required this.board,
    required this.size,
    required this.self,
    required this.difficulty,
    required this.timeBudgetMs,
  });
}

/// isolate 入口：重建 SearchBoard 并搜索（web 上 compute 退化为同步回调，行为一致）
@pragma('vm:entry-point')
int? _searchEntry(_SearchArgs args) {
  final board = SearchBoard(List<int>.of(args.board), args.size);
  return SearchEngine.search(
    board,
    args.self,
    AiDifficulty.values[args.difficulty],
    args.timeBudgetMs,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 日志（默认关闭，调试时置 enabled = true）
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class _AiLog {
  static bool enabled = false;
  static void d(String msg) {
    if (enabled) debugPrint('[GomokuAI] $msg');
  }
}
