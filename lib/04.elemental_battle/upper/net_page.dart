import 'package:flutter/material.dart';

import '../../00.common/network/client/socket_client.dart';
import '../../00.common/network/widget/online_game_host.dart';
import 'foundation_combat_widget.dart';

import '../../00.common/game/step.dart';
import '../../00.common/widget/component/chat_component.dart';
import '../../00.common/widget/navigator/notifier_navigator.dart';
import '../../00.common/l10n/strings.dart';
import 'net_combat_manager.dart';

class NetCombatPage extends StatelessWidget {
  final SocketClient room;

  const NetCombatPage({super.key, required this.room});

  @override
  Widget build(BuildContext context) => OnlineGameHost<NetCombatManager>(
    createManager: () => NetCombatManager(room: room),
    engineOf: (manager) => manager.turnEngine,
    disposeManager: (manager) => manager.dispose(),
    pageBuilder: (_, manager, requestExit) =>
        _CombatGame(manager: manager, onExit: requestExit),
  );
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
      valueListenable: _manager.turnEngine.gameStep,
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

          Expanded(
            child: MessageList(
              identity: _manager.turnEngine.identity,
              userName: _manager.turnEngine.userName,
              messageList: _manager.turnEngine.gameMessageList,
            ),
          ),
          MessageInput(onSendText: _manager.turnEngine.sendGameText),
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
