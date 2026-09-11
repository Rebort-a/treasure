import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/00.common/network/tcp_frame_codec.dart';

void main() {
  group('TcpFrameCodec', () {
    test('单帧往返', () {
      final decoder = TcpFrameDecoder();
      final payload = Uint8List.fromList([1, 2, 3, 255]);

      final frames = decoder.add(TcpFrameCodec.encode(payload));

      expect(frames, hasLength(1));
      expect(frames.single, payload);
    });

    test('半包：长度头和 payload 可逐字节输入', () {
      final decoder = TcpFrameDecoder();
      final framed = TcpFrameCodec.encode(
        List<int>.generate(1024, (i) => i % 256),
      );
      final frames = <Uint8List>[];

      for (final byte in framed) {
        frames.addAll(decoder.add([byte]));
      }

      expect(frames, hasLength(1));
      expect(frames.single, List<int>.generate(1024, (i) => i % 256));
    });

    test('粘包：单个 chunk 可解析多帧', () {
      final decoder = TcpFrameDecoder();
      final first = TcpFrameCodec.encode([1, 2]);
      final second = TcpFrameCodec.encode([3, 4, 5]);

      final frames = decoder.add([...first, ...second]);

      expect(frames, [
        [1, 2],
        [3, 4, 5],
      ]);
    });

    test('跨任意边界拆分后仍能解析多帧', () {
      final decoder = TcpFrameDecoder();
      final wire = [
        ...TcpFrameCodec.encode([1, 2, 3]),
        ...TcpFrameCodec.encode([4]),
        ...TcpFrameCodec.encode([5, 6]),
      ];

      final frames = <Uint8List>[];
      for (int i = 0; i < wire.length; i += 3) {
        frames.addAll(
          decoder.add(wire.sublist(i, (i + 3).clamp(0, wire.length))),
        );
      }

      expect(frames, [
        [1, 2, 3],
        [4],
        [5, 6],
      ]);
    });

    test('超过最大帧长时拒绝并可在 reset 后继续使用', () {
      final decoder = TcpFrameDecoder(maxFrameLength: 4);
      final oversizedHeader = Uint8List.fromList([0, 0, 0, 5]);

      expect(() => decoder.add(oversizedHeader), throwsFormatException);
      expect(decoder.add(TcpFrameCodec.encode([1, 2, 3, 4])).single, [
        1,
        2,
        3,
        4,
      ]);
    });

    test('加密 NetworkMessage 分片后可完整恢复', () {
      const key = 'room-key';
      final original = NetworkMessage(
        id: 7,
        type: MessageType.file,
        source: 'alice',
        content: '{"name":"中文.txt","data":"AA=="}',
      );
      final framed = TcpFrameCodec.encode(
        original.toSocketData(encryptionKey: key),
      );
      final decoder = TcpFrameDecoder();
      final payloads = <Uint8List>[];

      for (int i = 0; i < framed.length; i += 7) {
        payloads.addAll(
          decoder.add(framed.sublist(i, (i + 7).clamp(0, framed.length))),
        );
      }

      final restored = NetworkMessage.fromSocketData(
        payloads.single,
        encryptionKey: key,
      );
      expect(restored, isNotNull);
      expect(restored!.content, original.content);
    });
  });
}
