import 'dart:ui' show ImageByteFormat, SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/l10n.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/style/theme.dart';
import 'package:treasure/01.home/floating_navigation_bar.dart';
import 'package:treasure/01.home/home_manager.dart';
import 'package:treasure/01.home/home_page.dart';
import 'package:treasure/01.home/route.dart';
import 'package:treasure/main.dart';

const _selection = ValueKey('navigation-selection');
Finder _destination(int index) =>
    find.byKey(ValueKey('navigation-destination-$index'));
const _destinations = [
  NavigationDestination(
    icon: Icon(Icons.widgets_outlined),
    selectedIcon: Icon(Icons.widgets),
    label: 'Local',
  ),
  NavigationDestination(
    icon: Icon(Icons.lan_outlined),
    selectedIcon: Icon(Icons.lan),
    label: 'Network',
  ),
  NavigationDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];

Widget _navigation({
  bool reduceMotion = false,
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  double bottomPadding = 0,
  Widget body = const SizedBox.expand(),
}) {
  var index = 0;
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
          padding: EdgeInsets.only(bottom: bottomPadding),
        ),
        child: Directionality(
          textDirection: direction,
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              extendBody: true,
              body: body,
              bottomNavigationBar: FloatingNavigationBar(
                selectedIndex: index,
                onDestinationSelected: (value) => setState(() => index = value),
                destinations: _destinations,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'one selection shadow slides continuously and can be retargeted',
    (tester) async {
      await tester.pumpWidget(_navigation());
      final start = tester.getCenter(find.byKey(_selection)).dx;
      final end = tester.getCenter(_destination(2)).dx;
      await tester.tap(_destination(2));
      await tester.pump();
      expect(tester.getCenter(find.byKey(_selection)).dx, start);
      await tester.pump(const Duration(milliseconds: 100));
      final intermediate = tester.getCenter(find.byKey(_selection)).dx;
      expect(intermediate, greaterThan(start));
      expect(intermediate, lessThan(end));
      expect(find.byKey(_selection), findsOneWidget);

      await tester.tap(_destination(1));
      await tester.pump();
      expect(tester.getCenter(find.byKey(_selection)).dx, intermediate);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(_selection)).dx,
        closeTo(tester.getCenter(_destination(1)).dx, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion moves selection immediately', (tester) async {
    await tester.pumpWidget(_navigation(reduceMotion: true));
    await tester.tap(_destination(2));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
      Duration.zero,
    );
    expect(
      tester.getCenter(find.byKey(_selection)).dx,
      closeTo(tester.getCenter(_destination(2)).dx, 0.1),
    );
  });

  testWidgets('RTL mirrors the moving shadow and destination order', (
    tester,
  ) async {
    await tester.pumpWidget(_navigation(direction: TextDirection.rtl));
    final start = tester.getCenter(find.byKey(_selection)).dx;
    expect(start, greaterThan(tester.getCenter(_destination(2)).dx));
    await tester.tap(_destination(2));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byKey(_selection)).dx,
      closeTo(tester.getCenter(_destination(2)).dx, 0.1),
    );
  });

  testWidgets('destinations expose selected state and accessible tap actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_navigation());
    final local = tester.getSemantics(find.bySemanticsLabel('Local'));
    expect(local.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(local.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(local.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(_destination(2));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Settings'))
          .hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Local'))
          .hasFlag(SemanticsFlag.isSelected),
      isFalse,
    );
    semantics.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('narrow screen, large text, safe area (dark: $dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _navigation(dark: dark, textScale: 2, bottomPadding: 34),
      );
      final glass = tester.getRect(find.byType(BackdropFilter));
      expect(glass.left, 16);
      expect(glass.right, 304);
      expect(glass.height, 56);
      expect(glass.bottom, 640 - 34 - 12);
      await tester.tap(_destination(2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop capsule stays centered and does not stretch', (
    tester,
  ) async {
    await tester.pumpWidget(_navigation());
    final glass = tester.getRect(find.byType(BackdropFilter));
    expect(glass.width, 480);
    expect(glass.height, 56);
    expect(glass.center.dx, 400);
  });

  testWidgets('三个标签始终只显示居中图标，不显示文字', (tester) async {
    await tester.pumpWidget(_navigation());
    expect(find.text('Local'), findsNothing);
    expect(find.text('Network'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    for (var index = 0; index < 3; index++) {
      expect(
        tester.getCenter(
          find.descendant(of: _destination(index), matching: find.byType(Icon)),
        ),
        tester.getCenter(_destination(index)),
      );
    }
    expect(tester.widget<DecoratedBox>(find.byKey(_selection)).child, isNull);
    await tester.tap(_destination(2));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Local'), findsNothing);
    expect(find.text('Network'), findsNothing);
    expect(
      tester.getCenter(find.byIcon(Icons.settings)),
      tester.getCenter(_destination(2)),
    );
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('按下目标标签时不提前显示水波纹或第二块选中阴影', (tester) async {
    await tester.pumpWidget(_navigation());
    final start = tester.getCenter(find.byKey(_selection));
    final gesture = await tester.startGesture(
      tester.getCenter(_destination(2)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getCenter(find.byKey(_selection)), start);
    final ink = tester.widget<InkWell>(
      find.descendant(of: _destination(2), matching: find.byType(InkWell)),
    );
    expect(ink.splashFactory, NoSplash.splashFactory);
    for (final state in [
      WidgetState.pressed,
      WidgetState.hovered,
      WidgetState.focused,
    ]) {
      expect(ink.overlayColor!.resolve({state}), Colors.transparent);
    }
    await gesture.up();
    await tester.pump();
    expect(tester.getCenter(find.byKey(_selection)), start);
    expect(find.byKey(_selection), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byKey(_selection)).dx,
      closeTo(tester.getCenter(_destination(2)).dx, 0.1),
    );
  });

  testWidgets('关闭水波纹后仍支持键盘聚焦和切换', (tester) async {
    await tester.pumpWidget(_navigation());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusedBorder = tester.widget<DecoratedBox>(
      find.descendant(of: _destination(1), matching: find.byType(DecoratedBox)),
    );
    expect((focusedBorder.decoration as BoxDecoration).border, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lan), findsOneWidget);
    expect(find.text('Network'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('毛玻璃实际渲染可透出背后的不同色块（深色：$dark）', (tester) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: _navigation(
            dark: dark,
            body: const Row(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: Colors.red,
                    child: SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: Colors.blue,
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final glass = tester.getRect(find.byType(BackdropFilter));
      // 在图标和选中背景之外取样，验证底部确实绘制了背后的内容。
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final data = (await image.toByteData(
            format: ImageByteFormat.rawRgba,
          ))!;
          final y = (glass.top + 8).round();
          final redOffset =
              (y * image.width + (glass.left + glass.width * 0.42).round()) * 4;
          final blueOffset =
              (y * image.width + (glass.left + glass.width * 0.65).round()) * 4;
          expect(
            data.getUint8(redOffset) - data.getUint8(redOffset + 2),
            greaterThan(100),
          );
          expect(
            data.getUint8(blueOffset + 2) - data.getUint8(blueOffset),
            greaterThan(100),
          );
        } finally {
          image.dispose();
        }
      });
    });
  }

  testWidgets(
    'home content clears the capsule and retains search across tabs',
    (tester) async {
      LanguageProvider.instance.resetForTesting();
      ThemeProvider.instance.resetForTesting();
      final manager = HomeManager(startDiscovery: false);
      await tester.pumpWidget(MyApp(home: HomePage(manager: manager)));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final lastApp = find.text(
        S.roomTypeString(LocalItemType.values.last.name),
      );
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
    },
  );

  testWidgets('keyboard hides capsule without losing the selected page', (
    tester,
  ) async {
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
