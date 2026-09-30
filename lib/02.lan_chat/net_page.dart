import 'dart:convert';
import 'dart:ui';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import '../00.common/network/client/network_engine.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/style/chat_theme.dart';
import '../00.common/tool/blur_hash.dart';

import 'net_manager.dart';
import 'attachment_menu.dart';

class NetChatPage extends StatefulWidget {
  final NetworkEngine room;
  final String gameName;
  final bool ignoreBack;

  NetChatPage({
    super.key,
    required this.room,
    this.gameName = '',
    this.onMatched,
    this.ignoreBack = false,
  }) {
    if (!room.isJoined) {
      throw StateError('Room authentication has not completed');
    }
  }

  final Future<void> Function(BuildContext)? onMatched;

  @override
  State<NetChatPage> createState() => _NetChatPageState();
}

class _NetChatPageState extends State<NetChatPage> {
  late final NetManager _manager;
  final ChatTheme _theme = ChatTheme.light;
  bool _openingGame = false;

  @override
  void initState() {
    super.initState();
    _manager = NetManager(room: widget.room);
    widget.room.matchPhase.addListener(_matchChanged);
  }

  /// 匹配结果由房间保留，页面在导航时创建并自行接管游戏生命周期。
  void _matchChanged() {
    if (!mounted ||
        _openingGame ||
        widget.room.matchPhase.value != RoomMatchPhase.matched) {
      return;
    }
    _openingGame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.room.matchPhase.value != RoomMatchPhase.matched) {
        _openingGame = false;
        return;
      }
      final onMatched = widget.onMatched;
      if (onMatched == null) {
        widget.room.cancelMatching();
        _openingGame = false;
        return;
      }
      widget.room.openMatchedGame();
      try {
        await onMatched(context);
      } finally {
        if (mounted) setState(() => _openingGame = false);
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    widget.room.matchPhase.removeListener(_matchChanged);
    widget.room.cancelMatching();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.ignoreBack,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || widget.ignoreBack) return;
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
      final hasGame = widget.room.roomType != 0 && widget.gameName.isNotEmpty;
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
              channel: widget.room,
              theme: _theme,
              topPadding: showStatus || hasGame
                  ? 4
                  : MediaQuery.paddingOf(context).top + kToolbarHeight + 4,
            ),
          ),
          MessageInput(
            channel: widget.room,
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
      onImagePick: _pickImage,
      onFilePick: _pickFile,
    );
  }

  Widget _gameCard() {
    return ValueListenableBuilder<RoomMatchPhase>(
      valueListenable: widget.room.matchPhase,
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
            title: Text(S.roomTypeString(widget.gameName)),
            subtitle: matching ? Text(S.matching) : null,
            trailing: TextButton(
              onPressed: pending
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
        room.matchPhase.value != RoomMatchPhase.idle ||
        type <= 0 ||
        widget.gameName.isEmpty) {
      return;
    }
    room.startMatching();
  }

  void _cancelMatch() {
    if (_manager.room.matchPhase.value != RoomMatchPhase.idle) {
      _manager.room.cancelMatching();
      return;
    }
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

      _manager.room.sendImageMessage(
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
        _manager.room.sendFileMessage(
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
                onPressed: () {
                  _manager.room.messageList.clear();
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
