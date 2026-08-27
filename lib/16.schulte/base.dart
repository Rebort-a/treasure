import 'dart:math';

import 'package:flutter/material.dart';

/// 棋盘格子坐标（命名 record）
typedef Cell = ({int col, int row});

/// 一个不规则区域：一组连通格子 + 数字 + 绘制属性
class SchulteRegion {
  final int id;
  final int number; // 1~N
  final List<Cell> cells;
  final Offset centroid; // 质心（格子坐标，绘制时换算像素）
  final double fontSize;

  SchulteRegion({
    required this.id,
    required this.number,
    required this.cells,
    required this.centroid,
    required this.fontSize,
  });

  int get area => cells.length;
}

/// 舒尔特棋盘：网格 + 区域列表 + 格子→区域映射（用于命中检测）
class SchulteBoard {
  final int cols;
  final int rows;
  final List<SchulteRegion> regions;
  late final List<List<int>> _grid; // _grid[col][row] = regionId

  SchulteBoard({
    required this.cols,
    required this.rows,
    required this.regions,
  }) {
    _grid = List.generate(cols, (_) => List<int>.filled(rows, -1));
    for (final r in regions) {
      for (final c in r.cells) {
        _grid[c.col][c.row] = r.id;
      }
    }
  }

  /// 格子坐标 → 区域 id（点击命中：即使绘制边界扰动，仍按底层格子命中）
  int regionIdAt(int col, int row) {
    if (col < 0 || col >= cols || row < 0 || row >= rows) return -1;
    return _grid[col][row];
  }
}

/// 不规则区域生成器
/// 算法：预设目标大小 → 距离拒绝采样的分散种子 → 多源 BFS 优先小区域扩张
///      → 残余多轮扩散归邻接 → 被堵补救（含连通验证）→ 验证 min → 失败重试
class RegionGenerator {
  static const int _maxAttempts = 40;
  static const _dirs = <({int dx, int dy})>[
    (dx: 1, dy: 0),
    (dx: -1, dy: 0),
    (dx: 0, dy: 1),
    (dx: 0, dy: -1),
  ];

  static SchulteBoard generate(int cols, int rows, int n, {Random? rng}) {
    final random = rng ?? Random();
    final total = cols * rows;
    final minSize = max(2, (total / n * 0.5).floor());
    var maxSize = min(total - 1, (total / n * 2).ceil());

    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      final cells = _tryGenerate(cols, rows, n, minSize, maxSize, total, random);
      if (cells != null) return _buildBoard(cols, rows, cells, random);
    }
    maxSize = total;
    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      final cells = _tryGenerate(cols, rows, n, minSize, maxSize, total, random);
      if (cells != null) return _buildBoard(cols, rows, cells, random);
    }
    return _buildUniformBoard(cols, rows, n, random);
  }

  /// 生成目标大小列表，sum=total，每个 ∈ [minSize, maxSize]
  static List<int>? _generateSizes(
      int n, int minSize, int maxSize, int total, Random random) {
    if (n * minSize > total || n * maxSize < total) return null;
    final sizes = List<int>.filled(n, minSize);
    final capacities = List<int>.filled(n, maxSize - minSize);
    var remaining = total - n * minSize;
    while (remaining > 0) {
      final candidates = [
        for (int i = 0; i < n; i++)
          if (capacities[i] > 0) i
      ];
      if (candidates.isEmpty) return null;
      final idx = candidates[random.nextInt(candidates.length)];
      sizes[idx]++;
      capacities[idx]--;
      remaining--;
    }
    sizes.shuffle(random);
    return sizes;
  }

  /// 选 n 个分散种子：距离拒绝采样（低 n 拒绝相邻）+ 20 轮取最分散者
  static List<Cell>? _pickSeeds(int cols, int rows, int n, Random random) {
    final total = cols * rows;
    // 低密度时拒绝相邻种子（距离>=2），高密度自动放宽到 1
    final minDist = max(1, min(2, (total ~/ n) ~/ 3));
    List<Cell>? best;
    int bestMinDist = -1;
    for (int attempt = 0; attempt < 20; attempt++) {
      final picks = <Cell>[];
      final used = <int>{};
      int rejectStreak = 0;
      while (picks.length < n && rejectStreak < 400) {
        final idx = random.nextInt(total);
        if (used.contains(idx)) {
          rejectStreak++;
          continue;
        }
        final cand = (col: idx % cols, row: idx ~/ cols);
        bool ok = true;
        for (final p in picks) {
          if ((p.col - cand.col).abs() + (p.row - cand.row).abs() < minDist) {
            ok = false;
            break;
          }
        }
        if (!ok) {
          rejectStreak++;
          continue;
        }
        rejectStreak = 0;
        used.add(idx);
        picks.add(cand);
      }
      if (picks.length < n) continue;
      int md = 1 << 30;
      for (int i = 0; i < picks.length; i++) {
        for (int j = i + 1; j < picks.length; j++) {
          final d = (picks[i].col - picks[j].col).abs() +
              (picks[i].row - picks[j].row).abs();
          if (d < md) md = d;
        }
      }
      if (md > bestMinDist) {
        bestMinDist = md;
        best = picks;
      }
    }
    return best;
  }

  /// 一次尝试：BFS 扩张 + 残余多轮扩散 + 被堵补救 + 验证 min
  static List<List<Cell>>? _tryGenerate(
    int cols,
    int rows,
    int n,
    int minSize,
    int maxSize,
    int total,
    Random random,
  ) {
    final sizes = _generateSizes(n, minSize, maxSize, total, random);
    if (sizes == null) return null;
    final seeds = _pickSeeds(cols, rows, n, random);
    if (seeds == null) return null;

    final grid = List.generate(cols, (_) => List<int>.filled(rows, -1));
    final size = List<int>.filled(n, 0);
    final queues = List<List<Cell>>.generate(n, (_) => <Cell>[]);

    for (int i = 0; i < n; i++) {
      final s = seeds[i];
      grid[s.col][s.row] = i;
      size[i] = 1;
      queues[i].add(s);
    }

    int remaining = total - n;
    while (remaining > 0) {
      int? best;
      double bestRatio = 1e9;
      for (int i = 0; i < n; i++) {
        if (size[i] < sizes[i] && queues[i].isNotEmpty) {
          final r = size[i] / sizes[i];
          if (r < bestRatio) {
            bestRatio = r;
            best = i;
          }
        }
      }
      if (best == null) break;
      final cur = queues[best].removeAt(0);
      for (final d in _dirs) {
        if (size[best] >= sizes[best]) break;
        final nc = cur.col + d.dx;
        final nr = cur.row + d.dy;
        if (nc >= 0 && nc < cols && nr >= 0 && nr < rows && grid[nc][nr] == -1) {
          grid[nc][nr] = best;
          size[best]++;
          remaining--;
          queues[best].add((col: nc, row: nr));
        }
      }
    }

    // 残余处理：多轮扩散，把有已分配邻接的 -1 格归给该邻接区域，直到无变化
    // （网格整体连通，BFS 后真孤岛结构上不存在；单轮扫描会误判簇内部为孤岛）
    bool changed = true;
    while (changed) {
      changed = false;
      for (int c = 0; c < cols; c++) {
        for (int r = 0; r < rows; r++) {
          if (grid[c][r] != -1) continue;
          for (final d in _dirs) {
            final nc = c + d.dx;
            final nr = r + d.dy;
            if (nc >= 0 &&
                nc < cols &&
                nr >= 0 &&
                nr < rows &&
                grid[nc][nr] >= 0) {
              grid[c][r] = grid[nc][nr];
              size[grid[c][r]]++;
              changed = true;
              break;
            }
          }
        }
      }
    }
    // 剩余仍 -1 的为真孤岛（防御，实际不存在）
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r] == -1) return null;
      }
    }

    // 被堵补救：size<minSize 的区域从邻接 size>minSize 区域转移格子（验证转出方仍连通）
    bool rescued = true;
    while (rescued) {
      rescued = false;
      for (int i = 0; i < n; i++) {
        if (size[i] >= minSize) continue;
        bool found = false;
        for (int c = 0; c < cols && !found; c++) {
          for (int r = 0; r < rows && !found; r++) {
            if (grid[c][r] != i) continue;
            for (final d in _dirs) {
              final nc = c + d.dx;
              final nr = r + d.dy;
              if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
              final j = grid[nc][nr];
              if (j == i || j < 0 || size[j] <= minSize) continue;
              // 候选：把 (nc,nr) 从 j 转给 i；先验证 j 转出后仍连通
              grid[nc][nr] = i;
              Cell? start;
              for (int c2 = 0; c2 < cols && start == null; c2++) {
                for (int r2 = 0; r2 < rows; r2++) {
                  if (grid[c2][r2] == j) {
                    start = (col: c2, row: r2);
                    break;
                  }
                }
              }
              final cnt = start == null
                  ? 0
                  : _floodCount(grid, cols, rows, j, start.col, start.row);
              if (cnt == size[j] - 1) {
                size[i]++;
                size[j]--;
                rescued = true;
                found = true;
                break;
              } else {
                grid[nc][nr] = j; // 不连通，恢复
              }
            }
          }
        }
      }
    }

    // 验证：所有区域 >= minSize
    for (int i = 0; i < n; i++) {
      if (size[i] < minSize) return null;
    }

    // 收集每区域 cells
    final cells = List<List<Cell>>.generate(n, (_) => <Cell>[]);
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        cells[grid[c][r]].add((col: c, row: r));
      }
    }
    return cells;
  }

  /// flood fill 统计 regionId 连通格子数（从 start 起）
  static int _floodCount(
      List<List<int>> grid, int cols, int rows, int regionId, int sc, int sr) {
    if (grid[sc][sr] != regionId) return 0;
    final visited = List.generate(cols, (_) => List<bool>.filled(rows, false));
    final queue = <Cell>[(col: sc, row: sr)];
    visited[sc][sr] = true;
    int count = 0;
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      count++;
      for (final d in _dirs) {
        final nc = cur.col + d.dx;
        final nr = cur.row + d.dy;
        if (nc >= 0 &&
            nc < cols &&
            nr >= 0 &&
            nr < rows &&
            !visited[nc][nr] &&
            grid[nc][nr] == regionId) {
          visited[nc][nr] = true;
          queue.add((col: nc, row: nr));
        }
      }
    }
    return count;
  }

  /// 由 cells 构造棋盘：数字 1~N 打乱、质心、字号随区域大小
  static SchulteBoard _buildBoard(
      int cols, int rows, List<List<Cell>> cells, Random random) {
    final n = cells.length;
    final numbers = List<int>.generate(n, (i) => i + 1)..shuffle(random);
    int minArea = 1 << 30, maxArea = 0;
    for (final c in cells) {
      if (c.isEmpty) continue;
      if (c.length < minArea) minArea = c.length;
      if (c.length > maxArea) maxArea = c.length;
    }
    if (minArea == 1 << 30) minArea = 1;
    if (maxArea == 0) maxArea = 1;
    final regions = <SchulteRegion>[];
    for (int i = 0; i < n; i++) {
      final list = cells[i];
      if (list.isEmpty) {
        regions.add(SchulteRegion(
          id: i,
          number: numbers[i],
          cells: const [],
          centroid: Offset.zero,
          fontSize: 16,
        ));
        continue;
      }
      double sumX = 0, sumY = 0;
      for (final c in list) {
        sumX += c.col;
        sumY += c.row;
      }
      final centroid = Offset(sumX / list.length, sumY / list.length);
      final t = maxArea == minArea
          ? 0.0
          : (list.length - minArea) / (maxArea - minArea);
      final fs = (16.0 + 16.0 * t).clamp(16.0, 32.0);
      regions.add(SchulteRegion(
        id: i,
        number: numbers[i],
        cells: list,
        centroid: centroid,
        fontSize: fs.toDouble(),
      ));
    }
    return SchulteBoard(cols: cols, rows: rows, regions: regions);
  }

  /// 兜底：均分区域（算法失败时保证不崩溃，每区域至少 1 格）
  static SchulteBoard _buildUniformBoard(
      int cols, int rows, int n, Random random) {
    final total = cols * rows;
    final nn = n > total ? total : n; // 防御 n>total
    final perRegion = total ~/ nn;
    final grid = List.generate(cols, (_) => List<int>.filled(rows, 0));
    int regionId = 0, count = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        grid[c][r] = regionId;
        count++;
        if (count >= max(1, perRegion) && regionId < nn - 1) {
          regionId++;
          count = 0;
        }
      }
    }
    final cells = List<List<Cell>>.generate(nn, (_) => <Cell>[]);
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        cells[grid[c][r]].add((col: c, row: r));
      }
    }
    return _buildBoard(cols, rows, cells, random);
  }
}

/// 点击反馈：记录被点击的区域 id 与对错，供 painter 绘制瞬时蒙层
class SchulteTapFeedback {
  final int regionId;
  final bool isCorrect;

  const SchulteTapFeedback({required this.regionId, required this.isCorrect});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchulteTapFeedback &&
          regionId == other.regionId &&
          isCorrect == other.isCorrect;

  @override
  int get hashCode => Object.hash(regionId, isCorrect);
}
