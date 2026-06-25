import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'foundation_widget.dart';
import 'local_manager.dart';

class LocalAnimalChessPage extends StatelessWidget {
  final LocalManager _manager = LocalManager();

  LocalAnimalChessPage({super.key});

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
        child: FoundationalWidget(
          displayMap: _manager.displayMap,
          onCellClick: _manager.onCellClick,
        ),
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
