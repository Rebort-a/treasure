import 'package:flutter/material.dart';

import '../00.common/game/step.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/network/network_room.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import 'foundation_widget.dart';
import 'net_manager.dart';

class NetTankPage extends StatefulWidget {
  final RoomInfo roomInfo;
  final String userName;

  const NetTankPage({
    super.key,
    required this.roomInfo,
    required this.userName,
  });

  @override
  State<NetTankPage> createState() => _NetTankPageState();
}

class _NetTankPageState extends State<NetTankPage> {
  late final NetTankManager manager;

  @override
  void initState() {
    super.initState();
    manager = NetTankManager(
      roomInfo: widget.roomInfo,
      userName: widget.userName,
    );
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PopScope(canPop: false, child: _buildPage());

  Widget _buildPage() {
    return ValueListenableBuilder<GameStep>(
      valueListenable: manager.engine.gameStep,
      builder: (_, step, __) {
        return step == GameStep.action
            ? TankGameScreen(manager: manager, showStateButton: false)
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
