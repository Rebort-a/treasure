import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../network/client/game_engine.dart';
import '../../network/client/net_turn_engine.dart';

typedef OnlineGameViewBuilder<M extends Object> = Widget Function(
  BuildContext context,
  M manager,
  VoidCallback requestExit,
);

/// 单局生命周期容器，由游戏模块内部组合使用，不要求页面继承公共基类。
///
/// Manager 在 initState 中创建一次，父页面重建不重复创建；结束后退回下层路由，
/// 卸载时释放本局 Manager。共享引擎和房间连接始终归聊天室所有。
class OnlineGameHost<M extends Object> extends StatefulWidget {
  final M Function() createManager;
  final GameEngine Function(M manager) engineOf;
  final void Function(M manager) disposeManager;
  final OnlineGameViewBuilder<M> pageBuilder;

  const OnlineGameHost({
    super.key,
    required this.createManager,
    required this.engineOf,
    required this.disposeManager,
    required this.pageBuilder,
  });

  @override
  State<OnlineGameHost<M>> createState() => _OnlineGameHostState<M>();
}

class _OnlineGameHostState<M extends Object> extends State<OnlineGameHost<M>> {
  late final M _manager;
  late final GameEngine _game;
  late final void Function(M manager) _disposeManager;
  bool _exitScheduled = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _disposeManager = widget.disposeManager;
    _manager = widget.createManager();
    _game = widget.engineOf(_manager);
    _game.ended.addListener(_gameEnded);
    _game.startFromRoom();
    // 匹配与页面构建之间可能断线，此时退回房间，而不是留下未启动的游戏页。
    if (!_game.isActive) _game.finishGame(sendExit: false);
    _gameEnded();
  }

  void _gameEnded() {
    if (!_game.ended.value || _exitScheduled) return;
    _exitScheduled = true;
    // 网络回调和游戏组件 build 都可能结束对局，导航统一推迟到帧结束。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      if (route == null || !route.isActive || !navigator.canPop()) return;
      // 对手退出时可能还显示配置子页面或投降对话框，先收起它们再返回房间。
      navigator.popUntil((candidate) => candidate == route);
      if (route.isCurrent) navigator.pop();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _requestExit() async {
    if (_game.ended.value || _confirming) return;
    if (_game is! NetTurnEngine) {
      _game.leavePage();
      return;
    }
    _confirming = true;
    try {
      final surrender = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.surrender),
          content: Text(S.confirmSurrender),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(S.confirm),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(S.cancel),
            ),
          ],
        ),
      );
      if (mounted && surrender == true && !_game.ended.value) {
        _game.leavePage();
      }
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _game.ended,
    builder: (context, ended, _) => PopScope(
      canPop: ended,
      onPopInvokedWithResult: (didPop, _) {
        // 回合制返回即投降，实时游戏仍通过可见退出按钮退场。
        if (!didPop && _game is NetTurnEngine) unawaited(_requestExit());
      },
      child: widget.pageBuilder(context, _manager, () {
        unawaited(_requestExit());
      }),
    ),
  );

  @override
  void dispose() {
    _game.ended.removeListener(_gameEnded);
    _game.finishGame();
    // 与创建时的所有权配对，不因父组件重建、替换回调而改变释放职责。
    _disposeManager(_manager);
    // 共享引擎和 SocketClient 归房间入口所有，返回时绝不关闭它们。
    super.dispose();
  }
}
