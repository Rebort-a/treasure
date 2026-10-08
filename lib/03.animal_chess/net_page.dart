import 'package:flutter/material.dart';

import '../00.common/network/client/socket_client.dart';
import '../00.common/widget/navigator/online_game_host.dart';
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
          return Scaffold(appBar: _buildAppBar(step), body: _buildBody(step));
        },
      ),
    );
  }

  AppBar _buildAppBar(GameStep step) {
    // 根据游戏步骤确定图标和回调
    IconData icon;
    VoidCallback onPressed = _onExit;

    if (step.index < GameStep.action.index) {
      icon = Icons.arrow_back;
    } else if (step.index == GameStep.action.index) {
      icon = Icons.flag;
      onPressed = _onExit;
    } else {
      icon = Icons.exit_to_app;
    }

    return AppBar(
      leading: IconButton(icon: Icon(icon), onPressed: onPressed),
      title: Text(S.netAnimalChess),
      centerTitle: true,
    );
  }

  Widget _buildBody(GameStep step) {
    return Column(
      children: [
        // 弹出页面
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        ...(step == GameStep.action
            ? [
                _buildTurnIndicator(),
                Expanded(
                  flex: 3,
                  child: FoundationalWidget(
                    displayMap: _manager.displayMap,
                    onCellClick: _manager.onCellClick,
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
