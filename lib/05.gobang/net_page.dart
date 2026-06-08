import 'package:flutter/material.dart';

import '../00.common/network/network_room.dart';
import '../00.common/game/gamer.dart';
import '../00.common/game/step.dart';
import '../00.common/widget/net_prepare_widget.dart';
import '../00.common/widget/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'foundation_widget.dart';
import 'net_manager.dart';

class NetGomokuPage extends StatelessWidget {
  late final NetManager _manager;

  NetGomokuPage({
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
                      Expanded(child: FoundationalWidget(manager: _manager)),
                    ]
                  : [Expanded(child: NetPrepareWidget(step: step))]),
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
          gamer == TurnGamerType.rear ? S.blackSide : S.whiteSide,
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
