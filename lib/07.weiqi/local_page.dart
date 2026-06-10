import 'dart:math';
import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_manager.dart';
import 'foundation_widget.dart';
import 'local_manager.dart';

class GoLocalPage extends StatefulWidget {
  const GoLocalPage({super.key});

  @override
  State<GoLocalPage> createState() => _GoLocalPageState();
}

class _GoLocalPageState extends State<GoLocalPage> {
  late final GoFoundationalManager _manager;
  _GoAi? _ai;
  bool _vsAi = false;

  @override
  void initState() {
    super.initState();
    _manager = GoLocalManager();
  }

  void _toggleAi(bool value) {
    setState(() {
      _vsAi = value;
      if (value) {
        _ai = _GoAi(manager: _manager);
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
        title: Text(S.weiqi),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'surrender':
                  _manager.resign();
                case 'restart':
                  final winnerIsAi =
                      _vsAi && _manager.board.lastWinner == _ai?.faction;
                  _ai?.dispose();
                  _ai = null;
                  setState(() {
                    _manager.restart();
                    if (_vsAi) {
                      _ai = _GoAi(
                        manager: _manager,
                        faction: winnerIsAi
                            ? StoneState.black
                            : StoneState.white,
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
                value: 'undo',
                child: ListTile(
                  leading: const Icon(Icons.undo),
                  title: const Text('Undo'),
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
      ),
      body: Column(
        children: [
          ValueListenableBuilder<StoneState>(
            valueListenable: _manager.board.currentPlayer,
            builder: (context, player, child) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _manager.board.gameOver
                      ? S.sideWin(
                          player == StoneState.white
                              ? S.blackSide
                              : S.whiteSide,
                        )
                      : S.currentTurn(
                          player == StoneState.black
                              ? S.blackSide
                              : S.whiteSide,
                        ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: GoFoundationWidget(
              manager: _manager,
              onGridSelected: _onGridSelected,
            ),
          ),
        ],
      ),
    );
  }
}

/// 围棋 AI 控制器
class _GoAi {
  final GoFoundationalManager manager;
  late final StoneState faction;
  bool _thinking = false;

  _GoAi({required this.manager, StoneState? faction}) {
    this.faction = faction ?? manager.board.currentPlayer.value;
    manager.board.currentPlayer.addListener(_onTurnChanged);
  }

  void dispose() {
    manager.board.currentPlayer.removeListener(_onTurnChanged);
  }

  void _onTurnChanged() => startIfMyTurn();

  void startIfMyTurn() {
    if (manager.board.currentPlayer.value == faction &&
        !_thinking &&
        !manager.board.gameOver) {
      _doAiMove();
    }
  }

  void humanSelect(int index) {
    if (manager.board.currentPlayer.value == faction) return;
    manager.placePiece(index);
  }

  void _doAiMove() {
    _thinking = true;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (manager.board.gameOver ||
          manager.board.currentPlayer.value != faction) {
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
    final random = Random();

    // 候选位置：已有棋子周围 2 格内的空位
    final candidates = <int>{};
    for (int i = 0; i < size * size; i++) {
      if (!grids[i].value.isEmpty()) {
        final row = i ~/ size;
        final col = i % size;
        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            final nr = row + dr;
            final nc = col + dc;
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final ni = nr * size + nc;
              if (grids[ni].value.isEmpty()) candidates.add(ni);
            }
          }
        }
      }
    }

    if (candidates.isEmpty) {
      final center = size ~/ 2;
      return center * size + center;
    }

    int? bestMove;
    int bestScore = -999999;

    for (final i in candidates) {
      int score = _evaluatePosition(i, size);
      score += random.nextInt(5);
      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }
    return bestMove;
  }

  int _evaluatePosition(int index, int size) {
    int score = 0;
    final row = index ~/ size;
    final col = index % size;
    final grids = manager.board.grids.value;
    final humanPiece = faction == StoneState.black
        ? StoneState.white
        : StoneState.black;

    final center = size ~/ 2;
    score += max(0, (center - (row - center).abs() - (col - center).abs())) * 2;

    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (final (dr, dc) in directions) {
      score += _evaluateDirection(
        row,
        col,
        dr,
        dc,
        faction,
        humanPiece,
        size,
        grids,
      );
    }
    return score;
  }

  int _evaluateDirection(
    int row,
    int col,
    int dr,
    int dc,
    StoneState aiPiece,
    StoneState humanPiece,
    int size,
    List<dynamic> grids,
  ) {
    int aiCount = 0, humanCount = 0;
    int aiOpen = 0, humanOpen = 0;

    int r = row + dr, c = col + dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = grids[r * size + c].value.state;
      if (state == aiPiece) {
        aiCount++;
      } else if (state == humanPiece) {
        humanCount++;
        break;
      } else {
        aiOpen++;
        break;
      }
      r += dr;
      c += dc;
    }

    r = row - dr;
    c = col - dc;
    while (r >= 0 && r < size && c >= 0 && c < size) {
      final state = grids[r * size + c].value.state;
      if (state == aiPiece) {
        aiCount++;
      } else if (state == humanPiece) {
        humanCount++;
        break;
      } else {
        aiOpen++;
        break;
      }
      r -= dr;
      c -= dc;
    }

    return _scorePattern(aiCount, aiOpen) +
        (_scorePattern(humanCount, humanOpen) * 1.2).toInt();
  }

  int _scorePattern(int count, int openEnds) {
    if (count == 0) return 0;
    if (count >= 4 && openEnds > 0) return 100000;
    if (count == 3 && openEnds >= 2) return 10000;
    if (count == 3 && openEnds == 1) return 1000;
    if (count == 2 && openEnds >= 2) return 500;
    if (count == 2 && openEnds == 1) return 100;
    if (count == 1 && openEnds >= 2) return 50;
    if (count == 1 && openEnds == 1) return 10;
    return 0;
  }
}
