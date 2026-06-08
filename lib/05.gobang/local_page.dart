import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/l10n/strings.dart';
import 'ai_manager.dart';
import 'local_manager.dart';
import 'foundation_manager.dart';
import 'foundation_widget.dart';

class LocalGomokuPage extends StatefulWidget {
  const LocalGomokuPage({super.key});

  @override
  State<LocalGomokuPage> createState() => _LocalGomokuPageState();
}

class _LocalGomokuPageState extends State<LocalGomokuPage> {
  bool _vsAi = false;
  late FoundationalManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = LocalManager();
  }

  void _toggleAi(bool value) {
    setState(() {
      _vsAi = value;
      _manager = value ? AiManager() : LocalManager();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.gobang),
        centerTitle: true,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AI', style: TextStyle(fontSize: 13)),
              Switch(value: _vsAi, onChanged: _toggleAi),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {
              _manager = _vsAi ? AiManager() : LocalManager();
            }),
          ),
          IconButton(icon: const Icon(Icons.undo), onPressed: _manager.undo),
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          Expanded(child: FoundationalWidget(manager: _manager)),
        ],
      ),
    );
  }
}
