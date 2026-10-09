import 'package:flutter/material.dart';

import '../middle/common.dart';

/// 仅迷宫遭遇战固定使用缩放过渡，不改变应用主题或其他页面的导航效果。
class MazeCombatRoute extends MaterialPageRoute<ResultType> {
  static const _transitions = ZoomPageTransitionsBuilder();

  MazeCombatRoute({required super.builder});

  @override
  Duration get transitionDuration => _transitions.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _transitions.reverseTransitionDuration;

  // 将同一过渡交给下层迷宫页面，使进出战斗时两页的动画保持一致。
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _transitions.delegatedTransition;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _transitions.buildTransitions<ResultType>(
    this,
    context,
    animation,
    secondaryAnimation,
    child,
  );
}
