import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/01.home/floating_navigation_bar.dart';
import 'package:treasure/01.home/home_manager.dart';
import 'package:treasure/01.home/home_page.dart';
import 'package:treasure/main.dart';

void main() {
  for (final title in [
    'Animal Chess',
    'Gomoku',
    'Go',
    'Sudoku',
    'Guess',
    '3tiles',
    'Memory Match',
    'Schulte',
  ]) {
    for (final systemBack in [false, true]) {
      testWidgets('从 $title ${systemBack ? '系统返回' : '点击返回'}后保留首页，可再次进入', (
        tester,
      ) async {
        LanguageProvider.instance.resetForTesting();
        ThemeProvider.instance.resetForTesting();
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
          expect(find.text('Apps'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
