import 'package:flutter/material.dart';

import '../../00.common/game/gamer.dart';
import '../../00.common/widget/notifier_navigator.dart';
import '../middle/foundation_combat_widget.dart';
import '../middle/elemental.dart';
import 'local_combat_manager.dart';

class LocalCombatPage extends StatelessWidget {
  late final LocalCombatManager _manager;

  LocalCombatPage({
    super.key,
    required Elemental player,
    required Elemental enemy,
    required TurnGamerType playerType,
  }) {
    _manager = LocalCombatManager(
      player: player,
      enemy: enemy,
      playerType: playerType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: Scaffold(body: _buildBody()));
  }

  Widget _buildBody() {
    return OrientationBuilder(
      builder: (context, orientation) {
        // 根据屏幕方向选择布局
        return orientation == Orientation.portrait
            ? _buildPortraitLayout(context)
            : _buildLandscapeLayout(context);
      },
    );
  }

  // 竖屏布局
  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        ...FoundationalCombatWidget(combatManager: _manager).buildPage(),
        _buildBlankRegion(),
      ],
    );
  }

  Widget _buildBlankRegion() => const SizedBox(height: 192);

  // 横屏布局
  Widget _buildLandscapeLayout(BuildContext context) {
    return Column(
      children: [
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        ...FoundationalCombatWidget(combatManager: _manager).buildPage(),
      ],
    );
  }
}
