import 'dart:convert';

enum MessageType {
  // 系统信息
  broadcast,
  accept,

  // 聊天信息
  notify,
  text,
  image,
  file,
  emoji,
  typing,
  roomControl,

  // 游戏信息
  search,
  match,
  resource,
  sync,
  action,
  exit,
}

/// 自动通知只传固定编码，接收端展示时再按本地语言生成文案。
enum RoomNotice {
  joinedRoom(1),
  leftRoom(2),
  matchingPlayers(3),
  leftGame(4);

  const RoomNotice(this.code);

  /// 显式指定协议编码，调整枚举顺序不会改变网络含义。
  final int code;

  String get content => code.toString();

  static RoomNotice? fromContent(String content) {
    for (final notice in values) {
      if (notice.content == content) return notice;
    }
    return null;
  }
}

class NetworkMessage {
  int id;
  MessageType type;
  String source;
  String content;
  int? timestamp;
  String? replyToId;

  /// 服务器转发的目标客户端；为空时广播，由接收方按会话标识区分消息。
  int? targetId;

  /// 标识一次游戏会话，而非单条消息或回执；为空时表示房间消息。
  String? sessionId;

  NetworkMessage({
    required this.id,
    required this.type,
    required this.source,
    required this.content,
    this.timestamp,
    this.replyToId,
    this.targetId,
    this.sessionId,
  });

  /// 解析消息；字段类型、取值或通知编码不合法时返回 null，由调用方丢弃。
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
    final timestamp = json['timestamp'];
    final replyToId = json['replyToId'];
    final targetId = json['targetId'];
    final sessionId = json['sessionId'];
    if ((source != null && source is! String) ||
        (content != null && content is! String) ||
        (timestamp != null && timestamp is! int) ||
        (replyToId != null && replyToId is! String) ||
        (sessionId != null && sessionId is! String) ||
        (targetId != null && (targetId is! int || targetId <= 0))) {
      return null;
    }
    if (typeIndex == MessageType.notify.index &&
        (content is! String || RoomNotice.fromContent(content) == null)) {
      return null;
    }
    return NetworkMessage(
      id: id,
      type: MessageType.values[typeIndex],
      source: source as String? ?? '',
      content: content as String? ?? '',
      timestamp: timestamp as int?,
      replyToId: replyToId as String?,
      targetId: targetId as int?,
      sessionId: sessionId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'source': source,
      'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (replyToId != null) 'replyToId': replyToId,
      if (targetId != null) 'targetId': targetId,
      if (sessionId != null) 'sessionId': sessionId,
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
