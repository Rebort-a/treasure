import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../00.common/network/network_room.dart';
import '../00.common/style/chat_theme.dart';
import '../00.common/widget/component/chat_component.dart';
import '../00.common/widget/notifier_navigator.dart';
import '../l10n/strings.dart';
import 'net_manager.dart';
import 'widget/emoji_panel.dart';
import 'widget/attachment_menu.dart';

class NetChatPage extends StatefulWidget {
  final String userName;
  final RoomInfo roomInfo;

  const NetChatPage({
    super.key,
    required this.userName,
    required this.roomInfo,
  });

  @override
  State<NetChatPage> createState() => _NetChatPageState();
}

class _NetChatPageState extends State<NetChatPage> {
  late final NetManager _manager;
  final ChatTheme _theme = ChatTheme.light;
  bool _showEmojiPanel = false;

  @override
  void initState() {
    super.initState();
    _manager = NetManager(userName: widget.userName, roomInfo: widget.roomInfo);
  }

  @override
  void dispose() {
    _manager.leavePage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_showEmojiPanel) {
          setState(() => _showEmojiPanel = false);
        } else {
          _manager.leavePage();
        }
      },
      child: Scaffold(
        backgroundColor: _theme.backgroundColor,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: _theme.surfaceColor,
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
          Text(
            widget.roomInfo.name,
            style: TextStyle(
              color: _theme.otherTextColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
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
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_showEmojiPanel) setState(() => _showEmojiPanel = false);
            },
            child: MessageList(
              networkEngine: _manager.networkEngine,
              theme: _theme,
            ),
          ),
        ),
        MessageInput(
          networkEngine: _manager.networkEngine,
          theme: _theme,
          onEmojiTap: () => setState(() => _showEmojiPanel = !_showEmojiPanel),
          onAttachmentTap: _showAttachmentMenu,
        ),
        if (_showEmojiPanel)
          EmojiPanel(
            onEmojiSelected: (emoji) {
              final tc = _manager.networkEngine.textController;
              final sel = tc.selection;
              final old = tc.text;
              final start = sel.isValid ? sel.start : old.length;
              final end = sel.isValid ? sel.end : old.length;
              tc.value = TextEditingValue(
                text: old.replaceRange(start, end, emoji),
                selection: TextSelection.collapsed(
                  offset: start + emoji.length,
                ),
              );
            },
            backgroundColor: _theme.surfaceColor,
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

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) await _sendImageFile(pickedFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.selectImageFailed}: $e')));
      }
    }
  }

  Future<void> _sendImageFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      _manager.networkEngine.sendImageMessage(
        base64Encode(bytes),
        fileName: filePath.replaceAll('\\', '/').split('/').last,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.sendImageFailed}: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final fileBytes = await File(file.path!).readAsBytes();
          _manager.networkEngine.sendFileMessage(
            file.name,
            file.size,
            base64Encode(fileBytes),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.selectFileFailed}: $e')));
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
