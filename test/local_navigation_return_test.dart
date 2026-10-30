import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/00.common/widget/navigator/floating_navigation_bar.dart';
import 'package:treasure/01.home/upper/home_manager.dart';
import 'package:treasure/01.home/upper/home_page.dart';
import 'package:treasure/main.dart';

void main() {
  for (final type in [
    AppItemType.animalChess,
    AppItemType.gobang,
    AppItemType.weiqi,
    AppItemType.sudoku,
    AppItemType.guess,
    AppItemType.threeTiles,
    AppItemType.memoryCard,
    AppItemType.schulte,
  ]) {
    for (final systemBack in [false, true]) {
      testWidgets('从 $type ${systemBack ? '系统返回' : '点击返回'}后保留首页，可再次进入', (
        tester,
      ) async {
        LanguageProvider.instance.resetForTesting();
        ThemeProvider.instance.resetForTesting();
        final title = S.roomTypeString(type.name);
        final manager = HomeManager(startDiscovery: false);
        await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), title);
        await tester.pumpAndSettle();
        for (var visit = 0; visit < 2; visit++) {
          await tester.tap(find.text(title).last);
          await tester.pumpAndSettle();
          expect(find.byType(FloatingNavigationBar), findsNothing);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else if (find.byType(BackButton).evaluate().isNotEmpty) {
            await tester.pageBack();
          } else {
            await tester.tap(find.byIcon(Icons.arrow_back).first);
          }
          await tester.pumpAndSettle();
          expect(find.byType(FloatingNavigationBar), findsOneWidget);
          expect(
            ModalRoute.of(tester.element(find.byType(HomePage)))!.isCurrent,
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
