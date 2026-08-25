import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/map.dart';
import 'base.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 编码层 — 格子的位编码、吃子规则、地形通行
// ═══════════════════════════════════════════════════════════════════════════════

/// 格子位编码：[8..5]=动物类型 [4..3]=占据状态 [2..0]=地形类型
abstract final class CellCodec {
  static const _terrainBits = 0x07;
  static const _occupyShift = 3;
  static const _occupyBits = 0x03;
  static const _animalShift = 5;
  static const _animalBits = 0x07;

  // 占据状态枚举
  static const empty = 0, hidden = 1, self = 2, enemy = 3;

  // 解码
  static int occupy(int c) => (c >> _occupyShift) & _occupyBits;
  static AnimalType animal(int c) =>
      AnimalType.values[(c >> _animalShift) & _animalBits];
  static CellType terrain(int c) => CellType.values[c & _terrainBits];

  // 状态判断
  static bool isEmpty(int c) => occupy(c) == empty;
  static bool isHidden(int c) => occupy(c) == hidden;
  static bool isSelf(int c) => occupy(c) == self;
  static bool isEnemy(int c) => occupy(c) == enemy;

  // 编码
  static int encode(CellType terrain, int occupy, AnimalType? animal) =>
      terrain.index |
      (occupy << _occupyShift) |
      ((animal?.index ?? 0) << _animalShift);

  static int encodeEmpty(CellType terrain) => terrain.index;

  /// 只更新占据状态和动物类型（地形不变）
  static int updateOccupy(int cell, int occupy, AnimalType animal) =>
      (cell & _terrainBits) |
      (occupy << _occupyShift) |
      (animal.index << _animalShift);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 评估参数 — 所有魔法数字集中管理
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class EvalParams {
  // 搜索
  static const searchDepth = 6;
  // 将翻牌后续搜索深度设为 searchDepth - 1 = 5，与移动搜索绝对公平
  static const flipDepth = searchDepth - 1;

  // 动态分值
  static const totalScore = 16.0;
  static const threatHalf = 0.5; // 互吃威胁扣分系数
  static const threatFull = 1.0; // 单向威胁扣分系数
  static const positionWeight = 0.3; // 局势分权重
  static const mobilityWeight = 0.1; // 机动性分权重
  static const entropyWeight = 0.5; // 暗棋信息熵权重，体现未翻牌的战略价值

  static const winScore = 100000.0;

  static const maxCells = 169;
  static const cellCodeCount = 18;
  static const animalTypeCount = 8;
  static const historyLimit = 6;
  static const repeatThreshold = 2;

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

// ═══════════════════════════════════════════════════════════════════════════════
// 棋盘状态基类 — 公共数据结构和操作
// ═══════════════════════════════════════════════════════════════════════════════

/// 棋盘信息（Zobrist 哈希用，故意忽略暗棋位置）
class BoardInfo {
  final int size;
  final List<int> situation;
  final List<AnimalType> selfHidden;
  final List<AnimalType> enemyHidden;
  int? hash;

  BoardInfo(this.size, this.situation, this.selfHidden, this.enemyHidden)
    : hash = null;
}

/// 棋盘状态基类 — 维护己方/敌方双视角
class BoardState {
  final int size;
  final List<int> situation;
  final List<AnimalType> selfHidden;
  final List<AnimalType> enemyHidden;
  final Map<AnimalType, int> selfPos;
  final Map<AnimalType, int> enemyPos;
  final List<int> hiddenPositions;

  BoardState(
    this.size,
    this.situation,
    this.selfHidden,
    this.enemyHidden,
    this.selfPos,
    this.enemyPos,
    this.hiddenPositions,
  );

  /// 翻牌：更新局势和势力
  void applyFlip(int index, AnimalType type, bool isSelf) {
    situation[index] = CellCodec.updateOccupy(
      situation[index],
      isSelf ? CellCodec.self : CellCodec.enemy,
      type,
    );
    hiddenPositions.remove(index);
    (isSelf ? selfHidden : enemyHidden).remove(type);
    (isSelf ? selfPos : enemyPos)[type] = index;
  }

  /// 移动：空移改位置，有敌方棋子根据规则判断
  void applyMove(int from, int to) {
    final fromCell = situation[from];
    final fromType = CellCodec.animal(fromCell);
    final isSelf = CellCodec.isSelf(fromCell);
    final selfMap = isSelf ? selfPos : enemyPos;
    final enemyMap = isSelf ? enemyPos : selfPos;

    // 清空 from
    situation[from] = CellCodec.encodeEmpty(CellCodec.terrain(fromCell));

    // 判断目标位置
    final toCell = situation[to];
    if (CellCodec.isEmpty(toCell)) {
      // 空移
      situation[to] = CellCodec.updateOccupy(
        toCell,
        isSelf ? CellCodec.self : CellCodec.enemy,
        fromType,
      );
      selfMap[fromType] = to;
    } else {
      // 吃子：根据规则判断
      final toType = CellCodec.animal(toCell);
      final aWin = Rules.canEat(fromType, toType);
      final dWin = Rules.canEat(toType, fromType);

      if (aWin && dWin) {
        // 同归于尽
        situation[to] = CellCodec.encodeEmpty(CellCodec.terrain(toCell));
        selfMap.remove(fromType);
        enemyMap.remove(toType);
      } else if (aWin) {
        // 攻方胜
        situation[to] = CellCodec.updateOccupy(
          toCell,
          isSelf ? CellCodec.self : CellCodec.enemy,
          fromType,
        );
        enemyMap.remove(toType);
        selfMap[fromType] = to;
      } else {
        // 守方胜
        selfMap.remove(fromType);
      }
    }
  }

  /// 遍历 pos 的所有有效邻居索引
  void forEachNeighbor(int pos, void Function(int ni) fn) {
    final r = pos ~/ size, c = pos % size;
    for (final (dr, dc) in planeAround) {
      final nr = r + dr, nc = c + dc;
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) fn(nr * size + nc);
    }
  }

  @override
  String toString() {
    const tChar = ['L', 'R', 'O', 'B', 'T'];
    const aChar = ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'];
    const oChar = ['-', '?', 'S', 'E'];
    final sb = StringBuffer('BoardState\n');
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cell = situation[r * size + c];
        final occupy = CellCodec.occupy(cell);
        final a = occupy >= 2 ? aChar[CellCodec.animal(cell).index] : ' ';
        sb.write('${tChar[cell & 0x07]}${oChar[occupy]}$a ');
      }
      sb.writeln();
    }
    sb.writeln('selfPos: $selfPos');
    sb.writeln('enemyPos: $enemyPos');
    sb.writeln('selfHidden: $selfHidden');
    sb.writeln('enemyHidden: $enemyHidden');
    return sb.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 棋盘快照 — AI 对棋局状态的理解（继承 BoardState）
// ═══════════════════════════════════════════════════════════════════════════════

/// 棋盘快照 — 维护己方/敌方双视角，支持 Zobrist 哈希
class BoardSnapshot extends BoardState {
  final TurnGamerType faction;
  BoardInfo _info;

  BoardInfo get boardInfo => _info;

  BoardSnapshot._(this.faction, int size, List<int> situation)
    : _info = BoardInfo(size, situation, [], []),
      super(size, situation, [], [], {}, {}, []);

  factory BoardSnapshot.fromBoard(
    List<CellView> board,
    int size,
    TurnGamerType faction,
  ) {
    final snap = BoardSnapshot._(
      faction,
      size,
      List<int>.filled(size * size, 0),
    );
    snap._initFromBoard(board);
    return snap;
  }

  void _initFromBoard(List<CellView> board) {
    final selfTypes = <AnimalType>{};
    final enemyTypes = <AnimalType>{};

    for (int i = 0; i < board.length; i++) {
      final cell = board[i];
      if (!cell.hasAnimal) {
        situation[i] = CellCodec.encodeEmpty(cell.type);
      } else if (cell.animal!.isHidden) {
        situation[i] = CellCodec.encode(cell.type, CellCodec.hidden, null);
        hiddenPositions.add(i);
        (cell.animal!.owner == faction ? selfTypes : enemyTypes).add(
          cell.animal!.type,
        );
      } else {
        final isSelf = cell.animal!.owner == faction;
        situation[i] = CellCodec.encode(
          cell.type,
          isSelf ? CellCodec.self : CellCodec.enemy,
          cell.animal!.type,
        );
        (isSelf ? selfPos : enemyPos)[cell.animal!.type] = i;
      }
    }

    selfHidden.addAll(selfTypes);
    enemyHidden.addAll(enemyTypes);
    _info = BoardInfo(size, situation, selfHidden, enemyHidden);
  }

  /// 翻牌（覆写：同步更新 BoardInfo）
  @override
  void applyFlip(int index, AnimalType type, bool isSelf) {
    super.applyFlip(index, type, isSelf);
    _info.hash = null;
  }

  /// 移动（覆写：同步更新 BoardInfo）
  @override
  void applyMove(int from, int to) {
    super.applyMove(from, to);
    _info.hash = null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Zobrist 哈希 — 缓存搜索结果、检测重复局面
// ═══════════════════════════════════════════════════════════════════════════════

class ZobristHash {
  static final instance = ZobristHash._();
  final _rng = Random(2024);

  late final List<List<int>> _cellKeys;
  late final List<int> _selfKeys;
  late final List<int> _enemyKeys;
  final Map<int, GameAction> _table = {};
  final List<(int, GameAction)> _history = [];

  ZobristHash._() {
    _cellKeys = List.generate(
      EvalParams.maxCells,
      (_) => List.generate(EvalParams.cellCodeCount, (_) => _rand64()),
    );
    _selfKeys = List.generate(EvalParams.animalTypeCount, (_) => _rand64());
    _enemyKeys = List.generate(EvalParams.animalTypeCount, (_) => _rand64());
  }

  int _rand64() =>
      (_rng.nextInt(1 << 22) << 42) ^
      (_rng.nextInt(1 << 21) << 21) ^
      _rng.nextInt(1 << 21);

  /// cell → hash code（0=空, 1~8=己方, 9~16=敌方, 17=暗棋）
  int _cellCode(int cell) {
    if (cell == 0) return 0;
    final occupy = CellCodec.occupy(cell);
    if (occupy == CellCodec.empty) return 0;
    if (occupy == CellCodec.hidden) return 17;
    final animal = CellCodec.animal(cell).index;
    return occupy == CellCodec.self ? animal + 1 : animal + 9;
  }

  /// 计算棋盘哈希（位置相关，确保对称变体不同），结果缓存在 BoardInfo.hash
  int computeHash(BoardInfo info) {
    final cached = info.hash;
    if (cached != null) return cached;
    int h = 0;
    for (int i = 0; i < info.situation.length; i++) {
      h ^= _cellKeys[i][_cellCode(info.situation[i])] ^ i;
    }
    for (final t in info.selfHidden) {
      h ^= _selfKeys[t.index];
    }
    for (final t in info.enemyHidden) {
      h ^= _enemyKeys[t.index];
    }
    info.hash = h;
    return h;
  }

  /// 查表
  GameAction? lookup(BoardInfo info) => _table[computeHash(info)];

  /// 存表（四重对称，共 4 条记录）
  void store(BoardInfo info, GameAction action, bool isAi) {
    final hash = computeHash(info);
    if (isAi) {
      _recordAiMove(hash, action);
      if (_table.containsKey(hash)) {
        _AiLog.d('Zobrist store: hash=$hash already exists, skip');
        return;
      }
    }

    // 玩家行动写入 Zobrist 是有意为之，用于 AI 模仿玩家
    _table[hash] = action;

    // 存储三个对称变体
    for (final t in _transforms) {
      final ts = _applyTransform(info.situation, info.size, t);
      final th = computeHash(
        BoardInfo(info.size, ts, info.selfHidden, info.enemyHidden),
      );
      _table[th] = action.transform(t, info.size);
    }
  }

  void _recordAiMove(int hash, GameAction action) {
    _history.add((hash, action));
    if (_history.length > EvalParams.historyLimit) _history.removeAt(0);
  }

  bool detectRepetition(int hash, GameAction action) =>
      _history.where((h) => h.$1 == hash && h.$2 == action).length >=
      EvalParams.repeatThreshold;

  // 四重对称变换
  static int _mirrorH(int i, int n) => (i ~/ n) * n + (n - 1 - i % n);
  static int _mirrorV(int i, int n) => (n - 1 - i ~/ n) * n + (i % n);
  static int _rotate180(int i, int n) => (n - 1 - i ~/ n) * n + (n - 1 - i % n);
  static const _transforms = [_mirrorH, _mirrorV, _rotate180];

  static List<int> _applyTransform(
    List<int> s,
    int n,
    int Function(int, int) t,
  ) {
    final r = List<int>.filled(s.length, 0);
    for (int i = 0; i < s.length; i++) {
      r[t(i, n)] = s[i];
    }
    return r;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 搜索棋盘 — 可变副本，支持 do/undo 用于 Minimax 搜索
// ═══════════════════════════════════════════════════════════════════════════════

class SearchBoard extends BoardState {
  SearchBoard._(
    super.size,
    super.situation,
    super.selfHidden,
    super.enemyHidden,
    super.selfPos,
    super.enemyPos,
    super.hiddenPositions,
  );

  factory SearchBoard.fromSnapshot(BoardSnapshot snap) => SearchBoard._(
    snap.size,
    List<int>.of(snap.situation),
    List<AnimalType>.of(snap.selfHidden),
    List<AnimalType>.of(snap.enemyHidden),
    Map<AnimalType, int>.of(snap.selfPos),
    Map<AnimalType, int>.of(snap.enemyPos),
    List<int>.of(snap.hiddenPositions),
  );

  // ──── 走法生成 ────

  /// 生成合法走法，吃子走法在前并按价值降序
  List<GameAction> generateMoves(bool isSelf, {bool includeFlips = true}) {
    final captures = <GameAction>[];
    final moves = <GameAction>[];
    final posMap = isSelf ? selfPos : enemyPos;
    final hidden = isSelf ? selfHidden : enemyHidden;

    // 翻牌
    if (includeFlips && hidden.isNotEmpty) {
      for (final i in hiddenPositions) {
        moves.add(FlipAction(i));
      }
    }

    // 移动
    for (final MapEntry(key: type, value: from) in posMap.entries) {
      final fromTerrain = CellCodec.terrain(situation[from]);
      forEachNeighbor(from, (to) {
        final target = situation[to];
        if (CellCodec.isHidden(target)) return;
        if (isSelf ? CellCodec.isSelf(target) : CellCodec.isEnemy(target)) {
          return;
        }
        if (!Rules.canEnter(type, fromTerrain, CellCodec.terrain(target))) {
          return;
        }

        if (CellCodec.isEmpty(target)) {
          moves.add(MoveAction(from, to));
        } else if (Rules.canEat(type, CellCodec.animal(target))) {
          captures.add(MoveAction(from, to));
        }
      });
    }

    // 吃子走法按被吃棋子价值降序
    captures.sort(
      (a, b) => _baseScore(CellCodec.animal(situation[(b as MoveAction).to]))
          .compareTo(
            _baseScore(CellCodec.animal(situation[(a as MoveAction).to])),
          ),
    );

    return captures..addAll(moves);
  }

  int _baseScore(AnimalType t) => EvalParams.baseScores[t] ?? 0;

  // ──── do/undo ────

  T withMove<T>(MoveAction a, T Function() fn) {
    final undo = _doMove(a.from, a.to);
    final result = fn();
    _undoMove(undo);
    return result;
  }

  // 指定 forceAnimal
  T withFlip<T>(
    FlipAction a,
    T Function() fn, {
    required bool forceSelf,
    required AnimalType forceAnimal,
  }) {
    final undo = _doFlip(
      a.index,
      forceSelf: forceSelf,
      forceAnimal: forceAnimal,
    );
    final result = fn();
    _undoFlip(a.index, undo);
    return result;
  }

  ({int from, int to, int fromCell, int toCell}) _doMove(int from, int to) {
    final undo = (
      from: from,
      to: to,
      fromCell: situation[from],
      toCell: situation[to],
    );
    if (CellCodec.isHidden(situation[to])) return undo;

    final mType = CellCodec.animal(situation[from]);
    final isSelf = CellCodec.isSelf(situation[from]);
    situation[from] = CellCodec.encodeEmpty(CellCodec.terrain(situation[from]));

    if (CellCodec.isEmpty(situation[to])) {
      _place(to, mType, isSelf);
    } else {
      _resolveCombat(to, mType, isSelf);
    }
    return undo;
  }

  void _place(int pos, AnimalType type, bool isSelf) {
    situation[pos] = CellCodec.updateOccupy(
      situation[pos],
      isSelf ? CellCodec.self : CellCodec.enemy,
      type,
    );
    (isSelf ? selfPos : enemyPos)[type] = pos;
  }

  void _resolveCombat(int pos, AnimalType attacker, bool isSelf) {
    final defender = CellCodec.animal(situation[pos]);
    final aWin = Rules.canEat(attacker, defender);
    final dWin = Rules.canEat(defender, attacker);

    if (aWin && dWin) {
      situation[pos] = CellCodec.encodeEmpty(CellCodec.terrain(situation[pos]));
      (isSelf ? selfPos : enemyPos).remove(attacker);
      (isSelf ? enemyPos : selfPos).remove(defender);
    } else if (aWin) {
      _place(pos, attacker, isSelf);
      (isSelf ? enemyPos : selfPos).remove(defender);
    } else if (dWin) {
      (isSelf ? selfPos : enemyPos).remove(attacker);
    }
  }

  ({int cell, bool isSelf, AnimalType animal, int hiddenIdx}) _doFlip(
    int index, {
    required bool forceSelf,
    required AnimalType forceAnimal,
  }) {
    final cell = situation[index];
    final isSelf = forceSelf;
    final animal = forceAnimal;
    final hidden = isSelf ? selfHidden : enemyHidden;
    final idx = hidden.indexOf(animal);

    // 理论上一定能在所属方暗棋池中找到该动物
    hidden.removeAt(idx);
    situation[index] = CellCodec.updateOccupy(
      cell,
      isSelf ? CellCodec.self : CellCodec.enemy,
      animal,
    );
    (isSelf ? selfPos : enemyPos)[animal] = index;

    return (cell: cell, isSelf: isSelf, animal: animal, hiddenIdx: idx);
  }

  void _undoMove(({int from, int to, int fromCell, int toCell}) u) {
    situation[u.from] = u.fromCell;
    situation[u.to] = u.toCell;
    _restorePos(u.from, u.fromCell);
    if (!CellCodec.isEmpty(u.toCell) && !CellCodec.isHidden(u.toCell)) {
      _restorePos(u.to, u.toCell);
    } else {
      _removePos(u.to);
    }
  }

  void _undoFlip(
    int index,
    ({int cell, bool isSelf, AnimalType animal, int hiddenIdx}) u,
  ) {
    final animal = u.animal;
    (u.isSelf ? selfPos : enemyPos).remove(animal);
    final hidden = u.isSelf ? selfHidden : enemyHidden;
    hidden.insert(u.hiddenIdx, animal);
    situation[index] = u.cell;
  }

  void _restorePos(int pos, int cell) {
    if (CellCodec.isEmpty(cell) || CellCodec.isHidden(cell)) return;
    (CellCodec.isSelf(cell) ? selfPos : enemyPos)[CellCodec.animal(cell)] = pos;
  }

  void _removePos(int pos) {
    final cell = situation[pos];
    if (CellCodec.isEmpty(cell) || CellCodec.isHidden(cell)) return;
    final type = CellCodec.animal(cell);
    final map = CellCodec.isSelf(cell) ? selfPos : enemyPos;
    if (map[type] == pos) map.remove(type);
  }

  // ──── 威胁判断 ────

  /// pos 位置的 piece 是否被 isSelf 视角的敌方威胁
  bool isThreatened(int pos, AnimalType piece, bool isSelf) {
    final terrain = CellCodec.terrain(situation[pos]);
    if (terrain == CellType.tree && !Rules.canClimbTree(piece)) return false;

    var result = false;
    forEachNeighbor(pos, (ni) {
      if (result) return;
      final adj = situation[ni];
      if (CellCodec.isEmpty(adj) || CellCodec.isHidden(adj)) return;
      if (isSelf ? CellCodec.isSelf(adj) : !CellCodec.isSelf(adj)) return;

      final adjType = CellCodec.animal(adj);
      if (Rules.canEat(adjType, piece) &&
          Rules.canEnter(adjType, CellCodec.terrain(adj), terrain)) {
        result = true;
      }
    });
    return result;
  }

  double evaluatePosition() => Evaluator.evaluate(this);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 评估结果
// ═══════════════════════════════════════════════════════════════════════════════

final class EvalResult {
  final double total, material, position, mobility;
  final Map<AnimalType, double> selfDynamic, enemyDynamic;
  const EvalResult(
    this.total,
    this.material,
    this.position,
    this.mobility,
    this.selfDynamic,
    this.enemyDynamic,
  );

  @override
  String toString() =>
      'M=${material.toStringAsFixed(1)} P=${position.toStringAsFixed(1)} '
      'Mo=${mobility.toStringAsFixed(1)} → ${total.toStringAsFixed(1)}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// 评估引擎 — 材料 + 局势 + 机动性 + 暗棋信息熵
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class Evaluator {
  /// 计算各方明棋的动态分值（总分 - 威胁扣分）
  static Map<AnimalType, double> calcDynamicScores(
    SearchBoard board,
    bool isSelf,
  ) {
    final posMap = isSelf ? board.selfPos : board.enemyPos;
    final enemyPos = isSelf ? board.enemyPos : board.selfPos;
    final enemyH = isSelf ? board.enemyHidden : board.selfHidden;

    // 合并所有敌方类型
    final allEnemy = {...enemyPos.keys, ...enemyH};
    if (allEnemy.isEmpty) {
      return {for (final t in posMap.keys) t: EvalParams.totalScore};
    }

    return {
      for (final MapEntry(key: type) in posMap.entries)
        type:
            EvalParams.totalScore -
            allEnemy.fold(0.0, (penalty, eType) {
              if (!Rules.canEat(eType, type)) return penalty;
              final factor = Rules.canEat(type, eType)
                  ? EvalParams.threatHalf
                  : EvalParams.threatFull;
              return penalty + EvalParams.baseScores[eType]! * factor;
            }),
    };
  }

  static double evaluate(SearchBoard board) => _calc(board).total;

  /// 返回完整评估结果（供外部日志使用）
  static EvalResult evaluateDetail(SearchBoard board) => _calc(board);

  static EvalResult _calc(SearchBoard board) {
    final selfD = calcDynamicScores(board, true);
    final enemyD = calcDynamicScores(board, false);

    // 终局
    if (board.selfPos.isEmpty && board.selfHidden.isEmpty) {
      return EvalResult(-EvalParams.winScore, 0, 0, 0, selfD, enemyD);
    }
    if (board.enemyPos.isEmpty && board.enemyHidden.isEmpty) {
      return EvalResult(EvalParams.winScore, 0, 0, 0, selfD, enemyD);
    }

    // 材料分
    final material =
        _sum(board.selfPos.keys, selfD) -
        _sum(board.enemyPos.keys, enemyD) +
        _sumBase(board.selfHidden) -
        _sumBase(board.enemyHidden);

    // 局势分
    double position = 0;
    for (int i = 0; i < board.situation.length; i++) {
      final c = board.situation[i];
      if (CellCodec.isEmpty(c) || CellCodec.isHidden(c)) continue;
      final isSelf = CellCodec.isSelf(c);
      final weight = isSelf
          ? (selfD[CellCodec.animal(c)] ?? 0)
          : (enemyD[CellCodec.animal(c)] ?? 0);
      if (board.isThreatened(i, CellCodec.animal(c), isSelf)) {
        position += (isSelf ? -1 : 1) * weight * EvalParams.positionWeight;
      }
    }

    // 机动性分
    final mobility =
        (board.generateMoves(true, includeFlips: false).length -
            board.generateMoves(false, includeFlips: false).length) *
        EvalParams.mobilityWeight;

    // 暗棋信息熵，反映未翻开棋子的战略威慑价值
    final entropy =
        (board.selfHidden.length - board.enemyHidden.length) *
        EvalParams.entropyWeight;

    return EvalResult(
      material + position + mobility + entropy,
      material,
      position,
      mobility,
      selfD,
      enemyD,
    );
  }

  static double _sum(
    Iterable<AnimalType> types,
    Map<AnimalType, double> scores,
  ) => types.fold(0.0, (s, t) => s + (scores[t] ?? 0));

  static double _sumBase(List<AnimalType> types) =>
      types.fold(0.0, (s, t) => s + EvalParams.baseScores[t]!.toDouble());
}

// ═══════════════════════════════════════════════════════════════════════════════
// 搜索引擎 — Minimax + Alpha-Beta 剪枝 + 正确的翻牌期望值计算
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class SearchEngine {
  /// 搜索所有移动走法及评分（只考虑明棋移动），按评分降序
  static List<(GameAction, double)> searchMoves(
    SearchBoard board,
    int boardSize,
  ) {
    final moves = board.generateMoves(true, includeFlips: false);
    if (moves.isEmpty) return [];

    final scored = [
      for (final action in moves)
        (
          action,
          _execAndEval(
            board,
            action,
            () => _minimax(
              board,
              EvalParams.searchDepth - 1,
              -double.infinity,
              double.infinity,
              false,
            ),
          ),
        ),
    ];

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored;
  }

  // 完整枚举目标位置可能翻出的动物及归属概率
  static (FlipAction, double)? evaluateFlips(
    SearchBoard board,
    List<int> hidden,
  ) {
    if (hidden.isEmpty) return null;
    double bestScore = -double.infinity;
    int bestPos = hidden.first;

    for (final pos in hidden) {
      final score = _evalFlip(board, pos, EvalParams.flipDepth);
      if (score > bestScore) {
        bestScore = score;
        bestPos = pos;
      }
    }
    return (FlipAction(bestPos), bestScore);
  }

  static double _evalFlip(SearchBoard board, int targetPos, int depth) {
    final selfCount = board.selfHidden.length;
    final enemyCount = board.enemyHidden.length;
    final total = selfCount + enemyCount;
    if (total == 0) return Evaluator.evaluate(board);

    double totalScore = 0;
    for (final animal in AnimalType.values) {
      final sCnt = board.selfHidden.where((t) => t == animal).length;
      final eCnt = board.enemyHidden.where((t) => t == animal).length;
      final pAnimal = (sCnt + eCnt) / total;
      if (pAnimal == 0) continue;

      if (sCnt > 0) {
        final pSelf = sCnt / (sCnt + eCnt);
        final score = board.withFlip(
          FlipAction(targetPos),
          () =>
              _minimax(board, depth, -double.infinity, double.infinity, false),
          forceSelf: true,
          forceAnimal: animal,
        );
        totalScore += pAnimal * pSelf * score;
      }
      if (eCnt > 0) {
        final pEnemy = eCnt / (sCnt + eCnt);
        final score = board.withFlip(
          FlipAction(targetPos),
          () =>
              _minimax(board, depth, -double.infinity, double.infinity, false),
          forceSelf: false,
          forceAnimal: animal,
        );
        totalScore += pAnimal * pEnemy * score;
      }
    }
    return totalScore;
  }

  static double _minimax(
    SearchBoard board,
    int depth,
    double alpha,
    double beta,
    bool isMax,
  ) {
    if (depth == 0) return Evaluator.evaluate(board);
    final moves = board.generateMoves(isMax, includeFlips: false);
    if (moves.isEmpty) return Evaluator.evaluate(board);

    double value = isMax ? -double.infinity : double.infinity;
    for (final action in moves) {
      final score = _execAndEval(
        board,
        action,
        () => _minimax(board, depth - 1, alpha, beta, !isMax),
      );
      if (isMax) {
        value = max(value, score);
        alpha = max(alpha, value);
      } else {
        value = min(value, score);
        beta = min(beta, value);
      }
      if (beta <= alpha) break;
    }
    return value;
  }

  static double _execAndEval(
    SearchBoard board,
    GameAction action,
    double Function() fn,
  ) {
    return switch (action) {
      FlipAction _ => throw StateError('Should not flip in minimax search'),
      MoveAction m => board.withMove(m, fn),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 日志工具
// ═══════════════════════════════════════════════════════════════════════════════
abstract final class _AiLog {
  static bool enabled = true;
  static const _abbr = ['E', 'T', 'L', 'P', 'W', 'D', 'C', 'M'];

  static void d(String msg) {
    if (enabled) debugPrint('[AI] $msg');
  }

  static String pos(int index, int size) =>
      '(${index ~/ size},${index % size})';

  static String action(GameAction action, int size) => switch (action) {
    FlipAction f => 'Flip${pos(f.index, size)}',
    MoveAction m => '${pos(m.from, size)}→${pos(m.to, size)}',
  };

  /// 紧凑棋盘：地形.动物（己方大写 / 敌方小写 / 暗棋 ? / 空 .）
  static String board(BoardState state, TurnGamerType aiFaction) {
    const tChar = ['L', 'R', 'O', 'B', 'T'];
    final sb = StringBuffer('    ');
    for (int c = 0; c < state.size; c++) {
      sb.write('${c % 10}  ');
    }
    sb.writeln();
    for (int r = 0; r < state.size; r++) {
      sb.write('${r % 10}   ');
      for (int c = 0; c < state.size; c++) {
        final cell = state.situation[r * state.size + c];
        final t = tChar[cell & 0x07];
        final occupy = CellCodec.occupy(cell);
        if (occupy == CellCodec.empty) {
          sb.write('$t. ');
        } else if (occupy == CellCodec.hidden) {
          sb.write('$t? ');
        } else {
          final a = _abbr[CellCodec.animal(cell).index];
          sb.write('$t${occupy == CellCodec.self ? a : a.toLowerCase()} ');
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AI 控制器
// ═══════════════════════════════════════════════════════════════════════════════

class AiController {
  static final _random = Random();
  final ZobristHash _zobrist = ZobristHash.instance;

  final UnmodifiableListView<CellView> board; // 保证只读
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
    final action = _handleActionStrategy();
    if (action != null) {
      _zobrist.store(aiSnapshot.boardInfo, action, true);
      _updateSnapshot(action);
    }
    return action;
  }

  /// 玩家行动后更新快照并存表
  void applyPlayerAction(GameAction action) {
    _AiLog.d('Player: ${_AiLog.action(action, boardSize)}');
    _zobrist.store(playerSnapshot.boardInfo, action, false);
    _updateSnapshot(action);
  }

  void dispose() {}

  GameAction? _handleActionStrategy() {
    // 无明棋 → 随机翻牌
    if (aiSnapshot.selfPos.isEmpty && aiSnapshot.enemyPos.isEmpty) {
      final flip = _randomFlip(aiSnapshot);
      if (flip != null) {
        _logDecision(flip, reason: 'random flip (no visible)');
        return flip;
      }
    }

    // Zobrist 缓存命中
    final cached = _zobrist.lookup(aiSnapshot.boardInfo);
    if (cached != null) {
      final hash = _zobrist.computeHash(aiSnapshot.boardInfo);
      // 统一对 MoveAction 和 FlipAction 做重复检测
      if (_zobrist.detectRepetition(hash, cached)) {
        // skip
      } else {
        _logDecision(cached, reason: 'Zobrist cache hit');
        return cached;
      }
    }

    // 搜索移动
    final searchBoard = SearchBoard.fromSnapshot(aiSnapshot);
    final eval = Evaluator.evaluateDetail(searchBoard);
    final scoredMoves = SearchEngine.searchMoves(searchBoard, boardSize);

    // 过滤重复行动，取最佳移动
    final hash = _zobrist.computeHash(aiSnapshot.boardInfo);
    GameAction? bestMove;
    double moveScore = -double.infinity;
    int skipped = 0;

    for (final (action, score) in scoredMoves) {
      if (_zobrist.detectRepetition(hash, action)) {
        skipped++;
        continue;
      }
      bestMove = action;
      moveScore = score;
      break;
    }

    // 搜索翻牌
    final hidden = aiSnapshot.hiddenPositions;
    final flipResult = SearchEngine.evaluateFlips(searchBoard, hidden);

    _logSearch(
      eval: eval,
      candidates: scoredMoves.take(5).toList(),
      bestMove: bestMove,
      moveScore: moveScore,
      flipResult: flipResult,
      hiddenCount: hidden.length,
      skipped: skipped,
    );

    // 直接比较翻牌与移动的实际评估值
    if (flipResult != null) {
      final (bestFlip, flipScore) = flipResult;
      if (bestMove == null || flipScore > moveScore) {
        _logDecision(bestFlip, reason: 'flip beats move');
        return bestFlip;
      }
    }

    if (bestMove != null) {
      _logDecision(bestMove, reason: 'best move');
      return bestMove;
    }

    _AiLog.d('No action available');
    return null;
  }

  FlipAction? _randomFlip(BoardSnapshot snap) {
    final h = snap.hiddenPositions;
    return h.isEmpty ? null : FlipAction(h[_random.nextInt(h.length)]);
  }

  void _updateSnapshot(GameAction action) {
    switch (action) {
      case FlipAction f:
        final animal = board[f.index].animal!;
        final isSelf = animal.owner == faction;
        aiSnapshot.applyFlip(f.index, animal.type, isSelf);
        playerSnapshot.applyFlip(f.index, animal.type, !isSelf);
      case MoveAction m:
        aiSnapshot.applyMove(m.from, m.to);
        playerSnapshot.applyMove(m.from, m.to);
    }
  }

  // ──── 日志 ────

  /// 输出完整决策追踪：棋盘 → 评估 → 候选 → 决策
  void _logSearch({
    required EvalResult eval,
    required List<(GameAction, double)> candidates,
    required GameAction? bestMove,
    required double moveScore,
    required (FlipAction, double)? flipResult,
    required int hiddenCount,
    required int skipped,
  }) {
    if (!_AiLog.enabled) return;
    final sb = StringBuffer();
    sb.writeln('Board:\n${_AiLog.board(aiSnapshot, faction)}');
    sb.writeln('Eval: $eval');
    for (int i = 0; i < candidates.length; i++) {
      final (action, score) = candidates[i];
      final tag = action == bestMove ? ' ←' : '';
      final skip =
          (action is MoveAction &&
              _zobrist.detectRepetition(aiSnapshot.boardInfo.hash!, action))
          ? ' [repeat]'
          : '';
      sb.writeln(
        ' ${i + 1}. ${_AiLog.action(action, boardSize).padRight(12)} '
        '${score.toStringAsFixed(1)}$skip$tag',
      );
    }
    if (skipped > 0) sb.writeln(' ($skipped repeats skipped)');
    if (flipResult != null) {
      final (flip, score) = flipResult;
      sb.writeln(
        ' Flip: ${_AiLog.action(flip, boardSize)} '
        '${score.toStringAsFixed(1)} ($hiddenCount hidden)',
      );
    }
    _AiLog.d(sb.toString().trimRight());
  }

  void _logDecision(GameAction action, {required String reason}) {
    _AiLog.d('Decision: ${_AiLog.action(action, boardSize)} ($reason)');
  }
}
