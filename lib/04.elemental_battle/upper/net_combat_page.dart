import 'package:flutter/material.dart';

import '../middle/foundation_combat_widget.dart';

import '../../00.common/game/step.dart';
import '../../00.common/widget/component/chat_component.dart';
import '../../00.common/widget/navigator/notifier_navigator.dart';
import '../../00.common/l10n/strings.dart';
import 'net_combat_manager.dart';

class NetCombatPage extends StatelessWidget {
  final NetCombatManager _manager;

  const NetCombatPage({super.key, required NetCombatManager manager})
    : _manager = manager;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _manager.leavePage();
    },
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    return ValueListenableBuilder<GameStep>(
      valueListenable: _manager.netTurnEngine.gameStep,
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

          Expanded(child: MessageList(networkEngine: _manager.netTurnEngine)),
          MessageInput(networkEngine: _manager.netTurnEngine),
        ],
      ),
    );
  }

  Widget _buildPrepare(GameStep step) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _manager.leavePage,
          icon: Icon(Icons.arrow_back),
        ),
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
            Text(step.getExplanation()),
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
