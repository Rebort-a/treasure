import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../middle/match_manager.dart';
import 'game_view.dart';

class LocalMatchThreePage extends StatelessWidget {
  const LocalMatchThreePage({super.key});

  @override
  Widget build(BuildContext context) => const _LocalMatchHost();
}

class _LocalMatchHost extends StatefulWidget {
  const _LocalMatchHost();

  @override
  State<_LocalMatchHost> createState() => _LocalMatchHostState();
}

class _LocalMatchHostState extends State<_LocalMatchHost> {
  final _manager = MatchManager(generate: false);
  final _entranceReady = Completer<void>();
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_manager.board != null) return;
    _manager.reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animation = ModalRoute.of(context)?.animation;
    _manager.restart(entranceReady: _entranceReady.future);
    // 路由首帧可能还在离屏布局，此时动画会暂时报告已完成。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animation == null || animation.isCompleted) {
        _entranceReady.complete();
      } else {
        _routeAnimation = animation;
        animation.addStatusListener(_onRouteStatus);
      }
    });
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _entranceReady.complete();
  }

  @override
  Widget build(BuildContext context) => MatchGameView(
    manager: _manager,
    onExit: () => Navigator.maybePop(context),
  );

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _manager.dispose();
    if (!_entranceReady.isCompleted) _entranceReady.complete();
    super.dispose();
  }
}
