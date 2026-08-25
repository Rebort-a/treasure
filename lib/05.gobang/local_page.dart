import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/l10n/strings.dart';
import 'foundation_widget.dart';
import 'intelligence.dart';
import 'local_manager.dart';

class LocalGomokuPage extends StatefulWidget {
  const LocalGomokuPage({super.key});

  @override
  State<LocalGomokuPage> createState() => _LocalGomokuPageState();
}

class _LocalGomokuPageState extends State<LocalGomokuPage> {
  late final LocalManager _manager;
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
        _manager.toggleAi(true);
      } else {
        _manager.toggleAi(false);
      }
    });
  }

  void _setDifficulty(AiDifficulty d) {
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
        title: Text(S.gobang),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'restart':
                  final oldFaction = _manager.aiFaction;
                  final winnerIsAi = _vsAi &&
                      oldFaction != null &&
                      _manager.board.lastWinner == oldFaction;
                  final newFaction = winnerIsAi
                      ? TurnGamerType.front
                      : TurnGamerType.rear;
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
                  _setDifficulty(AiDifficulty.easy);
                case 'normal':
                  _setDifficulty(AiDifficulty.normal);
                case 'hard':
                  _setDifficulty(AiDifficulty.hard);
              }
            },
            itemBuilder: (_) => [
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
                _difficultyItem(S.easy, 'easy', AiDifficulty.easy),
                _difficultyItem(S.medium, 'normal', AiDifficulty.normal),
                _difficultyItem(S.hard, 'hard', AiDifficulty.hard),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<TurnGamerType>(
            valueListenable: _manager.board.currentGamer,
            builder: (context, gamer, _) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _manager.board.gameOver
                      ? S.sideWin(
                          gamer == TurnGamerType.rear
                              ? S.blackSide
                              : S.whiteSide,
                        )
                      : S.currentTurn(
                          gamer == TurnGamerType.front
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
            child: FoundationalWidget(
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
    AiDifficulty d,
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
