import 'dart:convert';
import 'dart:math';

enum RoomState { start, stop }

class RoomInfo {
  static const int chatType = 0;
  final String name;
  final int type;
  final String address;
  final int port;
  final String? encryptionKey;
  final bool hasPassword;

  /// 仅用于连接握手，不参与房间信息的序列化或广播。
  final String? password;
  final int count;

  RoomInfo({
    required this.name,
    required this.type,
    required this.address,
    required this.port,
    this.encryptionKey,
    this.hasPassword = false,
    this.password,
    this.count = 0,
  });

  RoomInfo withPassword(String? value) => RoomInfo(
    name: name,
    type: type,
    address: address,
    port: port,
    encryptionKey: encryptionKey,
    hasPassword: hasPassword,
    password: value,
    count: count,
  );

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'address': address,
      'port': port,
      if (encryptionKey != null) 'key': encryptionKey,
      'hasPassword': hasPassword,
      'count': count,
    };
  }

  static String getNameFromJson(Map<String, dynamic> json) {
    return json['name'] as String;
  }

  static int getTypeFromJson(Map<String, dynamic> json) {
    return json['type'] as int;
  }

  static String getAddressFromJson(Map<String, dynamic> json) {
    return json['address'] as String;
  }

  static int getPortFromJson(Map<String, dynamic> json) {
    return json['port'] as int;
  }

  static String? getKeyFromJson(Map<String, dynamic> json) {
    return json['key'] as String?;
  }

  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      name: getNameFromJson(json),
      type: getTypeFromJson(json),
      address: getAddressFromJson(json),
      port: getPortFromJson(json),
      encryptionKey: getKeyFromJson(json),
      hasPassword: json['hasPassword'] == true,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  static RoomState getOperationFromJson(Map<String, dynamic> json) {
    return RoomState.values[json['operation'] as int];
  }

  static Map<String, dynamic> configToJson(
    int port,
    int type,
    RoomState operation, {
    String? encryptionKey,
    bool hasPassword = false,
    int count = 0,
  }) {
    return {
      'port': port,
      'type': type,
      'operation': operation.index,
      if (encryptionKey != null) 'key': encryptionKey,
      'hasPassword': hasPassword,
      'count': count,
    };
  }

  static String configToJsonString(
    int port,
    int type,
    RoomState operation, {
    String? encryptionKey,
    bool hasPassword = false,
    int count = 0,
  }) {
    return jsonEncode(
      configToJson(
        port,
        type,
        operation,
        encryptionKey: encryptionKey,
        hasPassword: hasPassword,
        count: count,
      ),
    );
  }

  /// 生成 16 字节随机加密密钥（hex 编码为 32 字符）
  static String generateEncryptionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
