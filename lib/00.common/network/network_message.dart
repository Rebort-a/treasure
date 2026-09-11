import 'dart:convert';
import 'dart:math';

enum MessageType {
  // 系统信息
  broadcast,
  accept,
  ack,

  // 游戏信息
  search,
  match,
  resource,
  sync,
  action,
  exit,

  // 聊天信息
  notify,
  text,
  image,
  file,
  emoji,
  typing,
}

/// 需要 ACK 确认的游戏关键消息类型
const Set<MessageType> ackRequiredTypes = {
  MessageType.search,
  MessageType.match,
  MessageType.resource,
  MessageType.sync,
  MessageType.action,
  MessageType.exit,
};

class NetworkMessage {
  int id;
  MessageType type;
  String source;
  String content;
  String? messageId;
  int? timestamp;
  String? replyToId;

  NetworkMessage({
    required this.id,
    required this.type,
    required this.source,
    required this.content,
    this.messageId,
    this.timestamp,
    this.replyToId,
  });

  /// 为需要 ACK 的消息自动生成唯一 ID
  void ensureMessageId() {
    if (messageId == null && ackRequiredTypes.contains(type)) {
      messageId = _generateId();
    }
  }

  static String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final randomPart = random.nextInt(0xFFFFFF).toRadixString(36);
    return '$timestamp-$randomPart';
  }

  /// 创建 ACK 回复消息
  factory NetworkMessage.ack(String originalMessageId, int clientId) {
    return NetworkMessage(
      id: clientId,
      type: MessageType.ack,
      source: '',
      content: originalMessageId,
    );
  }

  /// 解析消息；type/id 越界或缺失时返回 null（不抛异常，调用方丢弃）
  static NetworkMessage? fromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'];
    if (typeIndex is! int ||
        typeIndex < 0 ||
        typeIndex >= MessageType.values.length) {
      return null;
    }
    final id = json['id'];
    if (id is! int || id < 0) {
      return null;
    }
    final source = json['source'];
    final content = json['content'];
    final messageId = json['messageId'];
    final timestamp = json['timestamp'];
    final replyToId = json['replyToId'];
    if ((source != null && source is! String) ||
        (content != null && content is! String) ||
        (messageId != null && messageId is! String) ||
        (timestamp != null && timestamp is! int) ||
        (replyToId != null && replyToId is! String)) {
      return null;
    }
    return NetworkMessage(
      id: id,
      type: MessageType.values[typeIndex],
      source: source as String? ?? '',
      content: content as String? ?? '',
      messageId: messageId as String?,
      timestamp: timestamp as int?,
      replyToId: replyToId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'source': source,
      'content': content,
      if (messageId != null) 'messageId': messageId,
      if (timestamp != null) 'timestamp': timestamp,
      if (replyToId != null) 'replyToId': replyToId,
    };
  }

  static NetworkMessage? fromJsonString(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return null;
      return NetworkMessage.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  static NetworkMessage? fromSocketData(
    List<int> data, {
    String? encryptionKey,
  }) {
    final decrypted = encryptionKey != null
        ? xorCrypt(data, encryptionKey)
        : data;
    return NetworkMessage.fromJsonString(
      utf8.decode(decrypted, allowMalformed: true),
    );
  }

  List<int> toSocketData({String? encryptionKey}) {
    final encoded = utf8.encode(toJsonString());
    return encryptionKey != null ? xorCrypt(encoded, encryptionKey) : encoded;
  }

  // ==================== XOR 流加密 ====================

  /// XOR 加解密（对称运算，加密和解密使用同一函数）
  static List<int> xorCrypt(List<int> data, String key) {
    if (key.isEmpty) return data;
    final keyBytes = utf8.encode(key);
    final result = List<int>.filled(data.length, 0);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }
    return result;
  }
}
