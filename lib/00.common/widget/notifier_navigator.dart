import 'package:flutter/material.dart';

import '../tool/notifiers.dart';

class NotifierNavigator extends StatelessWidget {
  final AlwaysNotifier<void Function(BuildContext)> navigatorHandler;

  const NotifierNavigator({super.key, required this.navigatorHandler});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<void Function(BuildContext)>(
      valueListenable: navigatorHandler,
      builder: (context, navigator, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigator(context);
          navigatorHandler.value = (_) {};
        });
        return const SizedBox.shrink();
      },
    );
  }
}
