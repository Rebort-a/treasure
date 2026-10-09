import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/network/protocol/network_room.dart';
import 'package:treasure/00.common/model/chat_message.dart';

/// 网络消息层单测：覆盖必选时间戳校验、解析健壮性与 XOR 加密往返。
/// 纯逻辑、无需真实 socket。
void main() {
  test('连接认证请求使用空收件集合', () {
    final request = NetworkMessage(
      id: 0,
      type: MessageType.connect,
      source: 'Alice',
      content: jsonEncode({'password': 'secret'}),
      timestamp: 1,
    );
    final decoded = NetworkMessage.fromPlainSocketData(
      request.toPlainSocketData(),
    );
    expect(decoded?.type, MessageType.connect);
    expect(decoded?.source, 'Alice');
    expect(decoded?.isRoomMessage, isTrue);
    expect(jsonDecode(decoded!.content), {'password': 'secret'});
  });

  test('RoomInfo 必须携带非空加密密钥', () {
    final room = RoomInfo(
      name: 'room',
      type: 0,
      address: '127.0.0.1',
      port: 1234,
      encryptionKey: 'room-key',
    );
    expect(room.toJson()['key'], 'room-key');
    expect(
      () => RoomInfo(
        name: 'room',
        type: 0,
        address: '127.0.0.1',
        port: 1234,
        encryptionKey: '',
      ),
      throwsArgumentError,
    );
    expect(
      () => RoomInfo.fromJson({
        'name': 'room',
        'type': 0,
        'address': '127.0.0.1',
        'port': 1234,
      }),
      throwsFormatException,
    );
  });

  test('纯表情和混合文字都以 text 传输并按普通聊天展示', () {
    for (final content in ['🙂', '你好 👨‍👩‍👧‍👦，一起玩吧']) {
      for (final recipients in <Set<int>>[
        {},
        {1, 2},
      ]) {
        final original = NetworkMessage(
          id: 1,
          type: MessageType.text,
          source: 'Alice',
          content: content,
          timestamp: 1,
          recipientIds: recipients,
        );
        final decoded = NetworkMessage.fromJsonString(original.toJsonString());
        expect(decoded, isNotNull);
        expect(decoded!.content, content);
        expect(decoded.type, MessageType.text);
        expect(decoded.recipientIds, recipients);
        expect(
          ChatMessage.fromNetworkMessage(decoded, 2, 'Bob').type,
          ChatMessageType.text,
        );
      }
    }
  });

  test('搜索使用空集合广播，匹配和确认只指定一个成员', () {
    final search = NetworkMessage(
      id: 1,
      type: MessageType.search,
      source: 'Alice',
      content: '',
      timestamp: 1,
    );
    expect(
      NetworkMessage.fromJsonString(search.toJsonString())?.isRoomMessage,
      isTrue,
    );
    for (final type in [MessageType.match, MessageType.confirm]) {
      final message = NetworkMessage(
        id: 1,
        type: type,
        source: 'Alice',
        content: '',
        timestamp: 1,
        recipientIds: {2},
      );
      expect(
        NetworkMessage.fromJsonString(message.toJsonString())?.recipientIds,
        {2},
      );
      expect(
        NetworkMessage.fromJsonString(
          NetworkMessage(
            id: 1,
            type: type,
            source: 'Alice',
            content: '',
            timestamp: 1,
          ).toJsonString(),
        ),
        isNull,
      );
    }
  });

  test('线协议收件字段必须存在且类型合法，不再包含旧路由字段', () {
    final recipients = <int>{2, 3};
    final message = NetworkMessage(
      id: 1,
      type: MessageType.text,
      source: 'A',
      content: 'hello',
      timestamp: 1,
      recipientIds: recipients,
    );
    recipients.add(4);
    expect(message.recipientIds, {2, 3});
    expect(() => message.recipientIds.add(4), throwsUnsupportedError);
    final json = message.toJson();
    expect(json.keys, isNot(contains('recipientId')));
    expect(json.keys, isNot(contains('route')));
    expect(json['recipientIds'], [2, 3]);
    expect(NetworkMessage.fromJson({...json}..remove('recipientIds')), isNull);
    for (final invalid in [
      null,
      '2',
      2,
      [0],
      [-1],
      [2.0],
      ['2'],
      [null],
      [2, 2],
    ]) {
      expect(
        NetworkMessage.fromJson({...json, 'recipientIds': invalid}),
        isNull,
      );
    }
    expect(NetworkMessage.fromJson({...json, 'recipientId': 2}), isNull);
    expect(NetworkMessage.fromJson({...json, 'route': 'group'}), isNull);
    final broadcast = NetworkMessage.fromJson({...json, 'recipientIds': []})!;
    expect(broadcast.isRoomMessage, isTrue);
    expect(broadcast.toJson()['recipientIds'], isEmpty);
  });

  test('构造时省略收件集合默认公开广播，仍序列化不可变的空集合', () {
    final message = NetworkMessage(
      id: 1,
      type: MessageType.text,
      source: 'A',
      content: 'hello',
      timestamp: 1,
    );
    expect(message.recipientIds, isEmpty);
    expect(message.isRoomMessage, isTrue);
    expect(message.hasValidRoute, isTrue);
    expect(message.toJson()['recipientIds'], isEmpty);
    expect(NetworkMessage.fromJson(message.toJson())!.recipientIds, isEmpty);
    expect(() => message.recipientIds.add(2), throwsUnsupportedError);
    final action = NetworkMessage(
      id: 1,
      type: MessageType.action,
      source: 'A',
      content: 'move',
      timestamp: 1,
    );
    expect(action.hasValidRoute, isFalse);
  });

  group('NetworkMessage.fromJson', () {
    test('解析合法消息', () {
      final msg = NetworkMessage.fromJson({
        'id': 5,
        'recipientIds': [],
        'type': MessageType.text.index,
        'source': 'alice',
        'content': 'hello',
        'timestamp': 123,
      });
      expect(msg, isNotNull);
      expect(msg!.id, 5);
      expect(msg.type, MessageType.text);
      expect(msg.source, 'alice');
      expect(msg.content, 'hello');
      expect(msg.timestamp, 123);
    });

    test('type 越界返回 null（不 RangeError）', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'recipientIds': [],
        'type': 9999,
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull, reason: '越界 type 应返回 null 而非崩溃');
    });

    test('type 负数返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'recipientIds': [],
        'type': -1,
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull);
    });

    test('type 非 int 返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'recipientIds': [],
        'type': 'text',
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull);
    });

    test('id 非 int 返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': '5',
        'recipientIds': [],
        'type': MessageType.text.index,
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull);
    });

    test('负数 id 返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': -1,
        'recipientIds': [],
        'type': MessageType.text.index,
      });
      expect(msg, isNull);
    });

    test('字段类型错误返回 null（不抛 TypeError）', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'recipientIds': [],
        'type': MessageType.text.index,
        'source': 123,
        'timestamp': 'now',
      });
      expect(msg, isNull);
    });

    test('缺少必选 timestamp 返回 null', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'recipientIds': [],
        'type': MessageType.text.index,
        'source': 'x',
        'content': 'x',
      });
      expect(msg, isNull);
    });

    test('source/content 缺失回退空串（不崩溃）', () {
      final msg = NetworkMessage.fromJson({
        'id': 1,
        'recipientIds': [],
        'type': MessageType.text.index,
        'timestamp': 1,
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
        'recipientIds': [1, 2],
        'type': MessageType.action.index,
        'source': 'bob',
        'content': 'move',
        'timestamp': 123,
      });
      final msg = NetworkMessage.fromJsonString(json);
      expect(msg, isNotNull);
      expect(msg!.content, 'move');
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
    test('xorCrypt 拒绝空密钥', () {
      const data = [1, 2, 3, 250, 255];
      expect(() => NetworkMessage.xorCrypt(data, ''), throwsArgumentError);
    });

    test('xorCrypt 加解密往返（对称）', () {
      const key = 'secretkey';
      const data = [72, 101, 108, 108, 111, 0, 255, 128];
      final encrypted = NetworkMessage.xorCrypt(data, key);
      expect(encrypted, isNot(equals(data)));
      final decrypted = NetworkMessage.xorCrypt(encrypted, key);
      expect(decrypted, equals(data));
    });

    test('明文握手数据往返', () {
      final original = NetworkMessage(
        id: 7,
        type: MessageType.image,
        source: 'cam',
        content: '{"data":"abc"}',
        timestamp: 1,
      );
      final wire = original.toPlainSocketData();
      final restored = NetworkMessage.fromPlainSocketData(wire);
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
        timestamp: 1,
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
        timestamp: 1,
      );
      final wire = original.toSocketData(encryptionKey: 'key1');
      final restored = NetworkMessage.fromSocketData(
        wire,
        encryptionKey: 'key2',
      );
      expect(restored, isNull, reason: '密钥不匹配应解为乱码而非合法消息');
    });
  });
}
