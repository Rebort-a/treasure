import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/game/step.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/l10n/strings.dart';
import 'foundation_widget.dart';
import 'net_manager.dart';

class NetGomokuPage extends StatelessWidget {
  final NetManager _manager;

  const NetGomokuPage({super.key, required NetManager manager})
    : _manager = manager;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, Object? result) {
      if (!didPop) _manager.leavePage();
    },
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(S.netGobang),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _manager.netTurnEngine.leavePage,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.flag),
          tooltip: S.surrender,
          onPressed: _manager.resign,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return ValueListenableBuilder<GameStep>(
      valueListenable: _manager.netTurnEngine.gameStep,
      builder: (__, step, _) {
        return Center(
          child: Column(
            children: [
              NotifierNavigator(navigatorHandler: _manager.pageNavigator),
              ...(step == GameStep.action
                  ? [
                      _buildTurnIndicator(),
                      Expanded(
                        flex: 3,
                        child: FoundationalWidget(manager: _manager),
                      ),
                    ]
                  : [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            Text(
                              step.getExplanation(),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ]),
              Expanded(
                flex: 2,
                child: MessageList(networkEngine: _manager.netTurnEngine),
              ),
              MessageInput(networkEngine: _manager.netTurnEngine),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTurnIndicator() => ValueListenableBuilder(
    valueListenable: _manager.board.currentGamer,
    builder: (_, gamer, __) {
      String text = '';
      if (_manager.board.gameOver) {
        text = S.sideWin(
          _manager.board.lastWinner == TurnGamerType.front
              ? S.blackSide
              : S.whiteSide,
        );
      } else {
        final side = gamer == TurnGamerType.front ? S.blackSide : S.whiteSide;
        text = gamer == _manager.netTurnEngine.playerType
            ? S.yourSideTurn(side)
            : S.opponentSideTurn(side);
      }
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      );
    },
  );
}
