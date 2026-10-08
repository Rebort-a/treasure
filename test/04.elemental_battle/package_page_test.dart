import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/entity.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/04.elemental_battle/base/energy.dart';
import 'package:treasure/04.elemental_battle/middle/player.dart';
import 'package:treasure/04.elemental_battle/middle/prop.dart';
import 'package:treasure/04.elemental_battle/upper/package_page.dart';

Future<GlobalKey<NavigatorState>> _openPackage(
  WidgetTester tester,
  NormalPlayer player, {
  VoidCallback? onReturnHome,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    PackagePage(player: player, onReturnHome: onReturnHome),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return navigator;
}

void main() {
  late Map<EntityType, int> originalCounts;

  setUp(() {
    originalCounts = {
      for (final entry in PropCollection.totalItems.entries)
        entry.key: entry.value.count,
    };
    for (final item in PropCollection.totalItems.values) {
      item.count = 0;
    }
  });

  tearDown(() {
    for (final entry in originalCounts.entries) {
      PropCollection.totalItems[entry.key]!.count = entry.value;
    }
  });

  NormalPlayer player() => NormalPlayer(id: EntityType.player, x: 0, y: 0);

  testWidgets('选择道具后由 UI 弹窗选择目标，规则只执行一次', (tester) async {
    final user = player();
    final sword = user.props[EntityType.sword]!..count = 2;
    final before = user.getAppointAttack(EnergyType.metal);
    await _openPackage(tester, user);
    await tester.tap(find.text(sword.icon));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, S.use));
    await tester.pumpAndSettle();
    expect(sword.count, 2);
    expect(find.byType(AlertDialog), findsOneWidget);

    final target =
        '${user.getAppointName(EnergyType.metal)} '
        '${user.getAppointHealth(EnergyType.metal)}/'
        '${user.getAppointCapacity(EnergyType.metal)}';
    await tester.tap(find.widgetWithText(ElevatedButton, target));
    await tester.pumpAndSettle();
    expect(sword.count, 1);
    expect(user.getAppointAttack(EnergyType.metal), greaterThan(before));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('取消目标选择不消耗道具', (tester) async {
    final user = player();
    final shield = user.props[EntityType.shield]!..count = 1;
    final navigator = await _openPackage(tester, user);
    await tester.tap(find.text(shield.icon));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, S.use));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(shield.count, 1);
    expect(find.byType(PackagePage), findsOneWidget);
  });

  testWidgets('回城卷轴消费一次，调用页面回调并关闭背包', (tester) async {
    final user = player();
    final scroll = user.props[EntityType.scroll]!..count = 1;
    var returned = 0;
    await _openPackage(tester, user, onReturnHome: () => returned++);
    await tester.tap(find.text(scroll.icon));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, S.use));
    await tester.pumpAndSettle();
    expect(scroll.count, 0);
    expect(returned, 1);
    expect(find.byType(PackagePage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
