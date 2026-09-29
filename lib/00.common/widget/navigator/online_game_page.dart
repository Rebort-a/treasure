import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/session/game_session.dart';
import '../../network/session/turn_game_session.dart';
import '../../network/engine/network_engine.dart';
import '../../l10n/strings.dart';
import '../../../02.lan_chat/net_page.dart';

/// 联机项目只有一个页面路由；大厅和对局在该路由内切换。
abstract class OnlineGamePage<M extends Object> extends StatelessWidget {
  final NetworkEngine room;

  const OnlineGamePage({super.key, required this.room});

  String get gameName;
  M createManager();
  GameSession sessionOf(M manager);
  Widget buildGame(BuildContext context, M manager, VoidCallback requestExit);
  void disposeManager(M manager);

  @override
  Widget build(BuildContext context) => _OnlineGameHost<M>(page: this);
}

/// 管理一局游戏的创建和释放，聊天室始终保留在页面中。
class _OnlineGameHost<M extends Object> extends StatefulWidget {
  final OnlineGamePage<M> page;

  const _OnlineGameHost({required this.page});

  @override
  State<_OnlineGameHost<M>> createState() => _OnlineGameHostState<M>();
}

class _OnlineGameHostState<M extends Object> extends State<_OnlineGameHost<M>> {
  final ValueNotifier<M?> _active = ValueNotifier(null);
  GameSession? _session;
  VoidCallback? _onEnded;
  Completer<void>? _finished;
  bool _confirming = false;

  Future<void> _launchGame(BuildContext context) {
    if (_active.value != null) return _finished?.future ?? Future<void>.value();
    final manager = widget.page.createManager();
    final session = widget.page.sessionOf(manager);
    final finished = Completer<void>();
    _session = session;
    _finished = finished;
    void onEnded() {
      if (!session.ended.value || !identical(_session, session)) return;
      session.ended.removeListener(onEnded);
      _onEnded = null;
      _session = null;
      _finished = null;
      _active.value = null;
      // 等对局组件从树中移除后，再释放它所监听的通知器。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.page.disposeManager(manager);
        if (!finished.isCompleted) finished.complete();
      });
    }

    _onEnded = onEnded;
    session.ended.addListener(onEnded);
    _active.value = manager;
    session.startFromRoom();
    if (session.ended.value) onEnded();
    return finished.future;
  }

  Future<void> _requestExit() async {
    final session = _session;
    if (session is! TurnGameSession || session.ended.value || _confirming) {
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
      if (mounted && surrender == true && identical(_session, session)) {
        session.leavePage();
      }
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<M?>(
    valueListenable: _active,
    builder: (context, manager, _) => PopScope(
      canPop: manager == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && manager != null) unawaited(_requestExit());
      },
      child: IndexedStack(
        index: manager == null ? 0 : 1,
        children: [
          NetChatPage(
            room: widget.page.room,
            gameName: widget.page.gameName,
            onMatched: _launchGame,
            ignoreBack: manager != null,
          ),
          if (manager != null)
            widget.page.buildGame(context, manager, () {
              unawaited(_requestExit());
            }),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    final session = _session;
    final manager = _active.value;
    final onEnded = _onEnded;
    if (session != null && onEnded != null) {
      session.ended.removeListener(onEnded);
      session.finish();
    }
    if (manager != null) widget.page.disposeManager(manager);
    final finished = _finished;
    if (finished != null && !finished.isCompleted) finished.complete();
    _active.dispose();
    super.dispose();
  }
}
