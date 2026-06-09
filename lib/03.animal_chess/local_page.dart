import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'intelligence.dart';
import 'foundation_manager.dart';
import 'foundation_widget.dart';
import 'local_manager.dart';

class LocalAnimalChessPage extends StatefulWidget {
  const LocalAnimalChessPage({super.key});

  @override
  State<LocalAnimalChessPage> createState() => _LocalAnimalChessPageState();
}

class _LocalAnimalChessPageState extends State<LocalAnimalChessPage> {
  late final FoundationalManager _manager;
  _AiController? _ai;
  bool _vsAi = false;

  @override
  void initState() {
    super.initState();
    _manager = LocalManager();
    _manager.onRestart = _doRestart;
  }

  void _doRestart() {
    final winnerIsAi = _vsAi && _manager.lastWinner == _ai?.aiSide;
    _ai?.dispose();
    _ai = null;
    _manager.pageNavigator.value = (_) {};
    setState(() {
      _manager.initGame();
      if (_vsAi) {
        _ai = _AiController(
          manager: _manager,
          aiSide: winnerIsAi ? TurnGamerType.front : TurnGamerType.rear,
        );
        if (winnerIsAi) _ai!.startIfMyTurn();
      }
    });
  }

  void _toggleAi(bool value) {
    setState(() {
      _vsAi = value;
      if (value) {
        _ai = _AiController(
          manager: _manager,
          aiSide: _manager.currentGamer.value,
        );
        _ai!.startIfMyTurn();
      } else {
        _ai?.dispose();
        _ai = null;
      }
    });
  }

  void _onGridSelected(int index) {
    if (_vsAi && _ai != null) {
      _ai!.humanSelect(index);
    } else {
      _manager.selectGrid(index);
    }
  }

  @override
  void dispose() {
    _ai?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _buildAppBar(),
    body: Column(
      children: [
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        _buildTurnIndicator(),
        Expanded(
          child: FoundationalWidget(
            displayMap: _manager.displayMap,
            onGridSelected: _onGridSelected,
          ),
        ),
      ],
    ),
  );

  AppBar _buildAppBar() => AppBar(
    title: Text(S.animalChess),
    centerTitle: true,
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'surrender':
              _manager.lastWinner = _manager.currentGamer.value.opponent;
              _manager.showChessResult(_manager.currentGamer.value == TurnGamerType.rear);
            case 'restart':
              _doRestart();
            case 'boardSize':
              _manager.showBoardSizeSelector();
            case 'ai':
              _toggleAi(!_vsAi);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'surrender',
            child: ListTile(
              leading: const Icon(Icons.flag),
              title: Text(S.surrender),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'restart',
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(S.restart),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'boardSize',
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: Text(S.setBoardSize),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'ai',
            child: ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('AI'),
              dense: true,
              trailing: Switch(
                value: _vsAi,
                onChanged: (v) {
                  Navigator.pop(context);
                  _toggleAi(v);
                },
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildTurnIndicator() => ValueListenableBuilder(
    valueListenable: _manager.currentGamer,
    builder: (_, gamer, __) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: gamer == TurnGamerType.front ? Colors.red : Colors.blue,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        gamer == TurnGamerType.front ? S.redTurn() : S.blueTurn(),
        style: globalTheme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
    ),
  );
}

/// AI 控制器：监听棋盘变化，轮到 AI 时自动走棋
class _AiController {
  final FoundationalManager manager;
  final TurnGamerType aiSide;
  bool _thinking = false;

  _AiController({required this.manager, required this.aiSide}) {
    manager.currentGamer.addListener(_onTurnChanged);
  }

  void dispose() {
    manager.currentGamer.removeListener(_onTurnChanged);
  }

  void _onTurnChanged() {
    startIfMyTurn();
  }

  void startIfMyTurn() {
    if (manager.currentGamer.value == aiSide && !_thinking) {
      _doAiMove();
    }
  }

  void humanSelect(int index) {
    if (manager.currentGamer.value == aiSide) {
      return;
    }
    manager.selectGrid(index);
  }

  void _doAiMove() {
    _thinking = true;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (manager.currentGamer.value != aiSide) {
        _thinking = false;
        return;
      }
      final move = _calculateBestMove();
      if (move != null) {
        _executeMove(move);
      }
      _thinking = false;
    });
  }

  void _executeMove(AiMove move) {
    switch (move) {
      case FlipMove(:final index):
        manager.selectGrid(index);
      case StepMove(:final from, :final to):
        manager.selectGrid(from);
        manager.selectGrid(to);
    }
  }

  AiMove? _calculateBestMove() {
    final snap = BoardSnapshot.from(manager, aiSide);
    final moves = snap.generateMoves(aiSide);
    if (moves.isEmpty) return null;

    // 2-Ply Minimax
    AiMove? bestMove;
    double bestScore = -double.infinity;

    for (final aiMove in moves) {
      final afterAi = snap.applyMove(aiMove, aiSide);
      if (afterAi.isGameOver) {
        final score = _evaluate(afterAi, aiSide);
        if (score > bestScore) {
          bestScore = score;
          bestMove = aiMove;
        }
        continue;
      }

      final opMoves = afterAi.generateMoves(aiSide.opponent);
      double worst = double.infinity;
      for (final opMove in opMoves) {
        final afterOp = afterAi.applyMove(opMove, aiSide);
        final score = _evaluate(afterOp, aiSide);
        if (score < worst) worst = score;
      }
      if (opMoves.isEmpty) worst = 10000;

      final combined = _evaluate(afterAi, aiSide) + worst * 0.6;
      if (combined > bestScore) {
        bestScore = combined;
        bestMove = aiMove;
      }
    }

    return bestMove ?? moves.first;
  }

  double _evaluate(BoardSnapshot snap, TurnGamerType aiSide) {
    if (snap.isGameOver) {
      final aiCount = aiSide == TurnGamerType.front
          ? snap.redCount
          : snap.blueCount;
      return aiCount > 0 ? 10000 : -10000;
    }

    double score = 0;
    final opSide = aiSide.opponent;

    // 材料分
    double material = 0;
    for (final a in snap.cells) {
      if (a == null) continue;
      final v = pieceValues[a.type]!.toDouble();
      material += a.owner == aiSide ? v : -v;
    }
    score += material * 0.4;

    // 机动性分
    score +=
        (snap.generateMoves(aiSide).length -
            snap.generateMoves(opSide).length) *
        0.1;

    // 威胁分
    score += _threatScore(snap, aiSide) * 0.25;

    // 地形分
    score += _terrainScore(snap, aiSide) * 0.15;

    return score;
  }

  double _threatScore(BoardSnapshot snap, TurnGamerType aiSide) {
    double score = 0;
    final aiPieces = snap.getRevealedIndices(aiSide);
    final opPieces = snap.getRevealedIndices(aiSide.opponent);

    for (final aiIdx in aiPieces) {
      final aiA = snap.cells[aiIdx]!;
      for (final opIdx in opPieces) {
        final opA = snap.cells[opIdx]!;
        final dist =
            (aiIdx ~/ snap.size - opIdx ~/ snap.size).abs() +
            (aiIdx % snap.size - opIdx % snap.size).abs();
        if (dist > 2) continue;
        if (opA.canEat(aiA)) score -= pieceValues[aiA.type]! / dist;
        if (aiA.canEat(opA)) score += pieceValues[opA.type]! / dist;
      }
    }
    return score;
  }

  double _terrainScore(BoardSnapshot snap, TurnGamerType aiSide) {
    double score = 0;
    for (int i = 0; i < snap.cells.length; i++) {
      final a = snap.cells[i];
      if (a == null || a.isHidden) continue;
      final sign = a.owner == aiSide ? 1.0 : -1.0;
      final gt = snap.gridTypes[i];
      if (gt == GridType.river && a.canMoveTo(GridType.land, GridType.river))
        score += sign * 1.5;
      if (gt == GridType.tree && a.canMoveTo(GridType.land, GridType.tree))
        score += sign * 1.0;
      if (gt == GridType.bridge) score += sign * 0.5;
    }
    return score;
  }
}
