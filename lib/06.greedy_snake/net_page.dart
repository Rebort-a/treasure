import '../00.common/network/middle/game_session.dart';
import '../00.common/widget/navigator/online_game_page.dart';

import 'package:flutter/material.dart';

import '../00.common/game/step.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'net_manager.dart';
import 'foundation_widget.dart';

class NetGreedySnakePage extends OnlineGamePage<NetManager> {
  const NetGreedySnakePage({super.key, required super.room});

  @override
  String get gameName => 'greedySnake';

  @override
  NetManager createManager() => NetManager(room: room);

  @override
  GameSession sessionOf(NetManager manager) => manager.realSession;

  @override
  Widget buildGame(
    BuildContext context,
    NetManager manager,
    VoidCallback requestExit,
  ) => _SnakeGame(manager: manager);

  @override
  void disposeManager(NetManager manager) => manager.dispose();
}

class _SnakeGame extends StatelessWidget {
  final NetManager _manager;

  const _SnakeGame({required NetManager manager}) : _manager = manager;

  @override
  Widget build(BuildContext context) => _buildPage();

  Widget _buildPage() {
    return ValueListenableBuilder<GameStep>(
      valueListenable: _manager.realSession.gameStep,
      builder: (_, step, __) {
        return step == GameStep.action
            ? GameScreen(manager: _manager, showStateButton: false)
            : _buildPrepare(step);
      },
    );
  }

  Widget _buildPrepare(GameStep step) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _manager.leavePage,
        ),
        title: Text(S.wait),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NotifierNavigator(navigatorHandler: _manager.pageNavigator),
            if (step != GameStep.gameOver) const SizedBox(height: 20),
            if (step != GameStep.gameOver) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(S.gameStepExplanation(step)),
          ],
        ),
      ),
    );
  }
}
