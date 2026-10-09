import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/04.elemental_battle/middle/common.dart';
import 'package:treasure/04.elemental_battle/upper/maze_combat_route.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('迷宫遭遇战固定使用 Zoom，其他路由保留默认效果：$platform', (tester) async {
      late BuildContext homeContext;
      late BuildContext combatContext;
      late MazeCombatRoute route;
      ResultType? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) {
              homeContext = context;
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    route = MazeCombatRoute(
                      builder: (context) {
                        combatContext = context;
                        return const Scaffold(body: Text('combat'));
                      },
                    );
                    result = await Navigator.of(context).push(route);
                  },
                  child: const Text('encounter'),
                ),
              );
            },
          ),
        ),
      );
      final defaultBuilder = Theme.of(homeContext)
          .pageTransitionsTheme
          .builders[platform]!;
      expect(
        defaultBuilder,
        platform == TargetPlatform.android
            ? isA<PredictiveBackPageTransitionsBuilder>()
            : isA<ZoomPageTransitionsBuilder>(),
      );
      await tester.tap(find.text('encounter'));
      await tester.pump();
      const zoom = ZoomPageTransitionsBuilder();
      expect(route.transitionDuration, zoom.transitionDuration);
      expect(route.reverseTransitionDuration, zoom.reverseTransitionDuration);
      expect(route.delegatedTransition, isNotNull);
      const animation = AlwaysStoppedAnimation<double>(0.5);
      const secondary = AlwaysStoppedAnimation<double>(0);
      const child = Text('transition');
      // 直接比较实际构建的过渡，避免只检查类名或主题配置。
      expect(
        route
            .buildTransitions(combatContext, animation, secondary, child)
            .runtimeType,
        zoom
            .buildTransitions<ResultType>(
              route,
              combatContext,
              animation,
              secondary,
              child,
            )
            .runtimeType,
      );
      await tester.pumpAndSettle();
      expect(find.text('combat'), findsOneWidget);
      // 路由不会修改页面的主题，后续普通跳转仍使用平台默认构建器。
      expect(
        Theme.of(combatContext).pageTransitionsTheme.builders[platform],
        same(defaultBuilder),
      );
      Navigator.of(combatContext).pop(ResultType.escape);
      await tester.pumpAndSettle();
      expect(result, ResultType.escape);
      expect(find.text('encounter'), findsOneWidget);
      expect(find.text('combat'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
