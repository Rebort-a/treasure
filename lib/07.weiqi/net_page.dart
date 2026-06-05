import 'package:flutter/material.dart';

import '../00.common/network/network_room.dart';
import '../00.common/game/step.dart';
import '../00.common/widget/net_prepare_widget.dart';
import '../00.common/widget/notifier_navigator.dart';
import '../l10n/strings.dart';
import 'base.dart';
import 'foundation_widget.dart';
import 'net_manager.dart';

class GoNetPage extends StatelessWidget {
  late final GoNetManager _manager;

  GoNetPage({super.key, required RoomInfo roomInfo, required String userName}) {
    _manager = GoNetManager(roomInfo: roomInfo, userName: userName);
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
      title: Text(S.weiqi),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _manager.netTurnEngine.leavePage,
      ),
      actions: [
        IconButton(icon: const Icon(Icons.flag), onPressed: _manager.resign),
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
                      Expanded(child: GoFoundationWidget(manager: _manager)),
                    ]
                  : [Expanded(child: NetPrepareWidget(step: step))]),
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
        text = S.sideWin(player == StoneState.white ? S.blackSide : S.whiteSide);
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
