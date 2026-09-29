import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/02.lan_chat/net_page.dart';

void main() {
  testWidgets('pinned room card stays below the translucent app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24),
            viewPadding: const EdgeInsets.only(top: 24),
          ),
          child: child!,
        ),
        home: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(title: const Text('Room')),
          body: const Column(
            children: [
              PinnedRoomCard(
                child: Card(
                  key: Key('pinned-card'),
                  child: ListTile(title: Text('Gomoku')),
                ),
              ),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

    final cardTop = tester.getTopLeft(find.byKey(const Key('pinned-card'))).dy;
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(cardTop, greaterThanOrEqualTo(appBarBottom));
  });
}
