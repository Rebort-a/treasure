import 'package:flutter/material.dart';

import '../00.common/network/client/socket_client.dart';
import '../00.common/network/widget/online_game_host.dart';
import '../00.common/network/widget/round_replay_board.dart';
import '../00.common/game/gamer.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/game/step.dart';

import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';

import 'net_manager.dart';
import 'foundation_widget.dart';

/// 唯一联机入口。只组合容器，具体 Manager 不作为模块对外接口。
class NetAnimalChessPage extends StatelessWidget {
  final SocketClient room;

  const NetAnimalChessPage({super.key, required this.room});

  @override
  Widget build(BuildContext context) => OnlineGameHost<NetManager>(
    createManager: () => NetManager(room: room),
    engineOf: (manager) => manager.turnEngine,
    disposeManager: (manager) => manager.dispose(),
    pageBuilder: (_, manager, requestExit) =>
        _AnimalChessGame(manager: manager, onExit: requestExit),
  );
}

class _AnimalChessGame extends StatelessWidget {
  final NetManager _manager;
  final VoidCallback _onExit;

  const _AnimalChessGame({
    required NetManager manager,
    required VoidCallback onExit,
  }) : _manager = manager,
       _onExit = onExit;

  @override
  Widget build(BuildContext context) => _buildPage(context);

  Widget _buildPage(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<GameStep>(
        valueListenable: _manager.turnEngine.gameStep,
        builder: (__, step, _) {
          return Scaffold(
            appBar: _buildAppBar(context, step),
            body: _buildBody(step),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, GameStep step) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _onExit,
      ),
      title: Text(S.netAnimalChess),
      centerTitle: true,
      actions: [
        if (step == GameStep.action)
          IconButton(
            tooltip: S.surrender,
            icon: const Icon(Icons.flag),
            onPressed: () =>
                confirmRoundSurrender(context, _manager.turnEngine),
          ),
      ],
    );
  }

  Widget _buildBody(GameStep step) {
    return Column(
      children: [
        // 弹出页面
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        ...(step == GameStep.action || step == GameStep.gameOver
            ? [
                _buildTurnIndicator(),
                Expanded(
                  flex: 3,
                  child: RoundReplayBoard(
                    engine: _manager.turnEngine,
                    child: FoundationalWidget(
                      displayMap: _manager.displayMap,
                      onCellClick: _manager.onCellClick,
                    ),
                  ),
                ),
              ]
            : _buildPrepare(step)),

        Expanded(
          flex: 1,
          child: MessageList(
            identity: _manager.turnEngine.identity,
            userName: _manager.turnEngine.userName,
            messageList: _manager.turnEngine.gameMessageList,
          ),
        ),
        MessageInput(onSendText: _manager.turnEngine.sendGameText),
      ],
    );
  }

  Widget _buildTurnIndicator() => ValueListenableBuilder(
    valueListenable: _manager.currentGamer,
    builder: (_, gamer, __) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: gamer == TurnGamerType.front ? Colors.red : Colors.blue,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        gamer == _manager.turnEngine.playerType
            ? S.yourTurn()
            : S.opponentTurn(),
        style: globalTheme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
    ),
  );

  List<Widget> _buildPrepare(GameStep step) {
    return [
      const SizedBox(height: 20),
      const CircularProgressIndicator(),
      const SizedBox(height: 20),
      Text(S.gameStepExplanation(step)),
    ];
  }
}
