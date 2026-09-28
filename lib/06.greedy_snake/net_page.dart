import 'package:flutter/material.dart';

import '../00.common/game/step.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'net_manager.dart';
import 'foundation_widget.dart';

class NetGreedySnakePage extends StatelessWidget {
  final NetManager manager;

  const NetGreedySnakePage({super.key, required this.manager});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) manager.leavePage();
    },
    child: _buildPage(),
  );

  Widget _buildPage() {
    return ValueListenableBuilder<GameStep>(
      valueListenable: manager.engine.gameStep,
      builder: (_, step, __) {
        return step == GameStep.action
            ? GameScreen(manager: manager, showStateButton: false)
            : _buildPrepare(step);
      },
    );
  }

  Widget _buildPrepare(GameStep step) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: manager.leavePage,
        ),
        title: Text(S.wait),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NotifierNavigator(navigatorHandler: manager.pageNavigator),
            if (step != GameStep.gameOver) const SizedBox(height: 20),
            if (step != GameStep.gameOver) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(step.getExplanation()),
          ],
        ),
      ),
    );
  }
}
