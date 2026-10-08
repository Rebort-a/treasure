import 'dart:ui' show ImageByteFormat, SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/01.home/floating_navigation_bar.dart';

const _selection = ValueKey('navigation-selection');
Finder _destination(int index) =>
    find.byKey(ValueKey('navigation-destination-$index'));
const _destinations = [
  NavigationDestination(
    icon: Icon(Icons.widgets_outlined),
    selectedIcon: Icon(Icons.widgets),
    label: 'Apps',
  ),
  NavigationDestination(
    icon: Icon(Icons.lan_outlined),
    selectedIcon: Icon(Icons.lan),
    label: 'Online',
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
  FloatingNavigationBarBackground backgroundStyle =
      FloatingNavigationBarBackground.translucent,
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
                backgroundStyle: backgroundStyle,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('选中背景紧贴图标，保持椭圆尺寸并随标签滑动', (tester) async {
    await tester.pumpWidget(_navigation());
    final selection = find.byKey(_selection);
    expect(tester.getSize(selection), const Size(50, 40));
    expect(
      tester.getSize(selection).width,
      lessThan(tester.getSize(_destination(0)).width),
    );
    expect(
      (tester.getCenter(selection) - tester.getCenter(_destination(0)))
          .distance,
      lessThan(0.1),
    );

    await tester.tap(_destination(2));
    await tester.pumpAndSettle();
    expect(tester.getSize(selection), const Size(50, 40));
    expect(
      (tester.getCenter(selection) - tester.getCenter(_destination(2)))
          .distance,
      lessThan(0.1),
    );
  });

  for (final dark in [false, true]) {
    testWidgets('默认半透明背景不启用模糊（深色：$dark）', (tester) async {
      await tester.pumpWidget(_navigation(dark: dark));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester
            .widget<FloatingNavigationBar>(find.byType(FloatingNavigationBar))
            .backgroundStyle,
        FloatingNavigationBarBackground.translucent,
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('navigation-surface')),
                  )
                  .decoration
              as BoxDecoration;
      final colors = (decoration.gradient! as LinearGradient).colors;
      expect(colors.first.a, closeTo(dark ? 0.72 : 0.78, 0.001));
      expect(colors.last.a, closeTo(dark ? 0.62 : 0.68, 0.001));
    });
  }

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
    final local = tester.getSemantics(find.bySemanticsLabel('Apps'));
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
          .getSemantics(find.bySemanticsLabel('Apps'))
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
      final glass = tester.getRect(
        find.byKey(const ValueKey('navigation-background')),
      );
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
    final glass = tester.getRect(
      find.byKey(const ValueKey('navigation-background')),
    );
    expect(glass.width, 480);
    expect(glass.height, 56);
    expect(glass.center.dx, 400);
  });

  testWidgets('三个标签始终只显示居中图标，不显示文字', (tester) async {
    await tester.pumpWidget(_navigation());
    expect(find.text('Apps'), findsNothing);
    expect(find.text('Online'), findsNothing);
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
    expect(find.text('Apps'), findsNothing);
    expect(find.text('Online'), findsNothing);
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
    expect(find.text('Online'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('毛玻璃实际渲染可透出背后的不同色块（深色：$dark）', (tester) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: _navigation(
            dark: dark,
            backgroundStyle: FloatingNavigationBarBackground.frostedGlass,
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
}
