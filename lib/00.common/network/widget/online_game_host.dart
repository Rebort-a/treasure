import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../client/base/game_engine.dart';
import '../client/net_turn_engine.dart';
import '../client/net_multi_turn_engine.dart';

typedef OnlineGameViewBuilder<M extends Object> = Widget Function(
  BuildContext context,
  M manager,
  VoidCallback requestExit,
);

/// 对局会话生命周期容器，由游戏模块内部组合使用，不要求页面继承公共基类。
///
/// Manager 在 initState 中创建一次，父页面重建及重开不重复创建；
/// 会话终止才退回下层路由并释放 Manager，房间连接始终归聊天室所有。
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
  bool get _turnBased => _game is NetTurnEngine || _game is NetMultiTurnEngine;

  @override
  void initState() {
    super.initState();
    _disposeManager = widget.disposeManager;
    _manager = widget.createManager();
    _game = widget.engineOf(_manager);
    _game.ended.addListener(_gameEnded);
    _game.roundReplay?.finished.addListener(_roundFinished);
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

  void _roundFinished() {
    if (!(_game.roundReplay?.finished.value ?? false)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(_game.roundReplay?.finished.value ?? false)) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isActive) return;
      // 收起旧局配置和技能弹窗，但保留棋盘页及其聊天历史。
      Navigator.of(context).popUntil((candidate) => candidate == route);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _requestExit() async {
    if (_game.ended.value || _confirming) return;
    if (_game.roundReplay?.finished.value ?? false) {
      _game.leavePage();
      return;
    }
    if (!_turnBased) {
      _game.leavePage();
      return;
    }
    _confirming = true;
    try {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.leave),
          content: Text(
            _game is NetMultiTurnEngine
                ? S.coopConfirmLeave
                : S.confirmGameLeave,
          ),
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
      if (mounted && leave == true && !_game.ended.value) {
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
        // 返回用于退出会话；棋盘中的投降按钮只结束当前轮次。
        if (!didPop && _turnBased) unawaited(_requestExit());
      },
      child: widget.pageBuilder(context, _manager, () {
        unawaited(_requestExit());
      }),
    ),
  );

  @override
  void dispose() {
    _game.ended.removeListener(_gameEnded);
    _game.roundReplay?.finished.removeListener(_roundFinished);
    _game.finishGame();
    // 与创建时的所有权配对，不因父组件重建、替换回调而改变释放职责。
    _disposeManager(_manager);
    // 共享引擎和 SocketClient 归房间入口所有，返回时绝不关闭它们。
    super.dispose();
  }
}
