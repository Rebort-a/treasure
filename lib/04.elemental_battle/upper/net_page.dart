import '../../00.common/network/client/game_session.dart';
import '../../00.common/widget/navigator/online_game_page.dart';

import 'package:flutter/material.dart';

import '../middle/foundation_combat_widget.dart';

import '../../00.common/game/step.dart';
import '../../00.common/widget/component/chat_component.dart';
import '../../00.common/widget/navigator/notifier_navigator.dart';
import '../../00.common/l10n/strings.dart';
import 'net_combat_manager.dart';

class NetCombatPage extends OnlineGamePage<NetCombatManager> {
  const NetCombatPage({super.key, required super.room});

  @override
  String get gameName => 'elementalBattle';

  @override
  NetCombatManager createManager() => NetCombatManager(room: room);

  @override
  GameSession sessionOf(NetCombatManager manager) => manager.turnSession;

  @override
  Widget buildGame(
    BuildContext context,
    NetCombatManager manager,
    VoidCallback requestExit,
  ) => _CombatGame(manager: manager, onExit: requestExit);

  @override
  void disposeManager(NetCombatManager manager) => manager.dispose();
}

class _CombatGame extends StatelessWidget {
  final NetCombatManager _manager;
  final VoidCallback _onExit;

  const _CombatGame({
    required NetCombatManager manager,
    required VoidCallback onExit,
  }) : _manager = manager,
       _onExit = onExit;

  @override
  Widget build(BuildContext context) => _buildPage(context);

  Widget _buildPage(BuildContext context) {
    return ValueListenableBuilder<GameStep>(
      valueListenable: _manager.turnSession.gameStep,
      builder: (__, step, _) {
        if (step.index == GameStep.action.index) {
          return _buildGame(step);
        } else {
          return _buildPrepare(step);
        }
      },
    );
  }

  Widget _buildGame(GameStep step) {
    return Scaffold(
      body: Column(
        children: [
          // 弹出页面
          NotifierNavigator(navigatorHandler: _manager.pageNavigator),

          ...FoundationalCombatWidget(combatManager: _manager).buildPage(),

          Expanded(child: MessageList(channel: _manager.turnSession)),
          MessageInput(channel: _manager.turnSession),
        ],
      ),
    );
  }

  Widget _buildPrepare(GameStep step) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: _onExit, icon: Icon(Icons.arrow_back)),
        title: Text(S.preparing),
        centerTitle: true,
      ),

      body: Center(
        child: Column(
          children: [
            NotifierNavigator(navigatorHandler: _manager.pageNavigator),
            const SizedBox(height: 20),
            if (step == GameStep.start) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(S.gameStepExplanation(step)),
            const SizedBox(height: 20),
            if (step == GameStep.frontConfig || step == GameStep.rearConfig)
              ElevatedButton(
                onPressed: () => _manager.navigateToCastPage(),
                child: Text(S.configCharacter),
              ),
            const SizedBox(height: 20),
            if (step == GameStep.rearConfig)
              ElevatedButton(
                onPressed: () => _manager.navigateToStatePage(),
                child: Text(S.viewOpponent),
              ),
          ],
        ),
      ),
    );
  }
}
