import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';

import 'ai_manager.dart';
import 'foundation_manager.dart';
import 'local_manager.dart';
import 'foundation_widget.dart';

class LocalAnimalChessPage extends StatefulWidget {
  const LocalAnimalChessPage({super.key});

  @override
  State<LocalAnimalChessPage> createState() => _LocalAnimalChessPageState();
}

class _LocalAnimalChessPageState extends State<LocalAnimalChessPage> {
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

  void _restart() {
    setState(() {
      _manager = _vsAi ? AiManager() : LocalManager();
    });
  }

  @override
  Widget build(BuildContext context) => _buildPage();

  Widget _buildPage() => Scaffold(appBar: _buildAppBar(), body: _buildBody());

  AppBar _buildAppBar() => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.flag),
      onPressed: _manager.leavePage,
    ),
    title: Text(S.animalChess),
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
        onPressed: _restart,
      ),
      IconButton(
        icon: const Icon(Icons.tune),
        onPressed: _manager.showBoardSizeSelector,
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
          onGridSelected: _manager.selectGrid,
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
