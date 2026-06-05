import 'dart:convert';
import 'package:flutter/material.dart';

import '../../model/chat_message.dart';
import '../../style/chat_theme.dart';
import '../../../l10n/strings.dart';
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

  @override
  void initState() {
    super.initState();
    widget.networkEngine.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final sc = widget.networkEngine.scrollController;
    if (!sc.hasClients) return;
    final atBottom = sc.offset >= sc.position.maxScrollExtent - 100;
    if (atBottom != !_showScrollToBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<NetworkMessage>>(
      valueListenable: widget.networkEngine.messageList,
      builder: (context, messages, child) {
        return Stack(
          children: [
            if (messages.isEmpty)
              _emptyState()
            else
              _messageList(messages),
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
            child: Icon(Icons.chat_rounded,
                size: 40, color: widget.theme.iconColor.withAlpha(80)),
          ),
          const SizedBox(height: 16),
          Text(S.typeMessage,
              style: widget.theme.systemTextStyle.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _messageList(List<NetworkMessage> messages) {
    final chatMessages = messages
        .map((m) => ChatMessage.fromNetworkMessage(
            m, widget.networkEngine.identity, widget.networkEngine.userName))
        .toList();

    return ListView.builder(
      controller: widget.networkEngine.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          widget.networkEngine.scrollController.animateTo(
            widget.networkEngine.scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
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
          child: Icon(Icons.keyboard_arrow_down_rounded,
              color: widget.theme.iconColor, size: 28),
        ),
      ),
    );
  }

  Widget _buildItem(ChatMessage msg, ChatMessage? prev, ChatMessage? avatarPrev) {
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
            color: Colors.black.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(ChatMessage.formatDateSeparator(timestamp),
              style: widget.theme.dateSeparatorStyle),
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage msg, ChatMessage? prev) {
    if (msg.isSystem) return _systemMsg(msg);

    final showAvatar = ChatMessage.needsAvatar(msg, prev);
    final showTime = showAvatar ||
        (prev != null && msg.timestamp - prev.timestamp > 5 * 60 * 1000);

    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 12 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment:
            msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              crossAxisAlignment:
                  msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAvatar)
                  Padding(
                    padding: EdgeInsets.only(
                        left: msg.isMe ? 0 : 4,
                        right: msg.isMe ? 4 : 0,
                        bottom: 4),
                    child: Text(msg.senderName,
                        textAlign: msg.isMe ? TextAlign.right : TextAlign.left,
                        style: widget.theme.usernameStyle),
                  ),
                _content(msg),
                if (showTime)
                  Padding(
                    padding: EdgeInsets.only(
                        top: 4,
                        left: msg.isMe ? 0 : 4,
                        right: msg.isMe ? 4 : 0),
                    child: Text(ChatMessage.formatTime(msg.timestamp),
                        style: widget.theme.timeTextStyle),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(letter,
            style: TextStyle(
                color: Colors.white,
                fontSize: widget.theme.avatarSize * 0.42,
                fontWeight: FontWeight.w600)),
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
            child: Text(msg.content, style: const TextStyle(fontSize: 48)));
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: msg.isMe
          ? widget.theme.selfBubbleDecoration
          : widget.theme.otherBubbleDecoration,
      child: Text(msg.content,
          style:
              msg.isMe ? widget.theme.selfTextStyle : widget.theme.otherTextStyle),
    );
  }

  Widget _imageBubble(ChatMessage msg) {
    Widget image;
    String? fileName;
    try {
      final json = jsonDecode(msg.content);
      final data = json['data'] as String?;
      fileName = json['name'] as String?;
      if (data != null) {
        image = Image.memory(base64Decode(data),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imgPlaceholder());
      } else {
        image = _imgPlaceholder();
      }
    } catch (_) {
      try {
        image = Image.memory(base64Decode(msg.content), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imgPlaceholder());
      } catch (_) {
        image = _imgPlaceholder();
      }
    }

    return Column(
      crossAxisAlignment:
          msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
            child: Text(fileName,
                style: widget.theme.timeTextStyle.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
      ],
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
          Text(S.imageLoadFailed,
              style: TextStyle(color: Colors.grey[400], fontSize: 11)),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
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
            child: Icon(Icons.insert_drive_file_rounded,
                color: isMe ? widget.theme.selfTextColor : Colors.blue,
                size: 22),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: TextStyle(
                        color: isMe
                            ? widget.theme.selfTextColor
                            : widget.theme.otherTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (fileSize > 0)
                  Text(ChatMessage.formatFileSize(fileSize),
                      style: TextStyle(
                          color: isMe
                              ? widget.theme.selfTextColor.withAlpha(150)
                              : widget.theme.otherTextColor.withAlpha(150),
                          fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemMsg(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('${msg.senderName} ${msg.content}',
              style: widget.theme.systemTextStyle),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        border:
            Border(top: BorderSide(color: widget.theme.dividerColor, width: 0.5)),
      ),
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
            // 附件按钮（有文字时隐藏）
            if (!_hasText)
              _iconBtn(
                icon: Icons.add_circle_outline_rounded,
                onTap: widget.onAttachmentTap,
              ),
            const SizedBox(width: 4),
            // 输入框
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
