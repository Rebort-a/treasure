import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_widget.dart';
import 'intelligence.dart';
import 'local_manager.dart';

class GoLocalPage extends StatefulWidget {
  const GoLocalPage({super.key});

  @override
  State<GoLocalPage> createState() => _GoLocalPageState();
}

class _GoLocalPageState extends State<GoLocalPage> {
  late final GoLocalManager _manager;
  bool _vsAi = false;

  @override
  void initState() {
    super.initState();
    _manager = GoLocalManager();
  }

  void _toggleAi(bool value) {
    setState(() {
      _vsAi = value;
      _manager.toggleAi(value);
    });
  }

  void _setDifficulty(GoAiDifficulty d) {
    setState(() => _manager.setDifficulty(d));
  }

  void _onGridSelected(int index) => _manager.placePiece(index);

  @override
  void dispose() {
    _manager.dispose();
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
                  final oldFaction = _manager.aiFaction;
                  final winnerIsAi = _vsAi &&
                      oldFaction != null &&
                      _manager.board.lastWinner == oldFaction;
                  final newFaction =
                      winnerIsAi ? StoneState.black : StoneState.white;
                  setState(() {
                    if (_vsAi) _manager.toggleAi(false);
                    _manager.restart();
                    if (_vsAi) _manager.toggleAi(true, faction: newFaction);
                  });
                case 'undo':
                  _manager.undo();
                case 'ai':
                  _toggleAi(!_vsAi);
                case 'easy':
                  _setDifficulty(GoAiDifficulty.easy);
                case 'normal':
                  _setDifficulty(GoAiDifficulty.normal);
                case 'hard':
                  _setDifficulty(GoAiDifficulty.hard);
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
                  title: Text(S.undo),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'ai',
                child: ListTile(
                  leading: const Icon(Icons.smart_toy),
                  title: Text(S.aiLabel),
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
              if (_vsAi) ...[
                const PopupMenuDivider(),
                _difficultyItem(S.easy, 'easy', GoAiDifficulty.easy),
                _difficultyItem(S.medium, 'normal', GoAiDifficulty.normal),
                _difficultyItem(S.hard, 'hard', GoAiDifficulty.hard),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<StoneState>(
            valueListenable: _manager.board.currentPlayer,
            builder: (context, player, _) {
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

  PopupMenuItem<String> _difficultyItem(
    String label,
    String value,
    GoAiDifficulty d,
  ) {
    final selected = _manager.difficulty == d;
    return PopupMenuItem<String>(
      value: value,
      child: ListTile(
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(label),
        dense: true,
      ),
    );
  }
}
