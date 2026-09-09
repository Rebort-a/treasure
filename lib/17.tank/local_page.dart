import 'package:flutter/material.dart';

import 'foundation_widget.dart';
import 'local_manager.dart';

class LocalTankPage extends StatelessWidget {
  final manager = LocalTankManager();

  LocalTankPage({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: GameScreen(manager: manager, showStateButton: true),
  );
}
