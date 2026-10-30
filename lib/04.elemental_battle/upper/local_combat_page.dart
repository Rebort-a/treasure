import 'package:flutter/material.dart';

import '../../00.common/widget/component/game_audio_scope.dart';

import '../../00.common/game/gamer.dart';
import '../../00.common/widget/navigator/notifier_navigator.dart';
import 'foundation_combat_widget.dart';
import '../middle/elemental.dart';
import 'local_combat_manager.dart';

class LocalCombatPage extends StatefulWidget {
  final Elemental player;
  final Elemental enemy;
  final TurnGamerType playerType;

  const LocalCombatPage({
    super.key,
    required this.player,
    required this.enemy,
    required this.playerType,
  });

  @override
  State<LocalCombatPage> createState() => _LocalCombatPageState();
}

class _LocalCombatPageState extends State<LocalCombatPage> {
  late final LocalCombatManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = LocalCombatManager(
      player: widget.player,
      enemy: widget.enemy,
      playerType: widget.playerType,
    );
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameAudioScope(
      source: _manager,
      project: '04.elemental_battle',
      child: PopScope(canPop: false, child: Scaffold(body: _buildBody())),
    );
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
