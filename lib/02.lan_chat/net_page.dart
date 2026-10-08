import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import '../00.common/model/app_item_type.dart';
import '../00.common/network/client/socket_client.dart';
import '../00.common/network/client/room_chat_engine.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/style/chat_theme.dart';

import 'net_manager.dart';
import 'attachment_menu.dart';

class NetChatPage extends StatefulWidget {
  final SocketClient room;
  final String gameName;

  /// 由首页注入，聊天室不导入任何具体游戏；匹配成功后才构建单局页面。
  final WidgetBuilder? gamePageBuilder;

  NetChatPage({
    super.key,
    required this.room,
    this.gameName = '',
    this.gamePageBuilder,
  }) {
    if (!room.isJoined) {
      throw StateError('Room authentication has not completed');
    }
  }

  @override
  State<NetChatPage> createState() => _NetChatPageState();
}

class _NetChatPageState extends State<NetChatPage> {
  late final NetManager _manager;
  late final RoomChatEngine _engine;
  final ChatTheme _theme = ChatTheme.light;
  bool _openingGame = false;
  bool _roomDisposed = false;
  MaterialPageRoute<void>? _gameRoute;

  String get _gameName => widget.gameName.isNotEmpty
      ? widget.gameName
      : OnlineItemType.tryFromRoomType(widget.room.roomType)?.name ?? '';

  @override
  void initState() {
    super.initState();
    _engine = RoomChatEngine.forClient(widget.room);
    _manager = NetManager(room: widget.room);
    _engine.matchPhase.addListener(_matchChanged);
    _matchChanged();
  }

  /// 房间持有连接与共享引擎，单局路由只借用它们并释放自己的 Manager。
  void _matchChanged() {
    if (!mounted ||
        _openingGame ||
        _engine.matchPhase.value != RoomMatchPhase.matched) {
      return;
    }
    _openingGame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!widget.room.isJoined ||
          _engine.matchPhase.value != RoomMatchPhase.matched) {
        setState(() => _openingGame = false);
        return;
      }
      final builder = widget.gamePageBuilder;
      if (builder == null) {
        _engine.cancelMatching();
        _openingGame = false;
        return;
      }
      _engine.openMatchedGame();
      final route = MaterialPageRoute<void>(builder: builder);
      _gameRoute = route;
      try {
        await Navigator.of(context).push(route);
        // push 的 Future 在 pop 时就完成，旧页还可能播放退出动画。
        // 要等组件和 Manager 真正卸载，才能再次配置同一个游戏引擎。
        await route.completed;
      } finally {
        _gameRoute = null;
        if (mounted) {
          setState(() => _openingGame = false);
        } else {
          _disposeRoom();
        }
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _engine.matchPhase.removeListener(_matchChanged);
    _engine.cancelMatching();
    _manager.dispose();
    final route = _gameRoute;
    if (route != null) {
      _engine.finishActiveGame();
      // 导航栈整体卸载或强制离房时，游戏页可能仍在卸载。
      // 等它释放 Manager 后再销毁共享通知器，避免子组件使用已销毁的状态。
      unawaited(route.completed.then((_) => _disposeRoom()));
    } else {
      _disposeRoom();
    }
    super.dispose();
  }

  void _disposeRoom() {
    if (_roomDisposed) return;
    _roomDisposed = true;
    _engine.dispose();
    widget.room.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _manager.leavePage();
      },
      child: Scaffold(
        backgroundColor: _theme.backgroundColor,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: ChatTheme.glassColor),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _theme.iconColor,
          size: 20,
        ),
        onPressed: _manager.leavePage,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<Map<int, String>>(
            valueListenable: _manager.room.members,
            builder: (_, session, __) => Text(
              '${_manager.room.roomName} (${session.length})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _theme.otherTextColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          _statusDot(),
        ],
      ),
      centerTitle: false,
      actions: [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: _theme.iconColor,
            size: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: _handleMenuAction,
          itemBuilder: (_) => [
            _menuItem('clear', Icons.delete_outline_rounded, S.clearHistory),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: _theme.iconColor),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  Widget _statusDot() {
    return ValueListenableBuilder<int>(
      valueListenable: _manager.room.identityNotifier,
      builder: (_, identity, __) {
        final online = identity > 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: online ? const Color(0xFF07C160) : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              online ? S.online : S.connecting,
              style: TextStyle(
                color: online
                    ? const Color(0xFF07C160)
                    : _theme.systemTextColor,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody() => ValueListenableBuilder<RoomStatus>(
    valueListenable: widget.room.status,
    builder: (_, status, __) {
      final showStatus =
          status.state != RoomConnectionState.joined &&
          status.state != RoomConnectionState.closed;
      final hasGame = widget.gamePageBuilder != null;
      final failed = status.state == RoomConnectionState.failed;
      final text = failed
          ? switch (status.failure) {
              RoomFailure.roomClosed => S.roomClosed,
              RoomFailure.invalidPassword => S.incorrectRoomPassword,
              _ => S.roomJoinFailed,
            }
          : S.reconnecting(status.attempt, widget.room.maxReconnectAttempts);
      return Column(
        children: [
          NotifierNavigator(navigatorHandler: _manager.pageNavigator),
          if (showStatus || hasGame)
            PinnedRoomCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showStatus)
                    ListTile(
                      title: Text(text),
                      trailing: TextButton(
                        onPressed: _manager.leavePage,
                        child: Text(failed ? S.close : S.cancel),
                      ),
                    ),
                  if (hasGame) _gameCard(),
                ],
              ),
            ),
          Expanded(
            child: MessageList(
              identity: widget.room.identity,
              userName: widget.room.userName,
              messageList: _engine.messageList,
              theme: _theme,
              topPadding: showStatus || hasGame
                  ? 4
                  : MediaQuery.paddingOf(context).top + kToolbarHeight + 4,
            ),
          ),
          MessageInput(
            onSendText: _engine.sendText,
            theme: _theme,
            onAttachmentTap: _showAttachmentMenu,
          ),
        ],
      );
    },
  );

  void _showAttachmentMenu() {
    AttachmentMenu.show(
      context: context,
      onImagePick: () => RoomAttachmentPicker.pickImage(context, _engine),
      onFilePick: () => RoomAttachmentPicker.pickFile(context, _engine),
    );
  }

  Widget _gameCard() {
    return ValueListenableBuilder<RoomMatchPhase>(
      valueListenable: _engine.matchPhase,
      builder: (_, match, __) {
        final matching =
            match == RoomMatchPhase.matching ||
            match == RoomMatchPhase.matched ||
            _openingGame;
        final pending = match == RoomMatchPhase.sending;
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: ListTile(
            leading: const Icon(Icons.gamepad),
            title: Text(S.roomTypeString(_gameName)),
            subtitle: matching ? Text(S.matching) : null,
            trailing: TextButton(
              onPressed: pending || _openingGame
                  ? null
                  : matching
                  ? _cancelMatch
                  : _requestPlay,
              child: Text(
                pending
                    ? S.startMatching
                    : matching
                    ? S.cancelMatching
                    : S.startMatching,
              ),
            ),
            onTap: matching || pending ? null : _requestPlay,
          ),
        );
      },
    );
  }

  void _requestPlay() {
    final room = _manager.room;
    final type = room.roomType;
    if (room.identity == 0 ||
        _openingGame ||
        _engine.matchPhase.value != RoomMatchPhase.idle ||
        type <= 0 ||
        widget.gamePageBuilder == null) {
      return;
    }
    _engine.startMatching();
  }

  void _cancelMatch() {
    if (_engine.matchPhase.value != RoomMatchPhase.idle) {
      _engine.cancelMatching();
      return;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(S.clearHistory),
            content: Text(S.clearHistoryConfirm),
            actions: [
              TextButton(
                onPressed: () {
                  _engine.messageList.clear();
                  Navigator.pop(context);
                },
                child: Text(
                  S.confirm,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.cancel),
              ),
            ],
          ),
        );
        break;
    }
  }
}

/// 聊天内容可延伸到毛玻璃顶部栏后方，但置顶内容必须避开顶部栏。
class PinnedRoomCard extends StatelessWidget {
  final Widget child;

  const PinnedRoomCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + kToolbarHeight,
    ),
    child: child,
  );
}
