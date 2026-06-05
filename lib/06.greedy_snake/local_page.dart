import 'package:flutter/material.dart';

import 'foundation_widget.dart';
import 'local_manager.dart';

class LocalGreedySnakePage extends StatelessWidget {
  final manager = LocalManager();

  LocalGreedySnakePage({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: GameScreen(manager: manager, showStateButton: true),
  );
}
