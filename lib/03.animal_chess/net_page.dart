import 'package:flutter/material.dart';

import '../00.common/game/gamer.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/game/step.dart';
import '../00.common/network/network_room.dart';

import '../00.common/widget/notifier_navigator.dart';
import '../l10n/strings.dart';

import 'net_manager.dart';
import 'foundation_widget.dart';

class NetAnimalChessPage extends StatelessWidget {
  late final NetManager _manager;

  NetAnimalChessPage({
    super.key,
    required RoomInfo roomInfo,
    required String userName,
  }) {
    _manager = NetManager(roomInfo: roomInfo, userName: userName);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, Object? result) {
      _manager.leavePage();
    },
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<GameStep>(
        valueListenable: _manager.netTurnEngine.gameStep,
        builder: (__, step, _) {
          return Scaffold(appBar: _buildAppBar(step), body: _buildBody(step));
        },
      ),
    );
  }

  AppBar _buildAppBar(GameStep step) {
    // 根据游戏步骤确定图标
    IconData icon;

    if (step.index < GameStep.action.index) {
      icon = Icons.arrow_back;
    } else if (step.index == GameStep.action.index) {
      icon = Icons.flag;
    } else {
      icon = Icons.exit_to_app;
    }

    return AppBar(
      leading: IconButton(icon: Icon(icon), onPressed: _manager.leavePage),
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
                    onGridSelected: _manager.sendActionMessage,
                  ),
                ),
              ]
            : _buildPrepare(step)),

        Expanded(
          flex: 1,
          child: MessageList(networkEngine: _manager.netTurnEngine),
        ),
        MessageInput(networkEngine: _manager.netTurnEngine),
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
        gamer == _manager.netTurnEngine.playerType ? S.yourTurn() : S.opponentTurn(),
        style: globalTheme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
    ),
  );

  List<Widget> _buildPrepare(GameStep step) {
    return [
      const SizedBox(height: 20),
      const CircularProgressIndicator(),
      const SizedBox(height: 20),
      Text(step.getExplanation()),
    ];
  }
}
