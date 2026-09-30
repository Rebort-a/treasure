import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/01.home/floating_navigation_bar.dart';
import 'package:treasure/01.home/home_manager.dart';
import 'package:treasure/01.home/home_page.dart';
import 'package:treasure/01.home/route.dart';
import 'package:treasure/main.dart';

Finder _destination(int index) =>
    find.byKey(ValueKey('navigation-destination-$index'));

void main() {
  testWidgets('首页标签切换保留应用搜索并确保列表可滚动到底', (tester) async {
    LanguageProvider.instance.resetForTesting();
    ThemeProvider.instance.resetForTesting();
    final manager = HomeManager(startDiscovery: false);
    await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final lastApp = find.text(S.roomTypeString(AppItemType.values.last.name));
    expect(
      tester.getRect(lastApp).bottom,
      lessThan(tester.getRect(find.byType(FloatingNavigationBar)).top),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Gomoku');
    await tester.tap(_destination(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(_destination(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Gomoku',
    );
    expect(find.text('All apps (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘弹出时隐藏导航胶囊且保留当前标签', (tester) async {
    LanguageProvider.instance.resetForTesting();
    final manager = HomeManager(startDiscovery: false);

    Widget home(double keyboard) => MyApp(
      home: MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboard)),
        child: HomePage(manager: manager),
      ),
    );

    await tester.pumpWidget(home(0));
    await tester.pump();
    await tester.pumpWidget(home(280));
    await tester.pump();

    expect(find.byType(FloatingNavigationBar), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(home(0));
    await tester.pump();
    expect(find.byType(FloatingNavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.widgets), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
