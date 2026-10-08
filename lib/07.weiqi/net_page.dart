import 'package:flutter/material.dart';

import '../00.common/network/client/socket_client.dart';
import '../00.common/widget/navigator/online_game_host.dart';
import '../00.common/game/step.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'foundation_widget.dart';
import 'net_manager.dart';

class GoNetPage extends StatelessWidget {
  final SocketClient room;

  const GoNetPage({super.key, required this.room});

  @override
  Widget build(BuildContext context) => OnlineGameHost<GoNetManager>(
    createManager: () => GoNetManager(room: room),
    engineOf: (manager) => manager.turnEngine,
    disposeManager: (manager) => manager.dispose(),
    pageBuilder: (_, manager, requestExit) =>
        _GoGame(manager: manager, onExit: requestExit),
  );
}

class _GoGame extends StatelessWidget {
  final GoNetManager _manager;
  final VoidCallback _onExit;

  const _GoGame({required GoNetManager manager, required VoidCallback onExit})
    : _manager = manager,
      _onExit = onExit;

  @override
  Widget build(BuildContext context) => _buildPage(context);

  Widget _buildPage(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(S.weiqi),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _onExit,
      ),
      actions: [IconButton(icon: const Icon(Icons.flag), onPressed: _onExit)],
    );
  }

  Widget _buildBody() {
    return ValueListenableBuilder<GameStep>(
      valueListenable: _manager.turnEngine.gameStep,
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
                        child: GoFoundationWidget(manager: _manager),
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
                              S.gameStepExplanation(step),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ]),
              Expanded(
                flex: 2,
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
      },
    );
  }

  Widget _buildTurnIndicator() => ValueListenableBuilder<StoneState>(
    valueListenable: _manager.board.currentPlayer,
    builder: (_, player, __) {
      String text = '';
      if (_manager.board.gameOver) {
        text = S.sideWin(
          player == StoneState.white ? S.blackSide : S.whiteSide,
        );
      } else {
        final side = player == StoneState.black ? S.blackSide : S.whiteSide;
        text = player == _manager.localPlayer
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
