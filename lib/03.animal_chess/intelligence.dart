import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import 'base.dart';

// ============================================================
// 常量 — 所有魔法数字集中管理
// ============================================================

abstract final class _Constants {
  // 位编码
  static const terrainMask = 0x07;
  static const occupyShift = 3;
  static const occupyMask = 0x03;
  static const animalShift = 5;
  static const animalMask = 0x07;

  // 占据状态编码
  static const empty = 0;
  static const hidden = 1;
  static const self = 2;
  static const enemy = 3;

  // 搜索参数
  static const searchDepth = 6;

  // 评估权重
  static const threatPenaltyHalf = 0.5;
  static const threatPenaltyFull = 1.0;
  static const positionThreatWeight = 0.3;
  static const mobilityWeight = 0.1;
  static const winScore = 100000.0;

  // Zobrist
  static const maxCells = 169;
  static const cellCodeCount = 18;
  static const animalTypeCount = 8;
  static const historyLimit = 6;
  static const repeatThreshold = 2;

  // 动态总分
  static const totalScore = 16;

  /// 各动物基础分值
  static const baseScores = <AnimalType, int>{
    AnimalType.elephant: 3,
    AnimalType.tiger: 1,
    AnimalType.lion: 2,
    AnimalType.leopard: 2,
    AnimalType.wolf: 1,
    AnimalType.dog: 2,
    AnimalType.cat: 1,
    AnimalType.mouse: 2,
  };
}

// ============================================================
// _CellUtils — 单元格编解码 / 吃子判断 / 地形通行
// ============================================================

abstract final class _CellUtils {
  // --- 编解码 ---

  static bool isEmpty(int c) =>
      c == 0 ||
      ((c >> _Constants.occupyShift) & _Constants.occupyMask) ==
          _Constants.empty;
  static bool isHidden(int c) =>
      ((c >> _Constants.occupyShift) & _Constants.occupyMask) ==
      _Constants.hidden;
  static bool isSelf(int c) =>
      ((c >> _Constants.occupyShift) & _Constants.occupyMask) ==
      _Constants.self;
  static bool isEnemy(int c) =>
      ((c >> _Constants.occupyShift) & _Constants.occupyMask) ==
      _Constants.enemy;

  static AnimalType animal(int c) =>
      AnimalType.values[(c >> _Constants.animalShift) & _Constants.animalMask];
  static CellType terrain(int c) => CellType.values[c & _Constants.terrainMask];

  static int encode(CellType terrain, int occupy, AnimalType? animal) =>
      terrain.index |
      (occupy << _Constants.occupyShift) |
      ((animal?.index ?? 0) << _Constants.animalShift);

  /// 编码仅保留地形的空格
  static int encodeEmpty(CellType terrain) => terrain.index;

  // --- 吃子判断 ---

  /// 判断 attacker 能否吃 defender
  static bool canEat(AnimalType attacker, AnimalType defender) {
    if (attacker == defender) return true;
    if (attacker == AnimalType.mouse && defender == AnimalType.elephant) {
      return true;
    }
    if (attacker == AnimalType.elephant && defender == AnimalType.mouse) {
      return false;
    }
    return attacker.index < defender.index;
  }

  // --- 地形通行 ---

  /// 可入河流的动物
  static const riverAnimals = {
    AnimalType.elephant,
    AnimalType.dog,
    AnimalType.mouse,
  };

  /// 可攀树的动物
  static const treeAnimals = {
    AnimalType.leopard,
    AnimalType.cat,
    AnimalType.mouse,
  };

  /// 判断动物能否从 from 地形进入 target 地形
  static bool canEnterTerrain(AnimalType type, CellType from, CellType target) {
    return switch (target) {
      CellType.river => riverAnimals.contains(type),
      CellType.bridge =>
        from == CellType.river
            ? type == AnimalType.mouse
            : type != AnimalType.elephant,
      CellType.tree => treeAnimals.contains(type),
      _ => true,
    };
  }
}

// ============================================================
// BoardInfo — 故意忽略暗棋位置信息，对应玩家眼中的棋盘（Zobrist 哈希用）
// ============================================================

class BoardInfo {
  final int size;
  final List<int> situation;
  final List<AnimalType> selfHidden;
  final List<AnimalType> enemyHidden;
  int? hash;

  BoardInfo(this.size, this.situation, this.selfHidden, this.enemyHidden)
    : hash = null;
}

// ============================================================
// BoardSnapshot — 棋盘快照
// ============================================================

class BoardSnapshot {
  late BoardInfo _boardInfo;
  final TurnGamerType faction;

  Map<AnimalType, int> selfVisible = {};
  Map<AnimalType, int> enemyVisible = {};
  final List<int> hiddenPositions = [];

  List<int> get situation => _boardInfo.situation;
  int get size => _boardInfo.size;
  List<AnimalType> get selfHidden => _boardInfo.selfHidden;
  List<AnimalType> get enemyHidden => _boardInfo.enemyHidden;

  BoardSnapshot._(List<int> situation, this.faction, int size)
    : _boardInfo = BoardInfo(size, situation, [], []);

  BoardInfo get boardInfo => _boardInfo;

  factory BoardSnapshot.fromBoard(
    List<CellView> board,
    int size,
    TurnGamerType faction,
  ) {
    final snapshot = BoardSnapshot._(
      List<int>.filled(size * size, 0),
      faction,
      size,
    );
    snapshot._buildFrom(board);
    return snapshot;
  }

  void _buildFrom(List<CellView> board) {
    final selfTypeSet = <AnimalType>{};
    final enemyTypeSet = <AnimalType>{};

    for (int i = 0; i < board.length; i++) {
      final cell = board[i];
      int occupyBits;
      int animalBits = 0;

      if (!cell.hasAnimal) {
        occupyBits = _Constants.empty;
      } else if (cell.animal!.isHidden) {
        occupyBits = _Constants.hidden;
        hiddenPositions.add(i);
        final isSelf = cell.animal!.owner == faction;
        (isSelf ? selfTypeSet : enemyTypeSet).add(cell.animal!.type);
      } else {
        final isSelf = cell.animal!.owner == faction;
        occupyBits = isSelf ? _Constants.self : _Constants.enemy;
        animalBits = cell.animal!.type.index;
        (isSelf ? selfVisible : enemyVisible)[cell.animal!.type] = i;
      }

      situation[i] =
          cell.type.index |
          (occupyBits << _Constants.occupyShift) |
          (animalBits << _Constants.animalShift);
    }

    _boardInfo = BoardInfo(
      size,
      situation,
      selfTypeSet.toList(),
      enemyTypeSet.toList(),
    );
  }

  /// 翻牌更新
  void applyFlip(
    int index,
    CellType terrain,
    AnimalType type,
    TurnGamerType owner,
  ) {
    _boardInfo.hash = null;
    final isSelf = owner == faction;
    situation[index] = _CellUtils.encode(
      terrain,
      isSelf ? _Constants.self : _Constants.enemy,
      type,
    );
    hiddenPositions.remove(index);

    if (isSelf) {
      selfHidden.remove(type);
      selfVisible[type] = index;
    } else {
      enemyHidden.remove(type);
      enemyVisible[type] = index;
    }
  }

  /// 移动更新（地形从 situation 读取，toType 非空表示吃子）
  void applyMove(
    int from,
    int to,
    AnimalType fromType,
    TurnGamerType fromOwner, {
    AnimalType? toType,
  }) {
    _boardInfo.hash = null;
    final isSelf = fromOwner == faction;
    final toTerrain = _CellUtils.terrain(situation[to]);

    situation[from] = _CellUtils.encodeEmpty(
      _CellUtils.terrain(situation[from]),
    );

    if (toType != null) {
      final attackerWins = _CellUtils.canEat(fromType, toType);
      final defenderWins = _CellUtils.canEat(toType, fromType);

      if (attackerWins && defenderWins) {
        situation[to] = _CellUtils.encodeEmpty(toTerrain);
        _removeVisible(fromType, isSelf);
        _removeVisible(toType, !isSelf);
      } else if (attackerWins) {
        situation[to] = _CellUtils.encode(
          toTerrain,
          isSelf ? _Constants.self : _Constants.enemy,
          fromType,
        );
        _removeVisible(toType, !isSelf);
        _updateVisible(fromType, isSelf, to);
      } else {
        _removeVisible(fromType, isSelf);
      }
    } else {
      situation[to] = _CellUtils.encode(
        toTerrain,
        isSelf ? _Constants.self : _Constants.enemy,
        fromType,
      );
      _updateVisible(fromType, isSelf, to);
    }
  }

  void _removeVisible(AnimalType type, bool isSelf) {
    (isSelf ? selfVisible : enemyVisible).remove(type);
  }

  void _updateVisible(AnimalType type, bool isSelf, int newIndex) {
    (isSelf ? selfVisible : enemyVisible)[type] = newIndex;
  }

  @override
  String toString() {
    const terrainChar = ['L', 'R', 'O', 'B', 'T'];
    const animalChar = ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'];
    final sb = StringBuffer('BoardSnapshot(faction=$faction)\n');
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cell = situation[r * size + c];
        final tChar = terrainChar[cell & _Constants.terrainMask];
        final occupy = (cell >> _Constants.occupyShift) & _Constants.occupyMask;
        final oChar = ['-', '?', 'S', 'E'][occupy];
        final aChar = occupy >= 2
            ? animalChar[(cell >> _Constants.animalShift) &
                  _Constants.animalMask]
            : ' ';
        sb.write('$tChar$oChar$aChar ');
      }
      sb.writeln();
    }
    // 仅 debug 输出时临时排序，不影响热路径
    Iterable<MapEntry<AnimalType, int>> sorted(Map<AnimalType, int> m) =>
        (m.entries.toList()
          ..sort((a, b) => a.key.index.compareTo(b.key.index)));
    sb.writeln('selfVisible: ${Map.fromEntries(sorted(selfVisible))}');
    sb.writeln('enemyVisible: ${Map.fromEntries(sorted(enemyVisible))}');
    sb.writeln('selfHidden: $selfHidden');
    sb.writeln('enemyHidden: $enemyHidden');
    return sb.toString();
  }
}

// ============================================================
// _Zobrist — Zobrist 哈希表（含四重对称变换）
// ============================================================

class _Zobrist {
  static final instance = _Zobrist._();

  late final List<List<int>> _cellKeys;
  late final List<int> _selfHiddenKeys;
  late final List<int> _enemyHiddenKeys;
  final Map<int, GameAction> _table = {};
  final List<(int, GameAction)> _aiHistory = [];
  final Random _rng = Random(2024);

  _Zobrist._() {
    _cellKeys = List.generate(
      _Constants.maxCells,
      (_) => List.generate(_Constants.cellCodeCount, (_) => _rand64()),
    );
    _selfHiddenKeys = List.generate(
      _Constants.animalTypeCount,
      (_) => _rand64(),
    );
    _enemyHiddenKeys = List.generate(
      _Constants.animalTypeCount,
      (_) => _rand64(),
    );
  }

  int _rand64() =>
      (_rng.nextInt(1 << 22) << 42) ^
      (_rng.nextInt(1 << 21) << 21) ^
      _rng.nextInt(1 << 21);

  /// 将 cell 值映射到哈希 code（0=空, 1~8=己方, 9~16=敌方, 17=暗棋）
  int _cellToCode(int cell) {
    if (cell == 0) return 0;
    final occupy = (cell >> _Constants.occupyShift) & _Constants.occupyMask;
    if (occupy == _Constants.empty) return 0;
    if (occupy == _Constants.hidden) return 17;
    final animal = (cell >> _Constants.animalShift) & _Constants.animalMask;
    return occupy == _Constants.self ? animal + 1 : animal + 9;
  }

  /// 计算棋盘哈希值（位置相关，确保对称变体产生不同哈希），结果缓存在 BoardInfo._hash
  int computeHash(BoardInfo info) {
    final cached = info.hash;
    if (cached != null) return cached;
    int h = 0;
    for (int i = 0; i < info.situation.length; i++) {
      h ^= _cellKeys[i][_cellToCode(info.situation[i])] ^ i;
    }
    for (final t in info.selfHidden) {
      h ^= _selfHiddenKeys[t.index];
    }
    for (final t in info.enemyHidden) {
      h ^= _enemyHiddenKeys[t.index];
    }
    info.hash = h;
    return h;
  }

  /// 查表
  GameAction? lookup(BoardInfo info) {
    final hash = computeHash(info);
    final action = _table[hash];
    // 日志移到调用处，更清晰
    return action;
  }

  /// 存表（四重对称，共 4 条记录）
  void store(BoardInfo info, GameAction action, bool isAi) {
    // 如果是ai，并且已有策略，不更新
    final int hash = computeHash(info);
    _AiLog.d(
      'Zobrist store: hash=$hash action=${_AiLog.action(action, info.size)} isAi=$isAi',
    );

    if (isAi) {
      _recordAiMove(hash, action);
      if (_table.containsKey(hash)) {
        _AiLog.d('Zobrist store: hash=$hash already exists, skip');
        return;
      }
    }

    // 玩家策略总是更新
    _table[hash] = action;

    // 将三个局面变体和转换后的最优解也保存
    for (final t in _kTransforms) {
      final ts = _transformSituation(info.situation, info.size, t);
      final tHash = computeHash(
        BoardInfo(info.size, ts, info.selfHidden, info.enemyHidden),
      );
      final transformed = action.transform(t, info.size);
      _AiLog.d(
        'Zobrist store sym: hash=$tHash action=${_AiLog.action(transformed, info.size)} (transform)',
      );
      _table[tHash] = transformed;
    }
  }

  /// 记录 AI 行动（行动前的 hash + 选择的 action），滑动窗口
  void _recordAiMove(int hash, GameAction action) {
    _AiLog.d('Zobrist ai move record: hash=$hash');
    _aiHistory.add((hash, action));
    if (_aiHistory.length > _Constants.historyLimit) {
      _AiLog.d('Zobrist ai move remove: hash=${_aiHistory[0]}');
      _aiHistory.removeAt(0);
    }
  }

  bool detectRepetition(int hash, GameAction action) {
    return _repeatCount(hash, action) >= _Constants.repeatThreshold;
  }

  /// 查询 (hash, action) 在历史窗口中出现的次数
  int _repeatCount(int hash, GameAction action) {
    int count = 0;
    for (final (h, a) in _aiHistory) {
      if (h == hash && a == action) count++;
    }
    return count;
  }

  // --- 四重对称变换 ---

  static int _hm(int i, int n) => (i ~/ n) * n + (n - 1 - i % n);
  static int _vm(int i, int n) => (n - 1 - i ~/ n) * n + (i % n);
  static int _r180(int i, int n) => (n - 1 - i ~/ n) * n + (n - 1 - i % n);

  static const _kTransforms = [_hm, _vm, _r180];

  static List<int> _transformSituation(
    List<int> situation,
    int n,
    int Function(int, int) t,
  ) {
    final r = List<int>.filled(situation.length, 0);
    for (int i = 0; i < situation.length; i++) {
      r[t(i, n)] = situation[i];
    }
    return r;
  }
}

// ============================================================
// _SearchBoard — 搜索用可变棋盘（do/undo 模式）
// ============================================================

/// 翻牌回退数据
final class _FlipUndo {
  final int cell;
  final bool isSelf;
  final int hiddenIndex;
  const _FlipUndo(this.cell, this.isSelf, this.hiddenIndex);
}

/// 移动回退数据（保存移动前 from/to 的位置和 cell 值）
final class _MoveUndo {
  final int fromPos;
  final int toPos;
  final int fromCell;
  final int toCell;
  const _MoveUndo(this.fromPos, this.toPos, this.fromCell, this.toCell);
}

class _SearchBoard {
  final int size;
  final List<int> situation;
  final List<AnimalType> selfHidden;
  final List<AnimalType> enemyHidden;
  final Map<AnimalType, int> selfPositions;
  final Map<AnimalType, int> enemyPositions;
  final List<int> hiddenPositions;

  _SearchBoard._(
    this.size,
    this.situation,
    this.selfHidden,
    this.enemyHidden,
    this.selfPositions,
    this.enemyPositions,
    this.hiddenPositions,
  );

  factory _SearchBoard.fromSnapshot(BoardSnapshot snapshot) {
    return _SearchBoard._(
      snapshot.size,
      List<int>.of(snapshot.situation),
      List<AnimalType>.of(snapshot.selfHidden),
      List<AnimalType>.of(snapshot.enemyHidden),
      Map<AnimalType, int>.of(snapshot.selfVisible),
      Map<AnimalType, int>.of(snapshot.enemyVisible),
      List<int>.of(snapshot.hiddenPositions),
    );
  }

  // --- 辅助：执行 → 回调 → 撤销 ---

  T withMove<T>(MoveAction action, T Function() fn) {
    final undo = doMove(action.from, action.to);
    final result = fn();
    undoMove(undo);
    return result;
  }

  T withFlip<T>(FlipAction action, T Function() fn) {
    final undo = doFlip(action.index);
    final result = fn();
    undoFlip(action.index, undo);
    return result;
  }

  // --- 走法执行 ---

  /// 执行移动，返回回退数据
  _MoveUndo doMove(int from, int to) {
    final undo = _MoveUndo(from, to, situation[from], situation[to]);
    final moving = situation[from];
    final mType = _CellUtils.animal(moving);
    final isSelf = _CellUtils.isSelf(moving);

    // 暗棋不可作为移动目标，直接返回 undo
    if (_CellUtils.isHidden(situation[to])) return undo;

    situation[from] = _CellUtils.encodeEmpty(_CellUtils.terrain(moving));

    if (_CellUtils.isEmpty(situation[to])) {
      _place(to, mType, isSelf);
    } else {
      _resolveCombat(to, mType, isSelf);
    }
    return undo;
  }

  /// 放置棋子到指定位置
  void _place(int pos, AnimalType type, bool isSelf) {
    situation[pos] = _CellUtils.encode(
      _CellUtils.terrain(situation[pos]),
      isSelf ? _Constants.self : _Constants.enemy,
      type,
    );
    (isSelf ? selfPositions : enemyPositions)[type] = pos;
  }

  /// 处理战斗结果
  void _resolveCombat(int pos, AnimalType attacker, bool isSelf) {
    final defender = _CellUtils.animal(situation[pos]);
    final aWins = _CellUtils.canEat(attacker, defender);
    final dWins = _CellUtils.canEat(defender, attacker);

    if (aWins && dWins) {
      // 同归于尽
      situation[pos] = _CellUtils.encodeEmpty(
        _CellUtils.terrain(situation[pos]),
      );
      (isSelf ? selfPositions : enemyPositions).remove(attacker);
      (isSelf ? enemyPositions : selfPositions).remove(defender);
    } else if (aWins) {
      // 攻方胜
      _place(pos, attacker, isSelf);
      (isSelf ? enemyPositions : selfPositions).remove(defender);
    } else if (dWins) {
      // 守方胜
      (isSelf ? selfPositions : enemyPositions).remove(attacker);
    }
    // 双方都不能吃对方 → 不操作（generateMoves 已过滤，此处为防御性保留）
  }

  /// 执行翻牌，返回回退数据
  _FlipUndo doFlip(int index) {
    final cell = situation[index];
    final animal = _CellUtils.animal(cell);
    final isSelf =
        _CellUtils.isSelf(cell) ||
        (!_CellUtils.isEnemy(cell) && selfHidden.contains(animal));
    final hidden = isSelf ? selfHidden : enemyHidden;
    final hiddenIndex = hidden.indexOf(animal);

    hidden.removeAt(hiddenIndex);
    situation[index] = _CellUtils.encode(
      _CellUtils.terrain(cell),
      isSelf ? _Constants.self : _Constants.enemy,
      animal,
    );
    (isSelf ? selfPositions : enemyPositions)[animal] = index;
    return _FlipUndo(cell, isSelf, hiddenIndex);
  }

  void undoMove(_MoveUndo undo) {
    situation[undo.fromPos] = undo.fromCell;
    situation[undo.toPos] = undo.toCell;

    // 增量恢复 from 位置
    if (!_CellUtils.isEmpty(undo.fromCell) &&
        !_CellUtils.isHidden(undo.fromCell)) {
      final type = _CellUtils.animal(undo.fromCell);
      final isSelf = _CellUtils.isSelf(undo.fromCell);
      (isSelf ? selfPositions : enemyPositions)[type] = undo.fromPos;
    }

    // 增量恢复 to 位置
    if (_CellUtils.isEmpty(undo.toCell) || _CellUtils.isHidden(undo.toCell)) {
      // to 原来是空/暗棋 → 移动后可能有棋子占据了，需移除
      final cur = situation[undo.toPos]; // 已被 restore，但用 toCell 判断更清晰
      if (!_CellUtils.isEmpty(cur) && !_CellUtils.isHidden(cur)) {
        final curType = _CellUtils.animal(cur);
        final curSelf = _CellUtils.isSelf(cur);
        final map = curSelf ? selfPositions : enemyPositions;
        if (map[curType] == undo.toPos) map.remove(curType);
      }
    } else {
      // to 原来有棋子 → 恢复它
      final type = _CellUtils.animal(undo.toCell);
      final isSelf = _CellUtils.isSelf(undo.toCell);
      (isSelf ? selfPositions : enemyPositions)[type] = undo.toPos;
    }
  }

  void undoFlip(int index, _FlipUndo undo) {
    final animal = _CellUtils.animal(situation[index]);
    (undo.isSelf ? selfPositions : enemyPositions).remove(animal);
    (undo.isSelf ? selfHidden : enemyHidden).insert(undo.hiddenIndex, animal);
    situation[index] = undo.cell;
  }

  // --- 走法生成 ---

  /// 生成所有合法走法，吃子走法排在前面并按被吃棋子价值降序
  /// [includeFlips] 为 true 时包含翻牌走法（评估用），false 时仅移动（搜索用）
  List<GameAction> generateMoves(bool isSelf, {bool includeFlips = true}) {
    final moves = <GameAction>[];
    final captures = <GameAction>[];
    final positions = isSelf ? selfPositions : enemyPositions;

    // 翻牌
    if (includeFlips && (isSelf ? selfHidden : enemyHidden).isNotEmpty) {
      for (final i in hiddenPositions) {
        moves.add(FlipAction(i));
      }
    }

    // 移动
    for (final MapEntry(key: type, value: i) in positions.entries) {
      final r = i ~/ size;
      final c = i % size;

      for (final (dr, dc) in planeAround) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;

        final ni = nr * size + nc;
        final target = situation[ni];

        if (_CellUtils.isHidden(target)) continue;
        if (isSelf ? _CellUtils.isSelf(target) : _CellUtils.isEnemy(target)) {
          continue;
        }
        if (!_CellUtils.canEnterTerrain(
          type,
          _CellUtils.terrain(situation[i]),
          _CellUtils.terrain(target),
        )) {
          continue;
        }

        if (!_CellUtils.isEmpty(target)) {
          // 只有能吃掉敌方棋子时才添加为吃子走法
          if (_CellUtils.canEat(type, _CellUtils.animal(target))) {
            captures.add(MoveAction(i, ni));
          }
        } else {
          moves.add(MoveAction(i, ni));
        }
      }
    }

    captures.sort((a, b) {
      final aVal =
          _Constants.baseScores[_CellUtils.animal(
            situation[(a as MoveAction).to],
          )] ??
          0;
      final bVal =
          _Constants.baseScores[_CellUtils.animal(
            situation[(b as MoveAction).to],
          )] ??
          0;
      return bVal.compareTo(aVal);
    });

    return captures..addAll(moves);
  }

  /// 公开位置评估
  double evaluatePosition() => _Evaluator.evaluate(this);

  // --- 威胁判断 ---

  /// 判断 pos 位置的 piece 是否被敌方威胁
  /// [isSelf] 为 true 表示检查己方棋子的威胁，false 表示检查敌方棋子
  bool isThreatened(int pos, AnimalType piece, bool isSelf) {
    final r = pos ~/ size;
    final c = pos % size;
    final terrain = _CellUtils.terrain(situation[pos]);

    if (terrain == CellType.tree && !_CellUtils.treeAnimals.contains(piece)) {
      return false;
    }

    for (final (dr, dc) in planeAround) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
      final adj = situation[nr * size + nc];
      if (_CellUtils.isEmpty(adj) || _CellUtils.isHidden(adj)) continue;
      // 根据视角跳过己方棋子
      final adjIsSelf = _CellUtils.isSelf(adj);
      if (isSelf ? adjIsSelf : !adjIsSelf) continue;

      final adjType = _CellUtils.animal(adj);
      if (!_CellUtils.canEat(adjType, piece)) continue;
      if (!_CellUtils.canEnterTerrain(
        adjType,
        _CellUtils.terrain(adj),
        terrain,
      )) {
        continue;
      }

      return true;
    }
    return false;
  }
}

// ============================================================
// _Evaluator — 局面评估引擎
// ============================================================

abstract final class _Evaluator {
  /// 计算各方每个明棋的动态分值（总分 - 威胁扣分）
  static Map<AnimalType, double> calcDynamicScores(
    _SearchBoard board,
    bool isSelf,
  ) {
    final result = <AnimalType, double>{};
    final positions = isSelf ? board.selfPositions : board.enemyPositions;
    final enemyPos = isSelf ? board.enemyPositions : board.selfPositions;
    final enemyH = isSelf ? board.enemyHidden : board.selfHidden;

    // 合并所有敌方动物类型（明棋 + 暗棋）
    final allEnemyTypes = <AnimalType>{}
      ..addAll(enemyPos.keys)
      ..addAll(enemyH);

    // 如果敌方没有任何棋子
    if (allEnemyTypes.isEmpty) {
      // 返回所有棋子满分（无威胁）
      for (final type in positions.keys) {
        result[type] = _Constants.totalScore.toDouble();
      }
      return result;
    }

    for (final MapEntry(key: type) in positions.entries) {
      double penalty = 0.0;

      // 统一遍历所有敌方类型
      for (final eType in allEnemyTypes) {
        if (_CellUtils.canEat(eType, type)) {
          final factor = _CellUtils.canEat(type, eType)
              ? _Constants
                    .threatPenaltyHalf // 0.5
              : _Constants.threatPenaltyFull; // 1.0
          penalty += _Constants.baseScores[eType]! * factor;
        }
      }

      result[type] = _Constants.totalScore - penalty;
    }

    return result;
  }

  /// 局面评估：材料分 + 局势分 + 机动性分
  static double evaluate(_SearchBoard board) => _calc(board).$1;

  /// 带日志的评估（仅顶层调用）
  static double logEvaluate(_SearchBoard board, int boardSize) {
    final (total, material, position, mobility, selfD, enemyD) = _calc(board);

    if (total.abs() >= _Constants.winScore) {
      _AiLog.d('[Eval] ${total > 0 ? "AI WINS" : "ENEMY WINS"}');
      return total;
    }

    // 材料分明细（紧凑格式）
    String fmtSide(
      Map<AnimalType, int> positions,
      List<AnimalType> hidden,
      Map<AnimalType, double> dynScores,
    ) {
      final parts = <String>[];
      for (final MapEntry(key: type, value: pos) in positions.entries) {
        final dyn = dynScores[type] ?? 0;
        parts.add(
          '${_AiLog.animal(type)}@${_AiLog._pos(pos, boardSize)}=${_AiLog.score(dyn)}',
        );
      }
      for (final type in hidden) {
        parts.add('${_AiLog.animal(type)}?=${_Constants.baseScores[type]}');
      }
      return parts.join(' ');
    }

    // 威胁明细
    final threats = <String>[];
    for (int i = 0; i < board.situation.length; i++) {
      final c = board.situation[i];
      if (_CellUtils.isEmpty(c) || _CellUtils.isHidden(c)) continue;
      final isSelf = _CellUtils.isSelf(c);
      final type = _CellUtils.animal(c);
      if (board.isThreatened(i, type, isSelf)) {
        final weight = isSelf ? (selfD[type] ?? 0) : (enemyD[type] ?? 0);
        final delta =
            (isSelf ? -1 : 1) * weight * _Constants.positionThreatWeight;
        threats.add(
          '${isSelf ? "AI" : "P"}${_AiLog.animal(type)}@${_AiLog._pos(i, boardSize)}'
          '(${_AiLog.score(delta)})',
        );
      }
    }

    _AiLog.d(
      '[Eval] M=${_AiLog.score(material)} P=${_AiLog.score(position)} '
      'Mo=${_AiLog.score(mobility)} → ${_AiLog.score(total)}',
    );
    _AiLog.d('  AI: ${fmtSide(board.selfPositions, board.selfHidden, selfD)}');
    _AiLog.d(
      '  P: ${fmtSide(board.enemyPositions, board.enemyHidden, enemyD)}',
    );
    if (threats.isNotEmpty) _AiLog.d('  Threats: ${threats.join(" ")}');

    return total;
  }

  /// 核心计算，返回 (总分, 材料, 局势, 机动性, 己方动态分, 敌方动态分)
  static (
    double,
    double,
    double,
    double,
    Map<AnimalType, double>,
    Map<AnimalType, double>,
  )
  _calc(_SearchBoard board) {
    final selfD = calcDynamicScores(board, true);
    final enemyD = calcDynamicScores(board, false);
    if (board.selfPositions.isEmpty && board.selfHidden.isEmpty) {
      return (-_Constants.winScore, 0, 0, 0, selfD, enemyD);
    }
    if (board.enemyPositions.isEmpty && board.enemyHidden.isEmpty) {
      return (_Constants.winScore, 0, 0, 0, selfD, enemyD);
    }

    double material = 0, position = 0;

    // 材料分（动态分值：未被威胁的棋子更珍贵）
    for (final type in board.selfPositions.keys) {
      material += selfD[type] ?? 0;
    }
    for (final type in board.enemyPositions.keys) {
      material -= enemyD[type] ?? 0;
    }
    for (final type in board.selfHidden) {
      material += _Constants.baseScores[type]!.toDouble();
    }
    for (final type in board.enemyHidden) {
      material -= _Constants.baseScores[type]!.toDouble();
    }

    // 局势分
    for (int i = 0; i < board.situation.length; i++) {
      final c = board.situation[i];
      if (_CellUtils.isEmpty(c) || _CellUtils.isHidden(c)) continue;
      final isSelf = _CellUtils.isSelf(c);
      final type = _CellUtils.animal(c);
      final weight = isSelf ? (selfD[type] ?? 0) : (enemyD[type] ?? 0);
      if (board.isThreatened(i, type, isSelf)) {
        position +=
            (isSelf ? -1 : 1) * weight * _Constants.positionThreatWeight;
      }
    }

    // 机动性分
    final mobility =
        (board.generateMoves(true).length - board.generateMoves(false).length) *
        _Constants.mobilityWeight;

    return (
      material + position + mobility,
      material,
      position,
      mobility,
      selfD,
      enemyD,
    );
  }
}

// ============================================================
// _SearchEngine — Minimax + Alpha-Beta 剪枝搜索
// ============================================================

abstract final class _SearchEngine {
  /// 位计数（int 最多 8 位有效，足够 AnimalType 用）
  static int _popcount(int v) {
    int count = 0;
    while (v != 0) {
      count++;
      v &= v - 1;
    }
    return count;
  }

  /// 搜索所有移动走法及评分（入口，只考虑明棋移动，不考虑翻牌），按评分降序
  static List<(GameAction, double)> searchMoves(
    _SearchBoard board,
    int boardSize,
  ) {
    final moves = board.generateMoves(true, includeFlips: false);
    if (moves.isEmpty) return [];

    _AiLog.d(
      '[Search] ${moves.length} moves (depth=${_Constants.searchDepth})',
    );

    final scored = <(GameAction, double)>[];

    for (final action in moves) {
      final score = _execAndEval(board, action, () {
        return _minimax(
          board,
          _Constants.searchDepth - 1,
          double.negativeInfinity,
          double.infinity,
          false,
        );
      });
      scored.add((action, score));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));

    // 只打印前3个候选
    final showCount = scored.length < 3 ? scored.length : 3;
    for (int i = 0; i < showCount; i++) {
      final (action, score) = scored[i];
      final marker = i == 0 ? ' ★' : '';
      _AiLog.d(
        '  ${_AiLog.action(action, boardSize).padRight(18)} '
        '${_AiLog.score(score)}$marker',
      );
    }
    if (scored.length > 3) {
      _AiLog.d('  ... and ${scored.length - 3} more');
    }

    return scored;
  }

  /// 翻牌评估：综合暗棋数量/类型和场上明棋局势，评估每个暗棋位置的翻牌收益
  static (FlipAction, double) evaluateFlipBenefit(
    _SearchBoard board,
    List<int> hiddenPositions,
    double currentScore,
  ) {
    double bestBenefit = double.negativeInfinity;
    int bestPos = hiddenPositions.first;

    for (final pos in hiddenPositions) {
      final benefit = _calcFlipBenefit(board, pos, currentScore);
      _AiLog.d(
        '  Flip${_AiLog._pos(pos, board.size)} '
        'benefit=${_AiLog.score(benefit)}',
      );
      if (benefit > bestBenefit) {
        bestBenefit = benefit;
        bestPos = pos;
      }
    }
    return (FlipAction(bestPos), bestBenefit);
  }

  // --- 私有方法 ---

  /// Minimax + Alpha-Beta 剪枝
  static double _minimax(
    _SearchBoard board,
    int depth,
    double alpha,
    double beta,
    bool isMax,
  ) {
    if (depth == 0) return _Evaluator.evaluate(board);

    final moves = board.generateMoves(isMax, includeFlips: false);
    if (moves.isEmpty) return _Evaluator.evaluate(board);

    double value = isMax ? double.negativeInfinity : double.infinity;

    for (final action in moves) {
      final childScore = _execAndEval(board, action, () {
        return _minimax(board, depth - 1, alpha, beta, !isMax);
      });

      if (isMax) {
        value = max(value, childScore);
        alpha = max(alpha, value);
      } else {
        value = min(value, childScore);
        beta = min(beta, value);
      }
      if (beta <= alpha) break;
    }
    return value;
  }

  /// 执行 action → 回调 → 撤销，返回回调结果
  static double _execAndEval(
    _SearchBoard board,
    GameAction action,
    double Function() fn,
  ) {
    if (action is FlipAction) return board.withFlip(action, fn);
    return board.withMove(action as MoveAction, fn);
  }

  /// 计算某暗棋位置的翻牌收益（相对于 currentScore 的增量）
  ///
  /// 综合考虑三个因素：
  /// 1. 邻域明棋：翻出后是否安全（己方）或能被吃掉（敌方）
  /// 2. 地形匹配：剩余暗棋能否利用该地形（树/河）
  /// 3. 距离因素：到最近明棋的距离（越近越有价值）
  static double _calcFlipBenefit(
    _SearchBoard board,
    int pos,
    double currentScore,
  ) {
    final selfH = board.selfHidden;
    final enemyH = board.enemyHidden;
    final totalHidden = selfH.length + enemyH.length;
    if (totalHidden == 0) return 0;

    final terrain = _CellUtils.terrain(board.situation[pos]);
    final r = pos ~/ board.size;
    final c = pos % board.size;

    // ---- 单次遍历邻居：同时收集明棋 + 检查特殊地形 ----
    final adjacentSelf = <(AnimalType, CellType)>[];
    final adjacentEnemy = <(AnimalType, CellType)>[];
    bool hasRiverNeighbor = false;
    bool hasTreeNeighbor = false;
    bool hasBridgeNeighbor = false;

    for (final (dr, dc) in planeAround) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= board.size || nc < 0 || nc >= board.size) continue;
      final adjPos = nr * board.size + nc;
      final adj = board.situation[adjPos];
      final adjTerrain = _CellUtils.terrain(adj);

      if (_CellUtils.isSelf(adj)) {
        adjacentSelf.add((_CellUtils.animal(adj), adjTerrain));
      } else if (_CellUtils.isEnemy(adj)) {
        adjacentEnemy.add((_CellUtils.animal(adj), adjTerrain));
      }

      if (adjTerrain == CellType.river) hasRiverNeighbor = true;
      if (adjTerrain == CellType.tree) hasTreeNeighbor = true;
      if (adjTerrain == CellType.bridge) hasBridgeNeighbor = true;
    }

    // ---- 因素1：邻域明棋评估 ----
    double neighborValue = 0;
    final prob = 1.0 / totalHidden;

    for (final type in selfH) {
      bool threatened = false;
      for (final (eType, eTerrain) in adjacentEnemy) {
        if (_CellUtils.canEat(eType, type) &&
            _CellUtils.canEnterTerrain(eType, eTerrain, terrain)) {
          threatened = true;
          break;
        }
      }
      final value = _Constants.baseScores[type]!.toDouble();
      neighborValue += prob * (threatened ? -value : value);
    }

    for (final type in enemyH) {
      bool canEat = false;
      for (final (sType, sTerrain) in adjacentSelf) {
        if (_CellUtils.canEat(sType, type) &&
            _CellUtils.canEnterTerrain(sType, sTerrain, terrain)) {
          canEat = true;
          break;
        }
      }
      final value = _Constants.baseScores[type]!.toDouble();
      neighborValue += prob * (canEat ? value : -value);
    }

    // ---- 因素2：地形匹配（用 bitfield 替代临时 Set）----
    double terrainBonus = 0;
    // 用 int 位标记暗棋类型，避免 Set 分配
    int hiddenBits = 0;
    for (final t in selfH) {
      hiddenBits |= 1 << t.index;
    }
    for (final t in enemyH) {
      hiddenBits |= 1 << t.index;
    }

    if (hasRiverNeighbor) {
      int riverBits = 0;
      for (final t in _CellUtils.riverAnimals) {
        riverBits |= 1 << t.index;
      }
      terrainBonus += _popcount(hiddenBits & riverBits) * 0.8;
    }

    if (hasTreeNeighbor) {
      int treeBits = 0;
      for (final t in _CellUtils.treeAnimals) {
        treeBits |= 1 << t.index;
      }
      terrainBonus += _popcount(hiddenBits & treeBits) * 0.8;
    }

    if (hasBridgeNeighbor) {
      terrainBonus += 0.3;
    }

    final isCorner =
        (r == 0 || r == board.size - 1) && (c == 0 || c == board.size - 1);
    if (isCorner) {
      terrainBonus -= 0.5;
    }

    // ---- 因素3：距离因素 ----
    double distanceBonus = 0;
    int minDist = board.size * 2;
    for (final entry in board.selfPositions.entries) {
      final er = entry.value ~/ board.size;
      final ec = entry.value % board.size;
      final dist = (r - er).abs() + (c - ec).abs();
      if (dist < minDist) minDist = dist;
    }
    for (final entry in board.enemyPositions.entries) {
      final er = entry.value ~/ board.size;
      final ec = entry.value % board.size;
      final dist = (r - er).abs() + (c - ec).abs();
      if (dist < minDist) minDist = dist;
    }
    if (minDist > 0) {
      distanceBonus = 1.0 / minDist;
    }

    return neighborValue + terrainBonus + distanceBonus * 0.5;
  }
}

// ============================================================
// _AiLog — 日志输出
// ============================================================

abstract final class _AiLog {
  static const _animalAbbr = ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'];

  static void d(String msg) => debugPrint('[debug] $msg');

  /// 格式化分数（保留1位小数）
  static String score(double v) => v.toStringAsFixed(1);

  /// 格式化棋子类型缩写
  static String animal(AnimalType type) => _animalAbbr[type.index];

  static String _pos(int index, int size) =>
      '(${index ~/ size},${index % size})';

  static String action(GameAction action, int size) {
    if (action is FlipAction) return 'Flip${_pos(action.index, size)}';
    if (action is MoveAction) {
      return 'Move${_pos(action.from, size)}->${_pos(action.to, size)}';
    }
    return action.toString();
  }

  /// 紧凑棋盘打印：己方大写 / 敌方小写 / 暗棋 ? / 空 .
  static void board(
    String label,
    List<CellView> board,
    int size,
    TurnGamerType aiFaction,
  ) {
    const terrainChar = ['L', 'R', 'O', 'B', 'T'];
    final sb = StringBuffer('  ');
    for (int c = 0; c < size; c++) {
      sb.write(c.toString().padLeft(3));
    }
    sb.writeln();

    for (int r = 0; r < size; r++) {
      sb.write('${r.toString().padLeft(2)}  ');
      for (int c = 0; c < size; c++) {
        final cell = board[r * size + c];
        final t = terrainChar[cell.type.index];
        if (!cell.hasAnimal) {
          sb.write('$t.');
        } else if (cell.animal!.isHidden) {
          sb.write('$t?');
        } else {
          final a = _animalAbbr[cell.animal!.type.index];
          sb.write(
            cell.animal!.owner == aiFaction ? '$t$a' : '$t${a.toLowerCase()}',
          );
        }
        sb.write(' ');
      }
      sb.writeln();
    }
    d('$label:\n$sb');
  }
}

// ============================================================
// AiController — AI 控制器（公开 API）
// ============================================================

class AiController {
  static final _random = Random();
  final _Zobrist _zobrist = _Zobrist.instance;

  final UnmodifiableListView<CellView> board;
  final int boardSize;
  final TurnGamerType faction;

  late final BoardSnapshot aiSnapshot;
  late final BoardSnapshot playerSnapshot;

  AiController({
    required this.board,
    required this.boardSize,
    required this.faction,
  }) {
    aiSnapshot = BoardSnapshot.fromBoard(board, boardSize, faction);
    playerSnapshot = BoardSnapshot.fromBoard(
      board,
      boardSize,
      faction.opponent,
    );
  }

  /// AI 决策入口
  GameAction? getAction() {
    _AiLog.board('AI', board, boardSize, faction);

    // 1. 无明棋 → 随机翻牌（不存储）
    if (aiSnapshot.selfVisible.isEmpty && aiSnapshot.enemyVisible.isEmpty) {
      final flip = _randomFlip(aiSnapshot);
      if (flip != null) {
        _zobrist.store(aiSnapshot.boardInfo, flip, true);
        _AiLog.d('[Step1] No visible → random flip');
        _updateSnapshot(flip);
        return flip;
      }
    }

    // 2. Zobrist 查表（命中且不重复则直接返回，不存储）
    final cached = _zobrist.lookup(aiSnapshot.boardInfo);
    if (cached != null) {
      final hash = aiSnapshot.boardInfo.hash!;
      if (cached is MoveAction && _zobrist.detectRepetition(hash, cached)) {
        _AiLog.d(
          '[Step2] Cache HIT but repeat → skip ${_AiLog.action(cached, boardSize)}',
        );
      } else {
        _zobrist.store(aiSnapshot.boardInfo, cached, true);
        _AiLog.d('[Step2] Cache HIT → ${_AiLog.action(cached, boardSize)}');
        _updateSnapshot(cached);
        return cached;
      }
    }

    // 3. Minimax 搜索（只考虑明棋移动）
    final searchBoard = _SearchBoard.fromSnapshot(aiSnapshot);
    _Evaluator.logEvaluate(searchBoard, boardSize);
    final scoredMoves = _SearchEngine.searchMoves(searchBoard, boardSize);

    // 4. 规避反复行动
    final int hash = aiSnapshot.boardInfo.hash!;
    GameAction? bestMove;
    double moveScore = double.negativeInfinity;

    for (final (action, score) in scoredMoves) {
      if (action is MoveAction && _zobrist.detectRepetition(hash, action)) {
        _AiLog.d('  Skip ${_AiLog.action(action, boardSize)} (repeat)');
        continue;
      }
      bestMove = action;
      moveScore = score;
      break;
    }

    // 5. 有暗棋 → 评估翻牌收益，与移动收益比较
    final hidden = aiSnapshot.hiddenPositions;
    if (hidden.isNotEmpty) {
      final currentScore = searchBoard.evaluatePosition();
      final (bestFlip, flipBenefit) = _SearchEngine.evaluateFlipBenefit(
        searchBoard,
        hidden,
        currentScore,
      );

      _AiLog.d(
        '[Step5] Hidden=${hidden.length} currentScore=${_AiLog.score(currentScore)}',
      );
      _AiLog.d(
        '  BestMove: ${bestMove != null ? _AiLog.action(bestMove, boardSize) : "none"} '
        'score=${_AiLog.score(moveScore)}',
      );
      _AiLog.d(
        '  BestFlip: ${_AiLog.action(bestFlip, boardSize)} '
        'benefit=${_AiLog.score(flipBenefit)}',
      );

      // 移动分为正 → 优先移动；移动分为负 → 翻牌收益需超过 |moveScore|
      if (bestMove == null || (moveScore <= 0 && flipBenefit > -moveScore)) {
        _AiLog.d(
          '[Decision] FLIP (benefit=${_AiLog.score(flipBenefit)} '
          '> |moveScore|=${_AiLog.score(-moveScore)})',
        );
        _zobrist.store(aiSnapshot.boardInfo, bestFlip, true);
        _updateSnapshot(bestFlip);
        return bestFlip;
      }
    }

    // 6. 返回最佳移动（搜索产生，存储）
    if (bestMove != null) {
      _zobrist.store(aiSnapshot.boardInfo, bestMove, true);
      _AiLog.d(
        '[Decision] MOVE ${_AiLog.action(bestMove, boardSize)} score=${_AiLog.score(moveScore)}',
      );
      _updateSnapshot(bestMove);
      return bestMove;
    }

    _AiLog.d('[Decision] NONE (no action)');
    return null;
  }

  /// 玩家行动后更新快照并存表
  void applyPlayerAction(GameAction action) {
    _AiLog.d('Player: ${_AiLog.action(action, boardSize)}');
    _zobrist.store(playerSnapshot.boardInfo, action, false);
    _updateSnapshot(action);
  }

  void dispose() {}

  // --- 内部方法 ---
  FlipAction? _randomFlip(BoardSnapshot snapshot) {
    final hidden = snapshot.hiddenPositions;
    if (hidden.isEmpty) return null;
    return FlipAction(hidden[_random.nextInt(hidden.length)]);
  }

  /// 增量更新快照
  void _updateSnapshot(GameAction action) {
    void applyToBoth(void Function(BoardSnapshot) fn) {
      fn(aiSnapshot);
      fn(playerSnapshot);
    }

    if (action is FlipAction) {
      final cell = board[action.index];
      final animal = cell.animal;
      if (!cell.hasAnimal || animal == null) return;

      applyToBoth(
        (snap) =>
            snap.applyFlip(action.index, cell.type, animal.type, animal.owner),
      );
    } else if (action is MoveAction) {
      final fromCell = board[action.from];
      final toCell = board[action.to];

      AnimalType movingType;
      TurnGamerType movingOwner;
      AnimalType? capturedType;

      if (fromCell.hasAnimal && fromCell.animal != null) {
        movingType = fromCell.animal!.type;
        movingOwner = fromCell.animal!.owner;
        if (toCell.hasAnimal && toCell.animal!.owner != movingOwner) {
          capturedType = toCell.animal!.type;
        }
      } else {
        final snapshotFrom = aiSnapshot.situation[action.from];
        if (_CellUtils.isEmpty(snapshotFrom) ||
            _CellUtils.isHidden(snapshotFrom)) {
          return;
        }
        movingType = _CellUtils.animal(snapshotFrom);
        final isSelf = _CellUtils.isSelf(snapshotFrom);
        movingOwner = isSelf ? faction : faction.opponent;

        final snapshotTo = aiSnapshot.situation[action.to];
        if (!_CellUtils.isEmpty(snapshotTo) &&
            !_CellUtils.isHidden(snapshotTo)) {
          final toIsSelf = _CellUtils.isSelf(snapshotTo);
          if (toIsSelf != isSelf) {
            capturedType = _CellUtils.animal(snapshotTo);
          }
        }
      }

      applyToBoth(
        (snap) => snap.applyMove(
          action.from,
          action.to,
          movingType,
          movingOwner,
          toType: capturedType,
        ),
      );
    }
  }
}
