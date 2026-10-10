import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/01.home/floating_navigation_bar.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final style in NavigationBarType.values) {
      testWidgets('$brightness / $style 导航栏外边框保持半透明灰色细线', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              bottomNavigationBar: FloatingNavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                backgroundStyle: style,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.apps), label: '应用'),
                  NavigationDestination(icon: Icon(Icons.lan), label: '联机'),
                  NavigationDestination(
                    icon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
              ),
            ),
          ),
        );
        final surface = tester.widget<Container>(
          find.byKey(const ValueKey('navigation-surface')),
        );
        final decoration = surface.foregroundDecoration! as BoxDecoration;
        final border = decoration.border! as Border;
        for (final side in [
          border.top,
          border.right,
          border.bottom,
          border.left,
        ]) {
          expect(
            side.color,
            Colors.grey.withValues(
              alpha: brightness == Brightness.dark ? 0.45 : 0.40,
            ),
          );
          expect(side.width, 1);
          expect(side.style, BorderStyle.solid);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
