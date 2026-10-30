import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/00.common/widget/navigator/floating_navigation_bar.dart';
import 'package:treasure/01.home/upper/home_manager.dart';
import 'package:treasure/01.home/upper/home_page.dart';
import 'package:treasure/01.home/middle/background_settings.dart';
import 'package:treasure/01.home/route.dart';
import 'package:treasure/main.dart';

Finder _destination(int index) =>
    find.byKey(ValueKey('navigation-destination-$index'));

Future<void> _swipeTab(
  WidgetTester tester, {
  required bool next,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final pages = find.byKey(const ValueKey('home-pages'));
  final distance = tester.getSize(pages).width * 0.8;
  await tester.drag(pages, Offset(next ? -distance : distance, 0), kind: kind);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => BackgroundSettings.instance.resetForTesting());

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('左右滑动与导航点击同步切换标签，首尾滑动不越界：$kind', (tester) async {
      LanguageProvider.instance.resetForTesting();
      await tester.pumpWidget(
        MyApp(home: HomePage(manager: HomeManager(startDiscovery: false))),
      );
      await tester.pumpAndSettle();
      int selected() => tester
          .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
          .selectedIndex;

      expect(selected(), 0);
      await _swipeTab(tester, next: false, kind: kind);
      expect(selected(), 0);
      await _swipeTab(tester, next: true, kind: kind);
      expect(selected(), 1);
      await _swipeTab(tester, next: true, kind: kind);
      expect(selected(), 2);
      await _swipeTab(tester, next: true, kind: kind);
      expect(selected(), 2);
      await tester.tap(_destination(0));
      await tester.pumpAndSettle();
      expect(selected(), 0);
      await _swipeTab(tester, next: true, kind: kind);
      expect(selected(), 1);
      await _swipeTab(tester, next: false, kind: kind);
      expect(selected(), 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('背景覆盖首页三个标签，设置可恢复默认背景', (tester) async {
    LanguageProvider.instance.resetForTesting();
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAA'
      'RnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAQSURBVBhXY/jPw'
      'PCfARkAAB7zAf+x9MCaAAAAAElFTkSuQmCC',
    );
    BackgroundSettings.instance.image.value = bytes;
    await tester.pumpWidget(
      MyApp(home: HomePage(manager: HomeManager(startDiscovery: false))),
    );
    await tester.pumpAndSettle();
    final background = find.byKey(const ValueKey('home-background-image'));
    expect(background, findsOneWidget);
    for (final index in [1, 2]) {
      await tester.tap(_destination(index));
      await tester.pumpAndSettle();
      expect(background, findsOneWidget);
    }
    expect(find.text(S.background), findsOneWidget);
    await tester.tap(find.byTooltip(S.restoreDefaultBackground));
    await tester.pumpAndSettle();
    expect(background, findsNothing);
    expect(BackgroundSettings.instance.image.value, isNull);
    expect(tester.takeException(), isNull);
  });

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
    final query = S.roomTypeString(AppItemType.gobang.name);
    await tester.enterText(find.byType(TextField), query);
    await _swipeTab(tester, next: true);
    await _swipeTab(tester, next: false);
    await tester.tap(_destination(2));
    await tester.pumpAndSettle();
    await tester.tap(_destination(0));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      query,
    );
    expect(find.text(query), findsWidgets);
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
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
