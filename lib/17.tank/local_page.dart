import 'package:flutter/material.dart';

import 'foundation_widget.dart';
import 'local_manager.dart';

class LocalTankPage extends StatefulWidget {
  const LocalTankPage({super.key});

  @override
  State<LocalTankPage> createState() => _LocalTankPageState();
}

class _LocalTankPageState extends State<LocalTankPage> {
  late final LocalTankManager manager;

  @override
  void initState() {
    super.initState();
    manager = LocalTankManager();
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: TankGameScreen(
      manager: manager,
      showStateButton: true,
      onRestart: manager.requestRestart,
    ),
  );
}
