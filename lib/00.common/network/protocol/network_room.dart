import 'dart:convert';
import 'dart:math';

enum RoomState { start, stop }

enum RoomGameMode { none, turn, real }

class RoomInfo {
  final String name;
  final int type;
  final String address;
  final int port;
  final String encryptionKey;
  final bool hasPassword;

  /// 仅用于连接握手，不参与房间信息的序列化或广播。
  final String? password;
  final int count;

  RoomInfo({
    required this.name,
    required this.type,
    required this.address,
    required this.port,
    required String encryptionKey,
    this.hasPassword = false,
    this.password,
    this.count = 0,
  }) : encryptionKey = _requireEncryptionKey(encryptionKey);

  static String _requireEncryptionKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'encryptionKey', 'must not be empty');
    }
    return key;
  }

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
      'key': encryptionKey,
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

  static String getKeyFromJson(Map<String, dynamic> json) {
    final key = json['key'];
    if (key is! String || key.isEmpty) {
      throw const FormatException('Missing or invalid encryption key');
    }
    return key;
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
    required String encryptionKey,
    bool hasPassword = false,
    int count = 0,
  }) {
    return {
      'port': port,
      'type': type,
      'operation': operation.index,
      'key': encryptionKey,
      'hasPassword': hasPassword,
      'count': count,
    };
  }

  static String configToJsonString(
    int port,
    int type,
    RoomState operation, {
    required String encryptionKey,
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
