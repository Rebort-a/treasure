import 'dart:convert';

enum MessageType {
  // 发现与握手
  broadcast,
  connect,
  accept,

  // 房间事件与通知
  notify,

  // 聊天信息
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
  exit,
  // 追加类型以保持既有消息类型索引不变。
  ack,
  reject,
  cancelSearch,
}

/// 入局确认与传输 ACK 分离：只有应用层状态机才能接受或撤销一次邀请。
enum MatchConfirmationPhase { accept, commit, ready, start, joined, abort }

class MatchConfirmation {
  final MatchConfirmationPhase phase;
  final String offerId;

  const MatchConfirmation(this.phase, this.offerId);

  String get content => '${phase.name}:$offerId';

  static MatchConfirmation? tryParse(String content) {
    final separator = content.indexOf(':');
    if (separator <= 0 || separator == content.length - 1) return null;
    for (final phase in MatchConfirmationPhase.values) {
      if (phase.name == content.substring(0, separator)) {
        return MatchConfirmation(phase, content.substring(separator + 1));
      }
    }
    return null;
  }
}

enum NoticeType {
  join(1),
  left(2),
  close(3),
  search(4);

  const NoticeType(this.code);

  final int code;

  static NoticeType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// 服务端房间通知；成员通知附带成员身份，供房间成员表和对局逻辑使用。
class RoomNotification {
  final NoticeType type;
  final int? memberId;
  final String? memberName;

  const RoomNotification({required this.type, this.memberId, this.memberName});

  String get content {
    final memberRequired = type != NoticeType.close;
    if (memberRequired &&
        (memberId == null ||
            memberId! <= 0 ||
            memberName == null ||
            memberName!.trim().isEmpty)) {
      throw ArgumentError('Member notifications require a valid member');
    }
    if (!memberRequired && (memberId != null || memberName != null)) {
      throw ArgumentError('Room-close notifications cannot identify a member');
    }
    return jsonEncode({
      'event': type.code,
      if (memberId != null) 'memberId': memberId,
      if (memberName != null) 'name': memberName,
    });
  }

  static RoomNotification? tryFromContent(String content) {
    try {
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) return null;
      final code = data['event'];
      if (code is! int) return null;
      final type = NoticeType.fromCode(code);
      if (type == null) return null;
      final memberId = data['memberId'];
      final memberName = data['name'];
      final memberRequired = type != NoticeType.close;
      if (memberRequired &&
          (memberId is! int ||
              memberId <= 0 ||
              memberName is! String ||
              memberName.trim().isEmpty)) {
        return null;
      }
      if (!memberRequired && (memberId != null || memberName != null)) {
        return null;
      }
      return RoomNotification(
        type: type,
        memberId: memberId as int?,
        memberName: memberName as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class NetworkMessage {
  /// 发送者身份，0 仅供服务器使用；成员事件的主体放在 content 中。
  int id;
  MessageType type;
  String source;
  String content;
  int timestamp;

  /// 私聊只指定对方；服务器先向发送者回环，再发给对方。
  final int? recipientId;

  /// 指定群体消息包含所有对局玩家，通常也包含自己。
  final Set<int>? recipientIds;

  /// 需要可靠投递的局内消息标识；同一消息重发时必须保持不变。
  final String? messageId;

  /// 对局归属，与单条消息 ID 不同；实时中途加入和发布者切换都保持此值。
  final String? gameId;

  NetworkMessage({
    required this.id,
    required this.type,
    required this.source,
    required this.content,
    required this.timestamp,
    this.recipientId,
    Set<int>? recipientIds,
    this.messageId,
    this.gameId,
  }) : recipientIds = recipientIds == null
           ? null
           : Set.unmodifiable(recipientIds);

  bool get isRoomMessage => recipientId == null && recipientIds == null;
  bool get isPrivateMessage => recipientId != null && recipientIds == null;
  bool get isGroupMessage => recipientIds != null && recipientId == null;

  /// search 是可重复发起的发现请求；ACK 自身不重发，房间聊天也不重发。
  bool get needsAck => switch (type) {
    MessageType.match ||
    MessageType.confirm ||
    MessageType.reject ||
    MessageType.publish ||
    MessageType.resource ||
    MessageType.sync ||
    MessageType.action ||
    MessageType.exit => true,
    MessageType.text => !isRoomMessage,
    _ => false,
  };

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
      MessageType.match ||
      MessageType.confirm ||
      MessageType.reject ||
      MessageType.ack => isPrivateMessage,
      MessageType.publish || MessageType.sync => isGroupMessage,
      MessageType.resource ||
      MessageType.action ||
      MessageType.exit => isPrivateMessage || isGroupMessage,
      MessageType.text => true,
      MessageType.connect => isRoomMessage,
      MessageType.cancelSearch => isRoomMessage,
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
    final target = json['recipientId'];
    final targets = json['recipientIds'];
    final messageId = json['messageId'];
    final gameId = json['gameId'];
    if ((source != null && source is! String) ||
        (content != null && content is! String) ||
        timestamp is! int ||
        (messageId != null &&
            (messageId is! String ||
                messageId.isEmpty ||
                messageId.length > 128)) ||
        (gameId != null &&
            (gameId is! String || gameId.isEmpty || gameId.length > 128)) ||
        (target != null && (target is! int || target <= 0)) ||
        (targets != null &&
            (targets is! List || targets.any((id) => id is! int || id <= 0)))) {
      return null;
    }
    if (typeIndex == MessageType.notify.index &&
        (content is! String ||
            RoomNotification.tryFromContent(content) == null)) {
      return null;
    }
    final message = NetworkMessage(
      id: id,
      type: MessageType.values[typeIndex],
      source: source as String? ?? '',
      content: content as String? ?? '',
      timestamp: timestamp,
      recipientId: target as int?,
      recipientIds: targets == null ? null : Set<int>.from(targets as List),
      messageId: messageId as String?,
      gameId: gameId as String?,
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
      'timestamp': timestamp,
      'route': isRoomMessage
          ? 'room'
          : isPrivateMessage
          ? 'private'
          : 'group',
      if (recipientId != null) 'recipientId': recipientId,
      if (recipientIds != null) 'recipientIds': recipientIds!.toList(),
      if (messageId != null) 'messageId': messageId,
      if (gameId != null) 'gameId': gameId,
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
    required String encryptionKey,
  }) {
    final decrypted = xorCrypt(data, encryptionKey);
    return NetworkMessage.fromJsonString(
      utf8.decode(decrypted, allowMalformed: true),
    );
  }

  static NetworkMessage? fromPlainSocketData(List<int> data) {
    return NetworkMessage.fromJsonString(
      utf8.decode(data, allowMalformed: true),
    );
  }

  List<int> toSocketData({required String encryptionKey}) {
    final encoded = utf8.encode(toJsonString());
    return xorCrypt(encoded, encryptionKey);
  }

  List<int> toPlainSocketData() {
    return utf8.encode(toJsonString());
  }

  // ==================== XOR 流加密 ====================

  /// XOR 加解密（对称运算，加密和解密使用同一函数）
  static List<int> xorCrypt(List<int> data, String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    final keyBytes = utf8.encode(key);
    final result = List<int>.filled(data.length, 0);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }
    return result;
  }
}
