import 'package:flutter/material.dart';

import '../middle/match_manager.dart';
import 'game_view.dart';

class LocalMatchThreePage extends StatelessWidget {
  const LocalMatchThreePage({super.key});

  @override
  Widget build(BuildContext context) => const _LocalMatchHost();
}

class _LocalMatchHost extends StatefulWidget {
  const _LocalMatchHost();

  @override
  State<_LocalMatchHost> createState() => _LocalMatchHostState();
}

class _LocalMatchHostState extends State<_LocalMatchHost> {
  late final MatchManager _manager = MatchManager();

  @override
  Widget build(BuildContext context) => MatchGameView(
    manager: _manager,
    onExit: () => Navigator.maybePop(context),
  );

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
