import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/widget/component/game_replay_board.dart';
import 'foundation_widget.dart';
import 'local_manager.dart';

class LocalAnimalChessPage extends StatefulWidget {
  const LocalAnimalChessPage({super.key});

  @override
  State<LocalAnimalChessPage> createState() => _LocalAnimalChessPageState();
}

class _LocalAnimalChessPageState extends State<LocalAnimalChessPage> {
  final LocalManager _manager = LocalManager();

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildPage();

  Widget _buildPage() => Scaffold(appBar: _buildAppBar(), body: _buildBody());

  AppBar _buildAppBar() => AppBar(
    title: Text(S.animalChess),
    centerTitle: true,
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'surrender':
              _manager.handleSurrender();
            case 'restart':
              _manager.initGame();
            case 'set':
              _manager.showBoardSizeSelector();
            case 'ai':
              _manager.toggleAiSwitch();
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
            value: 'set',
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: Text(S.settings),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'ai',
            child: ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('AI'),
              dense: true,
              trailing: Builder(
                builder: (ctx) => Switch(
                  value: _manager.aiEnabled,
                  onChanged: (v) {
                    _manager.toggleAiSwitch();
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildBody() => Column(
    children: [
      NotifierNavigator(navigatorHandler: _manager.pageNavigator),
      _buildTurnIndicator(),
      Expanded(
        child: ValueListenableBuilder<TurnGamerType?>(
          valueListenable: _manager.winner,
          builder: (_, winner, _) => GameReplayBoard(
            finished: winner != null,
            onReplay: _manager.initGame,
            child: FoundationalWidget(
              displayMap: _manager.displayMap,
              onCellClick: _manager.onCellClick,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildTurnIndicator() => ValueListenableBuilder<TurnGamerType?>(
    valueListenable: _manager.winner,
    builder: (_, winner, _) => ValueListenableBuilder(
      valueListenable: _manager.currentGamer,
      builder: (_, gamer, __) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: gamer == TurnGamerType.front ? Colors.red : Colors.blue,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          winner == null
              ? gamer == TurnGamerType.front
                    ? S.redTurn()
                    : S.blueTurn()
              : winner == TurnGamerType.front
              ? S.redWin()
              : S.blueWin(),
          style: globalTheme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
