import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'base.dart';
import 'local_manager.dart';
import 'foundation_widget.dart';

class GoLocalPage extends StatefulWidget {
  const GoLocalPage({super.key});

  @override
  State<GoLocalPage> createState() => _GoLocalPageState();
}

class _GoLocalPageState extends State<GoLocalPage> {
  late final GoLocalManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = GoLocalManager();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.weiqi),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _manager.restart,
          ),
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
                      ? S.sideWin(player == StoneState.white ? S.blackSide : S.whiteSide)
                      : S.currentTurn(player == StoneState.black ? S.blackSide : S.whiteSide),
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
