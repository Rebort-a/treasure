import '../network/network_message.dart';

/// 聊天消息类型
enum ChatMessageType { text, image, file, emoji, system }

/// 聊天消息模型 - 用于 UI 展示
class ChatMessage {
  final String id;
  final String senderName;
  final int senderId;
  final ChatMessageType type;
  final String content;
  final int timestamp;
  final bool isMe;
  final bool isSystem;
  final String? imagePath;
  final String? fileName;
  final int? fileSize;

  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderId,
    required this.type,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.isSystem = false,
    this.imagePath,
    this.fileName,
    this.fileSize,
  });

  /// 从 NetworkMessage 创建
  factory ChatMessage.fromNetworkMessage(
    NetworkMessage message,
    int localIdentity,
    String localUserName,
  ) {
    final isMe =
        message.id == localIdentity && message.source == localUserName;
    final isSystem = message.type == MessageType.notify;

    ChatMessageType type;
    switch (message.type) {
      case MessageType.image:
        type = ChatMessageType.image;
        break;
      case MessageType.file:
        type = ChatMessageType.file;
        break;
      case MessageType.emoji:
        type = ChatMessageType.emoji;
        break;
      case MessageType.notify:
        type = ChatMessageType.system;
        break;
      default:
        type = ChatMessageType.text;
    }

    return ChatMessage(
      id: message.messageId ?? '${message.id}_${message.timestamp ?? 0}',
      senderName: message.source,
      senderId: message.id,
      type: type,
      content: message.content,
      timestamp: message.timestamp ?? DateTime.now().millisecondsSinceEpoch,
      isMe: isMe,
      isSystem: isSystem,
    );
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 格式化时间
  static String formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化日期分隔符
  static String formatDateSeparator(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);
    if (messageDate == today) return '今天';
    if (messageDate == today.subtract(const Duration(days: 1))) return '昨天';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// 是否需要日期分隔符
  static bool needsDateSeparator(ChatMessage current, ChatMessage? previous) {
    if (previous == null) return true;
    final a = DateTime.fromMillisecondsSinceEpoch(current.timestamp);
    final b = DateTime.fromMillisecondsSinceEpoch(previous.timestamp);
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }

  /// 是否需要显示头像
  static bool needsAvatar(ChatMessage current, ChatMessage? previous) {
    if (previous == null) return true;
    if (current.senderId != previous.senderId) return true;
    return current.timestamp - previous.timestamp > 5 * 60 * 1000;
  }

  /// 获取头像首字母
  static String getAvatarLetter(String name) {
    if (name.isEmpty) return '?';
    final runes = name.runes;
    if (runes.isNotEmpty) {
      final lastChar = String.fromCharCode(runes.last);
      if (RegExp(r'[一-龥]').hasMatch(lastChar)) return lastChar;
    }
    return name.substring(0, 1).toUpperCase();
  }

  /// 根据用户名生成头像颜色
  static int getAvatarColor(String name) {
    const colors = [
      0xFF4CAF50, 0xFF2196F3, 0xFFFF9800, 0xFF9C27B0,
      0xFFE91E63, 0xFF00BCD4, 0xFF795548, 0xFF607D8B,
    ];
    int hash = 0;
    for (var rune in name.runes) {
      hash = (hash * 31 + rune) & 0xFFFFFFFF;
    }
    return colors[hash.abs() % colors.length];
  }
}
