import 'dart:convert';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../00.common/network/network_room.dart';

import '../00.common/network/room_session.dart';
import '../00.common/widget/navigator/game_launch.dart';
import '../00.common/style/chat_theme.dart';
import '../00.common/tool/blur_hash.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'net_manager.dart';
import 'attachment_menu.dart';

class NetChatPage extends StatefulWidget {
  final String userName;
  final RoomInfo roomInfo;

  const NetChatPage({
    super.key,
    required this.userName,
    required this.roomInfo,
    required this.gameFactory,
  });

  final GameLaunchFactory gameFactory;

  @override
  State<NetChatPage> createState() => _NetChatPageState();
}

class _NetChatPageState extends State<NetChatPage> {
  late final NetManager _manager;
  final ChatTheme _theme = ChatTheme.light;
  GameLaunch? _game;
  Route<void>? _gameRoute;
  bool _gameEventScheduled = false;

  @override
  void initState() {
    super.initState();
    _manager = NetManager(userName: widget.userName, roomInfo: widget.roomInfo);
  }

  void _gameChanged() {
    if (_gameEventScheduled || !mounted) return;
    _gameEventScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _gameEventScheduled = false;
      if (!mounted) return;
      final game = _game;
      if (game == null) return;
      if (game.engine.ended.value) {
        if (_gameRoute != null) {
          final navigator = Navigator.of(context);
          final chatRoute = ModalRoute.of(context);
          navigator.popUntil(
            (route) => route == _gameRoute || route == chatRoute,
          );
          if (_gameRoute!.isCurrent) navigator.pop();
        } else {
          _releaseGame(game);
        }
        return;
      }
      if (_gameRoute != null || !game.engine.readyToOpen.value) return;
      final route = MaterialPageRoute<void>(builder: (_) => game.buildPage());
      _gameRoute = route;
      await Navigator.of(context).push(route);
      game.engine.finish();
      await route.completed;
      if (!mounted) return;
      _gameRoute = null;
      _releaseGame(game);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _releaseGame(GameLaunch game) {
    game.engine.readyToOpen.removeListener(_gameChanged);
    game.engine.ended.removeListener(_gameChanged);
    if (identical(_game, game)) _game = null;
    game.dispose();
  }

  @override
  void dispose() {
    if (_game case final game?) _releaseGame(game);
    _manager.dispose();
    super.dispose();
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
        onPressed: _manager.networkEngine.leavePage,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<RoomSession>(
            valueListenable: _manager.networkEngine.roomSession,
            builder: (_, __, ___) => Text(
              _manager.networkEngine.roomName,
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
          Row(
            children: [
              _statusDot(),
              ValueListenableBuilder<RoomSession>(
                valueListenable: _manager.networkEngine.roomSession,
                builder: (_, session, __) => Text(
                  ' · ${session.count} ${S.members}',
                  style: TextStyle(color: _theme.systemTextColor, fontSize: 11),
                ),
              ),
            ],
          ),
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
      valueListenable: _manager.networkEngine.identityNotifier,
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

  Widget _buildBody() {
    return Column(
      children: [
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        ValueListenableBuilder<RoomSession>(
          valueListenable: _manager.networkEngine.roomSession,
          builder: (_, session, __) => session.game == 0
              ? const SizedBox.shrink()
              : PinnedRoomCard(child: _gameCard(session)),
        ),
        Expanded(
          child: ValueListenableBuilder<RoomSession>(
            valueListenable: _manager.networkEngine.roomSession,
            builder: (_, session, __) => MessageList(
              networkEngine: _manager.networkEngine,
              theme: _theme,
              topPadding: session.game == 0
                  ? MediaQuery.paddingOf(context).top + kToolbarHeight + 4
                  : 4,
            ),
          ),
        ),
        MessageInput(
          networkEngine: _manager.networkEngine,
          theme: _theme,
          onAttachmentTap: _showAttachmentMenu,
        ),
      ],
    );
  }

  void _showAttachmentMenu() {
    AttachmentMenu.show(
      context: context,
      onImagePick: _pickImage,
      onFilePick: _pickFile,
    );
  }

  Widget _gameCard(RoomSession session) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ListTile(
        leading: const Icon(Icons.sports_esports_outlined),
        title: Text(S.roomTypeString(session.gameName)),

        trailing: Text(S.joinGame),
        onTap: _requestPlay,
      ),
    );
  }

  void _requestPlay() {
    final room = _manager.networkEngine;
    final type = room.roomSession.value.game;
    if (room.identity == 0 || _gameRoute != null || type <= 0) {
      return;
    }
    if (_game case final previous?) _releaseGame(previous);
    final game = widget.gameFactory(room);
    if (game == null) return;
    _game = game;
    game.engine.readyToOpen.addListener(_gameChanged);
    game.engine.ended.addListener(_gameChanged);
    game.engine.start();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) await _sendImageFile(pickedFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.selectImageFailed}: $e')));
      }
    }
  }

  Future<void> _sendImageFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();

      // 计算 BlurHash（忽略错误，不影响发送）
      String? blurHash;
      try {
        final (pixels, w, h) = await BlurHash.pixelsFromBytes(bytes);
        blurHash = BlurHash.encode(pixels, w, h);
      } catch (_) {}

      _manager.networkEngine.sendImageMessage(
        base64Encode(bytes),
        fileName: file.name,
        blurHash: blurHash,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${S.sendImageFailed}: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file != null) {
        final fileBytes = await file.readAsBytes();
        _manager.networkEngine.sendFileMessage(
          file.name,
          fileBytes.length,
          base64Encode(fileBytes),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${S.selectFileFailed}: $e')));
      }
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
                onPressed: () => Navigator.pop(context),
                child: Text(S.cancel),
              ),
              TextButton(
                onPressed: () {
                  _manager.networkEngine.messageList.clear();
                  Navigator.pop(context);
                },
                child: Text(
                  S.confirm,
                  style: const TextStyle(color: Colors.red),
                ),
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
