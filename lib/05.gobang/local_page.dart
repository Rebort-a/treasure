import 'dart:math';
import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';
import 'foundation_widget.dart';
import 'local_manager.dart';

class LocalGomokuPage extends StatefulWidget {
  const LocalGomokuPage({super.key});

  @override
  State<LocalGomokuPage> createState() => _LocalGomokuPageState();
}

class _LocalGomokuPageState extends State<LocalGomokuPage> {
  late final FoundationalManager _manager;
  _GomokuAi? _ai;
  bool _vsAi = false;

  @override
  void initState() {
    super.initState();
    _manager = LocalManager();
  }

  void _toggleAi(bool value) {
    setState(() {
      _vsAi = value;
      if (value) {
        _ai = _GomokuAi(manager: _manager);
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
      _manager.placePiece(index);
    }
  }

  @override
  void dispose() {
    _ai?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.gobang),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'restart':
                  final winnerIsAi = _vsAi && _manager.board.lastWinner == _ai?.aiSide;
                  _ai?.dispose();
                  _ai = null;
                  setState(() {
                    _manager.restart();
                    if (_vsAi) {
                      _ai = _GomokuAi(
                        manager: _manager,
                        aiSide: winnerIsAi ? TurnGamerType.front : TurnGamerType.rear,
                      );
                      if (winnerIsAi) _ai!.startIfMyTurn();
                    }
                  });
                case 'undo':
                  _manager.undo();
                case 'ai':
                  _toggleAi(!_vsAi);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'restart',
                child: ListTile(leading: const Icon(Icons.refresh), title: Text(S.restart), dense: true),
              ),
              PopupMenuItem(
                value: 'undo',
                child: ListTile(leading: const Icon(Icons.undo), title: const Text('Undo'), dense: true),
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
      ),
      body: Column(
        children: [
          ValueListenableBuilder<TurnGamerType>(
            valueListenable: _manager.board.currentGamer,
            builder: (context, gamer, child) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _manager.board.gameOver == false
                      ? S.currentTurn(
                          gamer == TurnGamerType.front
                              ? S.blackSide
                              : S.whiteSide,
                        )
                      : S.sideWin(
                          gamer == TurnGamerType.rear
                              ? S.blackSide
                              : S.whiteSide,
                        ),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          Expanded(child: FoundationalWidget(manager: _manager, onGridSelected: _onGridSelected)),
        ],
      ),
    );
  }
}

/// 五子棋 AI 控制器
class _GomokuAi {
  final FoundationalManager manager;
  late final TurnGamerType aiSide;
  bool _thinking = false;

  _GomokuAi({required this.manager, TurnGamerType? aiSide}) {
    this.aiSide = aiSide ?? manager.board.currentGamer.value;
    manager.board.currentGamer.addListener(_onTurnChanged);
  }

  void dispose() {
    manager.board.currentGamer.removeListener(_onTurnChanged);
  }

  void _onTurnChanged() => startIfMyTurn();

  void startIfMyTurn() {
    if (manager.board.currentGamer.value == aiSide && !_thinking && !manager.board.gameOver) {
      _doAiMove();
    }
  }

  void humanSelect(int index) {
    if (manager.board.currentGamer.value == aiSide) return;
    manager.placePiece(index);
  }

  void _doAiMove() {
    _thinking = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (manager.board.gameOver || manager.board.currentGamer.value != aiSide) {
        _thinking = false;
        return;
      }
      final move = _calculateBestMove();
      if (move != null) manager.placePiece(move);
      _thinking = false;
    });
  }

  int? _calculateBestMove() {
    final board = manager.board;
    final size = board.size;
    final grids = board.grids.value;
    final aiPiece = aiSide == TurnGamerType.front ? PieceType.black : PieceType.white;
    final humanPiece = aiPiece == PieceType.black ? PieceType.white : PieceType.black;

    int? bestMove;
    int bestScore = -1;

    for (int i = 0; i < size * size; i++) {
      if (!grids[i].value.isEmpty()) continue;
      final score = _evaluatePosition(i, aiPiece, humanPiece, size);
      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }
    return bestMove;
  }

  int _evaluatePosition(int index, PieceType aiPiece, PieceType humanPiece, int size) {
    int score = 0;
    final row = index ~/ size;
    final col = index % size;
    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (final (dr, dc) in directions) {
      score += _evaluateDirection(row, col, dr, dc, aiPiece, humanPiece, size);
    }
    final center = size ~/ 2;
    score += max(0, center - (row - center).abs() - (col - center).abs());
    return score;
  }

  int _evaluateDirection(int row, int col, int dr, int dc, PieceType aiPiece, PieceType humanPiece, int size) {
    int aiCount = 0, humanCount = 0;
    int aiOpen = 0, humanOpen = 0;

    int r = row + dr, c = col + dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = manager.board.grids.value[r * size + c].value.type;
      if (state == aiPiece) { aiCount++; }
      else if (state == humanPiece) { humanCount++; break; }
      else { aiOpen++; break; }
      r += dr; c += dc;
    }

    r = row - dr; c = col - dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = manager.board.grids.value[r * size + c].value.type;
      if (state == aiPiece) { aiCount++; }
      else if (state == humanPiece) { humanCount++; break; }
      else { aiOpen++; break; }
      r -= dr; c -= dc;
    }

    return _scorePattern(aiCount, aiOpen, isAi: true) + _scorePattern(humanCount, humanOpen, isAi: false);
  }

  int _scorePattern(int count, int openEnds, {required bool isAi}) {
    if (count == 0 && openEnds == 0) return 0;
    if (count >= 4) return isAi ? 100000 : 90000;
    if (count == 3 && openEnds >= 2) return isAi ? 50000 : 40000;
    if (count == 3 && openEnds == 1) return isAi ? 5000 : 4000;
    if (count == 2 && openEnds >= 2) return isAi ? 3000 : 2500;
    if (count == 2 && openEnds == 1) return isAi ? 500 : 400;
    if (count == 1 && openEnds >= 2) return isAi ? 200 : 150;
    if (count == 1 && openEnds == 1) return isAi ? 50 : 30;
    if (openEnds >= 2) return isAi ? 10 : 5;
    return 0;
  }
}
