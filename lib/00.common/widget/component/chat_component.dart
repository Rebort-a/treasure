import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
// ignore: unnecessary_import
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../model/chat_message.dart';
import '../../style/chat_theme.dart';
import '../../../l10n/strings.dart';
import '../blur_hash_image.dart';
import '../../engine/network_engine.dart';
import '../../network/network_message.dart';

/// 现代化消息列表
class MessageList extends StatefulWidget {
  final NetworkEngine networkEngine;
  final ChatTheme theme;

  const MessageList({
    super.key,
    required this.networkEngine,
    this.theme = ChatTheme.light,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  bool _showScrollToBottom = false;
  bool _pendingCheck = false;
  bool _pendingScrollToBottom = false;
  double _lastMaxExtent = 0;

  @override
  void initState() {
    super.initState();
    widget.networkEngine.scrollController.addListener(_onScroll);
    _scheduleScrollToBottomIfNeeded();
  }

  void _onScroll() {
    if (_pendingCheck) return;
    _pendingCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingCheck = false;
      if (!mounted) return;
      final sc = widget.networkEngine.scrollController;
      if (!sc.hasClients) return;
      final maxExtent = sc.position.maxScrollExtent;
      final atBottom = sc.offset >= maxExtent - 100;
      // 图片加载导致 maxScrollExtent 增长时，自动跟随到底部
      if (!_showScrollToBottom && maxExtent > _lastMaxExtent) {
        sc.jumpTo(maxExtent);
      }
      _lastMaxExtent = maxExtent;
      if (atBottom == _showScrollToBottom) {
        setState(() => _showScrollToBottom = !atBottom);
      }
    });
  }

  void _scheduleScrollToBottomIfNeeded() {
    if (_pendingScrollToBottom) return;
    _pendingScrollToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollToBottom = false;
      if (!mounted || _showScrollToBottom) return;
      final sc = widget.networkEngine.scrollController;
      if (!sc.hasClients) return;
      final diff = sc.position.maxScrollExtent - sc.offset;
      if (diff > 1) sc.jumpTo(sc.position.maxScrollExtent);
    });
  }

  void _onImageLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showScrollToBottom) return;
      final sc = widget.networkEngine.scrollController;
      if (!sc.hasClients) return;
      final maxExtent = sc.position.maxScrollExtent;
      if (maxExtent > _lastMaxExtent) {
        sc.jumpTo(maxExtent);
        _lastMaxExtent = maxExtent;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<NetworkMessage>>(
      valueListenable: widget.networkEngine.messageList,
      builder: (context, messages, child) {
        if (!_showScrollToBottom) _scheduleScrollToBottomIfNeeded();
        return Stack(
          children: [
            if (messages.isEmpty) _emptyState() else _messageList(messages),
            if (_showScrollToBottom) _scrollToBottomBtn(),
          ],
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.theme.iconColor.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_rounded,
              size: 40,
              color: widget.theme.iconColor.withAlpha(80),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.typeMessage,
            style: widget.theme.systemTextStyle.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _messageList(List<NetworkMessage> messages) {
    final chatMessages = messages
        .map(
          (m) => ChatMessage.fromNetworkMessage(
            m,
            widget.networkEngine.identity,
            widget.networkEngine.userName,
          ),
        )
        .toList();

    return ListView.builder(
      controller: widget.networkEngine.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
      itemCount: chatMessages.length,
      itemBuilder: (context, index) {
        final msg = chatMessages[index];
        final prev = index > 0 ? chatMessages[index - 1] : null;
        // 找上一条非系统消息作为头像判断依据
        ChatMessage? avatarPrev;
        for (int i = index - 1; i >= 0; i--) {
          if (!chatMessages[i].isSystem) {
            avatarPrev = chatMessages[i];
            break;
          }
        }
        return _buildItem(msg, prev, avatarPrev);
      },
    );
  }

  Widget _scrollToBottomBtn() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: GestureDetector(
        onTap: () {
          final sc = widget.networkEngine.scrollController;
          if (sc.hasClients) {
            sc.jumpTo(sc.position.maxScrollExtent);
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.theme.surfaceColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: widget.theme.iconColor,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    ChatMessage msg,
    ChatMessage? prev,
    ChatMessage? avatarPrev,
  ) {
    if (ChatMessage.needsDateSeparator(msg, prev)) {
      return Column(
        children: [_dateSeparator(msg.timestamp), _bubble(msg, avatarPrev)],
      );
    }
    return _bubble(msg, avatarPrev);
  }

  Widget _dateSeparator(int timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            ChatMessage.formatDateSeparator(timestamp),
            style: widget.theme.dateSeparatorStyle,
          ),
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage msg, ChatMessage? prev) {
    if (msg.isSystem) return _systemMsg(msg);

    final showAvatar = ChatMessage.needsAvatar(msg, prev);
    final showTime =
        showAvatar ||
        (prev != null && msg.timestamp - prev.timestamp > 5 * 60 * 1000);

    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 16 : 3, bottom: 3),
      child: Row(
        mainAxisAlignment: msg.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            showAvatar
                ? _avatar(msg.senderName)
                : SizedBox(width: widget.theme.avatarSize),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showAvatar)
                  Padding(
                    padding: EdgeInsets.only(
                      left: msg.isMe ? 0 : 4,
                      right: msg.isMe ? 4 : 0,
                      bottom: 4,
                    ),
                    child: Text(
                      msg.senderName,
                      textAlign: msg.isMe ? TextAlign.right : TextAlign.left,
                      style: widget.theme.usernameStyle,
                    ),
                  ),
                _content(msg),
                if (showTime)
                  Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      left: msg.isMe ? 0 : 4,
                      right: msg.isMe ? 4 : 0,
                    ),
                    child: Text(
                      ChatMessage.formatTime(msg.timestamp),
                      style: widget.theme.timeTextStyle,
                    ),
                  ),
              ],
            ),
          ),
          if (msg.isMe) ...[
            const SizedBox(width: 8),
            showAvatar
                ? _avatar(msg.senderName)
                : SizedBox(width: widget.theme.avatarSize),
          ],
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final letter = ChatMessage.getAvatarLetter(name);
    final color = ChatTheme.getAvatarColor(name);
    return Container(
      width: widget.theme.avatarSize,
      height: widget.theme.avatarSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.theme.avatarSize * 0.42,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _content(ChatMessage msg) {
    switch (msg.type) {
      case ChatMessageType.text:
        return _textBubble(msg);
      case ChatMessageType.emoji:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(msg.content, style: const TextStyle(fontSize: 48)),
        );
      case ChatMessageType.image:
        return _imageBubble(msg);
      case ChatMessageType.file:
        return _fileBubble(msg);
      case ChatMessageType.system:
        return _systemMsg(msg);
    }
  }

  Widget _textBubble(ChatMessage msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: msg.isMe
          ? widget.theme.selfBubbleDecoration
          : widget.theme.otherBubbleDecoration,
      child: Text(
        msg.content,
        style: msg.isMe
            ? widget.theme.selfTextStyle
            : widget.theme.otherTextStyle,
      ),
    );
  }

  Widget _imageBubble(ChatMessage msg) {
    Widget image;
    String? fileName;
    Uint8List? imageBytes;
    String? blurHash;
    try {
      final json = jsonDecode(msg.content);
      final data = json['data'] as String?;
      fileName = json['name'] as String?;
      blurHash = json['hash'] as String?;
      if (data != null) {
        imageBytes = base64Decode(data);
        if (blurHash != null && imageBytes.isNotEmpty) {
          image = BlurHashImage(
            hash: blurHash,
            imageBytes: imageBytes,
            onLoad: _onImageLoad,
          );
        } else {
          image = Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imgPlaceholder(),
          );
        }
      } else {
        image = _imgPlaceholder();
      }
    } catch (_) {
      try {
        imageBytes = base64Decode(msg.content);
        image = Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imgPlaceholder(),
        );
      } catch (_) {
        image = _imgPlaceholder();
      }
    }

    return GestureDetector(
      onTap: imageBytes != null
          ? () => _openImageViewer(imageBytes!, fileName)
          : null,
      child: Column(
        crossAxisAlignment: msg.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 240),
            decoration: msg.isMe
                ? widget.theme.selfBubbleDecoration
                : widget.theme.otherBubbleDecoration,
            clipBehavior: Clip.antiAlias,
            child: image,
          ),
          if (fileName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                fileName,
                style: widget.theme.timeTextStyle.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 150,
      height: 100,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_rounded, color: Colors.grey[300], size: 32),
          const SizedBox(height: 4),
          Text(
            S.imageLoadFailed,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _fileBubble(ChatMessage msg) {
    String fileName = S.unknownFile;
    int fileSize = 0;
    try {
      final json = jsonDecode(msg.content);
      fileName = json['name'] as String? ?? S.unknownFile;
      fileSize = json['size'] as int? ?? 0;
    } catch (_) {}

    final isMe = msg.isMe;
    final bgColor = isMe
        ? widget.theme.selfBubbleColor.withAlpha(40)
        : widget.theme.otherBubbleColor;

    return GestureDetector(
      onTap: () => _saveFile(msg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isMe
                    ? widget.theme.selfBubbleColor.withAlpha(80)
                    : Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: isMe ? widget.theme.selfTextColor : Colors.blue,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: isMe
                          ? widget.theme.selfTextColor
                          : widget.theme.otherTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fileSize > 0)
                    Text(
                      ChatMessage.formatFileSize(fileSize),
                      style: TextStyle(
                        color: isMe
                            ? widget.theme.selfTextColor.withAlpha(150)
                            : widget.theme.otherTextColor.withAlpha(150),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              color: isMe
                  ? widget.theme.selfTextColor.withAlpha(100)
                  : widget.theme.otherTextColor.withAlpha(100),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(Uint8List bytes, String? fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(bytes: bytes, fileName: fileName),
      ),
    );
  }

  /// 获取平台默认下载目录
  Future<Directory> _getDownloadDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return Directory('${dir.path}${Platform.pathSeparator}downloads');
    }
    String home;
    if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'] ?? '.';
    } else {
      home = Platform.environment['HOME'] ?? '.';
    }
    return Directory('$home${Platform.pathSeparator}Downloads');
  }

  /// 统一路径分隔符
  String _normalizePath(String path) {
    return path
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
  }

  Future<void> _saveFile(ChatMessage msg) async {
    String? base64Data;
    String fileName = 'file';
    try {
      final json = jsonDecode(msg.content);
      fileName = json['name'] as String? ?? 'file';
      base64Data = json['data'] as String?;
    } catch (_) {}

    if (base64Data == null || base64Data.isEmpty) return;

    final bytes = base64Decode(base64Data);

    // 在 await 之前捕获 navigator/messenger，避免跨 async gap 使用 context
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // 弹窗：用户可编辑文件名
    final controller = TextEditingController(text: fileName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.downloading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.savedTo,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: S.file,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.confirm),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final userFileName = controller.text.trim();
    if (userFileName.isEmpty) return;

    // loading
    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dlDir = await _getDownloadDir();
      if (!await dlDir.exists()) await dlDir.create(recursive: true);
      final safeName = userFileName.contains(Platform.pathSeparator)
          ? userFileName.split(Platform.pathSeparator).last
          : userFileName;
      final filePath = '${dlDir.path}${Platform.pathSeparator}$safeName';
      final file = File(_normalizePath(filePath));
      await file.writeAsBytes(bytes);

      navigator.pop(); // 关闭 loading
      messenger.showSnackBar(
        SnackBar(content: Text('${S.savedTo}: ${file.path}')),
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('${S.saveFailed}: $e')));
    }
  }

  Widget _systemMsg(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${msg.senderName} ${msg.content}',
            style: widget.theme.systemTextStyle,
          ),
        ),
      ),
    );
  }
}

/// 现代化消息输入组件
class MessageInput extends StatefulWidget {
  final NetworkEngine networkEngine;
  final ChatTheme theme;
  final VoidCallback? onEmojiTap;
  final VoidCallback? onAttachmentTap;

  const MessageInput({
    super.key,
    required this.networkEngine,
    this.theme = ChatTheme.light,
    this.onEmojiTap,
    this.onAttachmentTap,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.networkEngine.textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.networkEngine.textController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(color: ChatTheme.glassColor),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 表情按钮
                _iconBtn(
                  icon: Icons.emoji_emotions_outlined,
                  onTap: widget.onEmojiTap,
                ),
                // 附件按钮
                _iconBtn(
                  icon: Icons.add_circle_outline_rounded,
                  onTap: widget.onAttachmentTap,
                ),
                const SizedBox(width: 4),
                // 输入框
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      maxHeight: 120,
                    ),
                    decoration: widget.theme.inputDecoration,
                    child: TextField(
                      controller: widget.networkEngine.textController,
                      style: widget.theme.inputTextStyle,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: S.typeMessage,
                        hintStyle: widget.theme.inputHintStyle,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // 发送按钮
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _hasText
                      ? _sendBtn()
                      : _iconBtn(icon: Icons.mic_rounded, onTap: null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, VoidCallback? onTap}) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, color: widget.theme.iconColor, size: 24),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }

  Widget _sendBtn() {
    return GestureDetector(
      onTap: widget.networkEngine.sendInputText,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: widget.theme.sendButtonColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

/// 全屏图片查看页面（支持缩放/平移）
class _ImageViewerPage extends StatelessWidget {
  final Uint8List bytes;
  final String? fileName;

  const _ImageViewerPage({required this.bytes, this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(fileName ?? '', style: const TextStyle(fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
