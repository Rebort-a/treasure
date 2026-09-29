import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/model/notifiers.dart';
import 'package:treasure/00.common/widget/navigator/notifier_navigator.dart';

void main() {
  for (final reentrant in [false, true]) {
    testWidgets('已退出路由不能执行${reentrant ? '回调中重复' : '同帧连续'}的退出命令', (
      tester,
    ) async {
      final notifier = AlwaysNotifier<void Function(BuildContext)>((_) {});
      final observer = _PopObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PopScope(
                      canPop: false,
                      // 故意模拟旧页面的错误用法，验证公共导航器也能拦住重复 pop。
                      onPopInvokedWithResult: (didPop, _) {
                        if (reentrant) {
                          notifier.value = (context) => Navigator.pop(context);
                        }
                      },
                      child: Scaffold(
                        body: NotifierNavigator(navigatorHandler: notifier),
                      ),
                    ),
                  ),
                ),
                child: const Text('首页'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      notifier.value = (context) => Navigator.pop(context);
      if (!reentrant) notifier.value = (context) => Navigator.pop(context);
      await tester.pumpAndSettle();
      expect(observer.pops, 1);
      expect(find.text('首页'), findsOneWidget);
      expect(Navigator.of(tester.element(find.text('首页'))).canPop(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      notifier.dispose();
    });
  }

  testWidgets('仍在栈内的页面可以关闭覆盖自己的弹窗', (tester) async {
    final notifier = AlwaysNotifier<void Function(BuildContext)>((_) {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('首页'),
              NotifierNavigator(navigatorHandler: notifier),
            ],
          ),
        ),
      ),
    );
    notifier.value = (context) => showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('提示')),
    );
    await tester.pumpAndSettle();
    expect(find.text('提示'), findsOneWidget);
    notifier.value = (context) => Navigator.pop(context);
    await tester.pumpAndSettle();
    expect(find.text('提示'), findsNothing);
    expect(find.text('首页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    notifier.dispose();
  });

  testWidgets('空闲导航器不持续调度帧，命令只执行一次', (tester) async {
    final notifier = AlwaysNotifier<void Function(BuildContext)>((_) {});
    var runs = 0;
    Widget page() =>
        MaterialApp(home: NotifierNavigator(navigatorHandler: notifier));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    notifier.value = (_) => runs++;
    await tester.pumpAndSettle();
    expect(runs, 1);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(runs, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    notifier.dispose();
  });

  testWidgets('同帧命令和执行期间产生的新命令不会被清空覆盖', (tester) async {
    final notifier = AlwaysNotifier<void Function(BuildContext)>((_) {});
    final events = <int>[];
    await tester.pumpWidget(
      MaterialApp(home: NotifierNavigator(navigatorHandler: notifier)),
    );
    notifier.value = (_) {
      events.add(1);
      notifier.value = (_) => events.add(3);
    };
    notifier.value = (_) => events.add(2);
    await tester.pumpAndSettle();
    expect(events, [1, 2, 3]);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    notifier.dispose();
  });

  testWidgets('卸载后不执行待处理命令，重新挂载不重复旧命令', (tester) async {
    final notifier = AlwaysNotifier<void Function(BuildContext)>((_) {});
    var runs = 0;
    await tester.pumpWidget(
      MaterialApp(home: NotifierNavigator(navigatorHandler: notifier)),
    );
    notifier.value = (_) => runs++;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(runs, 0);
    await tester.pumpWidget(
      MaterialApp(home: NotifierNavigator(navigatorHandler: notifier)),
    );
    await tester.pumpAndSettle();
    expect(runs, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    notifier.dispose();
  });

  testWidgets('更换通知器后只处理新通知器的命令', (tester) async {
    final first = AlwaysNotifier<void Function(BuildContext)>((_) {});
    final second = AlwaysNotifier<void Function(BuildContext)>((_) {});
    var runs = 0;
    await tester.pumpWidget(
      MaterialApp(home: NotifierNavigator(navigatorHandler: first)),
    );
    first.value = (_) => runs += 100;
    second.value = (_) => runs++;
    await tester.pumpWidget(
      MaterialApp(home: NotifierNavigator(navigatorHandler: second)),
    );
    await tester.pumpAndSettle();
    first.value = (_) => runs += 100;
    second.value = (_) => runs++;
    await tester.pumpAndSettle();
    expect(runs, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    second.dispose();
  });
}

class _PopObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}
