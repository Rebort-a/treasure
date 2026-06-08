import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import 'ai_manager.dart';
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
  bool _vsAi = false;
  late GoFoundationalManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = GoLocalManager();
  }

  void _toggleAi(bool value) {
    setState(() {
      _vsAi = value;
      _manager = value ? GoAiManager() : GoLocalManager();
    });
  }

  void _restart() {
    setState(() {
      _manager = _vsAi ? GoAiManager() : GoLocalManager();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.weiqi),
        centerTitle: true,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AI', style: TextStyle(fontSize: 13)),
              Switch(value: _vsAi, onChanged: _toggleAi),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _restart),
          IconButton(icon: const Icon(Icons.undo), onPressed: _manager.undo),
          IconButton(icon: const Icon(Icons.flag), onPressed: _manager.resign),
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
          Expanded(child: GoFoundationWidget(manager: _manager)),
        ],
      ),
    );
  }
}
