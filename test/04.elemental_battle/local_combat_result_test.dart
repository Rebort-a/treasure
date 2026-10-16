import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/game/gamer.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/widget/navigator/notifier_navigator.dart';
import 'package:treasure/04.elemental_battle/base/energy.dart';
import 'package:treasure/04.elemental_battle/middle/common.dart';
import 'package:treasure/04.elemental_battle/middle/elemental.dart';
import 'package:treasure/04.elemental_battle/upper/local_combat_manager.dart';

void main() {
  tearDown(() => LanguageProvider.instance.resetForTesting());

  for (final locale in AppLocale.values) {
    testWidgets('本地战斗结算可关闭并返回冒险，不使用房间关闭提示：$locale', (tester) async {
      await LanguageProvider.instance.setLocale(locale);
      Elemental create(String name) => Elemental(
        baseName: name,
        configs: EnergyConfigs.defaultConfigs(),
        current: 0,
      );
      final manager = LocalCombatManager(
        player: create('Player'),
        enemy: create('Enemy'),
        playerType: TurnGamerType.front,
      );
      ResultType? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<ResultType>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: NotifierNavigator(
                          navigatorHandler: manager.pageNavigator,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Adventure'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Adventure'));
      await tester.pumpAndSettle();
      manager.updateGameStepAfterAction(true, CombatResult.attackerWin);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(S.close, locale == AppLocale.zh ? '关闭' : 'Close');
      expect(S.roomClosed, locale == AppLocale.zh ? '房间已关闭' : 'Room closed');
      expect(find.text(S.roomClosed), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, S.close));
      await tester.pumpAndSettle();
      expect(result, ResultType.victory);
      expect(find.text('Adventure'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      manager.disposeAudioEvents();
      manager.pageNavigator.dispose();
      manager.infoList.dispose();
      manager.currentGamer.dispose();
    });
  }
}
