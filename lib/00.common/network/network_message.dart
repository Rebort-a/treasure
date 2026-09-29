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

  // 游戏信息
  search,
  match,
  confirm,
  publish,
  resource,
  sync,
  action,
  gameExit,
  memberJoined,
  memberLeft,
  roomClosed,
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
  /// 发送者身份，0 仅供服务器使用；成员事件的主体放在 content 中。
  int id;
  MessageType type;
  String source;
  String content;
  int? timestamp;
  String? replyToId;

  /// 私聊只指定对方；服务器先向发送者回环，再发给对方。
  final int? recipientId;

  /// 指定群体消息包含所有对局玩家，通常也包含自己。
  final Set<int>? recipientIds;

  NetworkMessage({
    required this.id,
    required this.type,
    required this.source,
    required this.content,
    this.timestamp,
    this.replyToId,
    this.recipientId,
    Set<int>? recipientIds,
  }) : recipientIds = recipientIds == null
           ? null
           : Set.unmodifiable(recipientIds);

  bool get isRoomMessage => recipientId == null && recipientIds == null;
  bool get isPrivateMessage => recipientId != null && recipientIds == null;
  bool get isGroupMessage => recipientIds != null && recipientId == null;

  /// 游戏消息必须指定非空收件集合；空集合绝不能退化为房间广播。
  bool get hasValidRoute {
    final recipients = recipientIds;
    if ((recipientId != null && recipientId! <= 0) ||
        (recipientId != null && recipients != null) ||
        (recipients != null &&
            (recipients.isEmpty || recipients.any((id) => id <= 0)))) {
      return false;
    }
    return switch (type) {
      MessageType.match || MessageType.confirm => isPrivateMessage,
      MessageType.publish || MessageType.sync => isGroupMessage,
      MessageType.resource ||
      MessageType.action ||
      MessageType.gameExit => isPrivateMessage || isGroupMessage,
      MessageType.text => true,
      _ => isRoomMessage,
    };
  }

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
    final target = json['recipientId'];
    final targets = json['recipientIds'];
    if ((source != null && source is! String) ||
        (content != null && content is! String) ||
        (timestamp != null && timestamp is! int) ||
        (replyToId != null && replyToId is! String) ||
        (target != null && (target is! int || target <= 0)) ||
        (targets != null &&
            (targets is! List || targets.any((id) => id is! int || id <= 0)))) {
      return null;
    }
    if (typeIndex == MessageType.notify.index &&
        (content is! String || RoomNotice.fromContent(content) == null)) {
      return null;
    }
    final message = NetworkMessage(
      id: id,
      type: MessageType.values[typeIndex],
      source: source as String? ?? '',
      content: content as String? ?? '',
      timestamp: timestamp as int?,
      replyToId: replyToId as String?,
      recipientId: target as int?,
      recipientIds: targets == null ? null : Set<int>.from(targets as List),
    );
    final route = message.isRoomMessage
        ? 'room'
        : message.isPrivateMessage
        ? 'private'
        : 'group';
    if (json['route'] != route) {
      return null;
    }
    return message.hasValidRoute ? message : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'source': source,
      'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (replyToId != null) 'replyToId': replyToId,
      'route': isRoomMessage
          ? 'room'
          : isPrivateMessage
          ? 'private'
          : 'group',
      if (recipientId != null) 'recipientId': recipientId,
      if (recipientIds != null) 'recipientIds': recipientIds!.toList(),
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
