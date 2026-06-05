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

  NetworkMessage({
    required this.id,
    required this.type,
    required this.source,
    required this.content,
    this.messageId,
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

  factory NetworkMessage.fromJson(Map<String, dynamic> json) {
    return NetworkMessage(
      id: json['id'],
      type: MessageType.values[json['type']],
      source: json['source'],
      content: json['content'],
      messageId: json['messageId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'source': source,
      'content': content,
      if (messageId != null) 'messageId': messageId,
    };
  }

  factory NetworkMessage.fromJsonString(String data) {
    return NetworkMessage.fromJson(jsonDecode(data));
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory NetworkMessage.fromSocketData(
    List<int> data, {
    String? encryptionKey,
  }) {
    final decrypted =
        encryptionKey != null ? xorCrypt(data, encryptionKey) : data;
    return NetworkMessage.fromJsonString(utf8.decode(decrypted));
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
