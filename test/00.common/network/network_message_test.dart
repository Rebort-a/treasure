import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:treasure/00.common/network/network_message.dart';

/// 网络消息层单测：覆盖解析健壮性（1.1 可空改造）与 XOR 加密往返。
/// 纯逻辑、无需真实 socket。
void main() {
  group('NetworkMessage.fromJson', () {
    test('解析合法消息', () {
      final msg = NetworkMessage.fromJson({
        'id': 5,
        'type': MessageType.text.index,
        'source': 'alice',
        'content': 'hello',
      });
      expect(msg, isNotNull);
      expect(msg!.id, 5);
      expect(msg.type, MessageType.text);
      expect(msg.source, 'alice');
      expect(msg.content, 'hello');
    });

    test('type 越界返回 null（不 RangeError）', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'type': 9999,
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull, reason: '越界 type 应返回 null 而非崩溃');
    });

    test('type 负数返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'type': -1,
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull);
    });

    test('type 非 int 返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'type': 'text',
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull);
    });

    test('id 非 int 返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': '5',
        'type': MessageType.text.index,
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull);
    });

    test('负数 id 返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': -1,
        'type': MessageType.text.index,
      });
      expect(msg, isNull);
    });

    test('可选字段类型错误返回 null（不抛 TypeError）', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'type': MessageType.text.index,
        'source': 123,
        'timestamp': 'now',
      });
      expect(msg, isNull);
    });

    test('source/content 缺失回退空串（不崩溃）', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'type': MessageType.text.index,
      });
      expect(msg, isNotNull);
      expect(msg!.source, '');
      expect(msg.content, '');
    });
  });

  group('NetworkMessage.fromJsonString', () {
    test('合法 JSON 解析', () {
      final json = jsonEncode({
        'id': 2,
        'type': MessageType.action.index,
        'source': 'bob',
        'content': 'move',
        'messageId': 'm1',
      });
      final msg = NetworkMessage.fromJsonString(json);
      expect(msg, isNotNull);
      expect(msg!.messageId, 'm1');
    });

    test('畸形 JSON 返回 null（不抛异常）', () {
      final msg = NetworkMessage.fromJsonString('not a json {{{');
      expect(msg, isNull);
    });

    test('非 Map 类型（List）返回 null', () {
      final msg = NetworkMessage.fromJsonString('[1,2,3]');
      expect(msg, isNull);
    });
  });

  group('XOR 加密与传输往返', () {
    test('xorCrypt 空密钥返回原数据', () {
      const data = [1, 2, 3, 250, 255];
      expect(NetworkMessage.xorCrypt(data, ''), data);
    });

    test('xorCrypt 加解密往返（对称）', () {
      const key = 'secretkey';
      const data = [72, 101, 108, 108, 111, 0, 255, 128];
      final encrypted = NetworkMessage.xorCrypt(data, key);
      expect(encrypted, isNot(equals(data)));
      final decrypted = NetworkMessage.xorCrypt(encrypted, key);
      expect(decrypted, equals(data));
    });

    test('toSocketData / fromSocketData 往返（无密钥）', () {
      final original = NetworkMessage(
        id: 7,
        type: MessageType.image,
        source: 'cam',
        content: '{"data":"abc"}',
      );
      final wire = original.toSocketData();
      final restored = NetworkMessage.fromSocketData(wire);
      expect(restored, isNotNull);
      expect(restored!.id, 7);
      expect(restored.type, MessageType.image);
      expect(restored.source, 'cam');
      expect(restored.content, '{"data":"abc"}');
    });

    test('toSocketData / fromSocketData 往返（带密钥）', () {
      const key = 'room-key-123';
      final original = NetworkMessage(
        id: 3,
        type: MessageType.file,
        source: 'host',
        content: '{"name":"a.txt","size":10,"data":"QQ=="}',
      );
      final wire = original.toSocketData(encryptionKey: key);
      // 密文不应等于明文
      final plain = utf8.encode(original.toJsonString());
      expect(wire, isNot(equals(plain)));
      final restored = NetworkMessage.fromSocketData(wire, encryptionKey: key);
      expect(restored, isNotNull);
      expect(restored!.id, 3);
      expect(restored.type, MessageType.file);
      expect(restored.content, '{"name":"a.txt","size":10,"data":"QQ=="}');
    });

    test('密钥不匹配时解不出合法消息', () {
      final original = NetworkMessage(
        id: 1,
        type: MessageType.text,
        source: 'a',
        content: 'hi',
      );
      final wire = original.toSocketData(encryptionKey: 'key1');
      final restored = NetworkMessage.fromSocketData(
        wire,
        encryptionKey: 'key2',
      );
      expect(restored, isNull, reason: '密钥不匹配应解为乱码而非合法消息');
    });
  });

  group('ACK 与 messageId', () {
    test('ack 工厂构造正确', () {
      final ack = NetworkMessage.ack('msg-42', 7);
      expect(ack.id, 7);
      expect(ack.type, MessageType.ack);
      expect(ack.content, 'msg-42');
    });

    test('ensureMessageId 为需 ACK 的类型生成 id', () {
      final msg = NetworkMessage(
        id: 1,
        type: MessageType.action,
        source: 'a',
        content: 'x',
      );
      expect(msg.messageId, isNull);
      msg.ensureMessageId();
      expect(msg.messageId, isNotNull);
    });

    test('ensureMessageId 不为非 ACK 类型生成 id', () {
      final msg = NetworkMessage(
        id: 1,
        type: MessageType.text,
        source: 'a',
        content: 'x',
      );
      msg.ensureMessageId();
      expect(msg.messageId, isNull);
    });

    test('生成的 messageId 格式合法', () {
      final msg = NetworkMessage(
        id: 1,
        type: MessageType.action,
        source: 'a',
        content: 'x',
      )..ensureMessageId();
      expect(
        msg.messageId,
        matches(RegExp(r'^[0-9a-z]+-[0-9a-z]+$')),
        reason: '格式应为 <base36 时间戳>-<base36 随机>',
      );
    });
  });
}
