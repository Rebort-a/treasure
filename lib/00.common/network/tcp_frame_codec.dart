import 'dart:typed_data';

/// TCP 消息分帧：4 字节无符号大端长度 + payload。
///
/// TCP 本身没有消息边界，本编解码器保证半包、粘包和大附件都以 O(n) 处理，
/// 同时通过 [maxFrameLength] 限制恶意或损坏的长度头。
abstract final class TcpFrameCodec {
  static const int headerLength = 4;
  static const int defaultMaxFrameLength = 128 * 1024 * 1024;

  static Uint8List encode(List<int> payload) {
    if (payload.isEmpty || payload.length > defaultMaxFrameLength) {
      throw ArgumentError.value(
        payload.length,
        'payload.length',
        'must be between 1 and $defaultMaxFrameLength bytes',
      );
    }
    final framed = Uint8List(headerLength + payload.length);
    ByteData.sublistView(framed).setUint32(0, payload.length, Endian.big);
    framed.setRange(headerLength, framed.length, payload);
    return framed;
  }
}

class TcpFrameDecoder {
  final int maxFrameLength;

  final Uint8List _header = Uint8List(TcpFrameCodec.headerLength);
  int _headerBytes = 0;
  int? _expectedLength;
  BytesBuilder _payload = BytesBuilder(copy: false);
  int _payloadBytes = 0;

  TcpFrameDecoder({this.maxFrameLength = TcpFrameCodec.defaultMaxFrameLength})
    : assert(maxFrameLength > 0);

  /// 输入任意 TCP chunk，返回其中已完成的零到多个 payload。
  List<Uint8List> add(List<int> chunk) {
    final frames = <Uint8List>[];
    int offset = 0;

    while (offset < chunk.length) {
      if (_expectedLength == null) {
        final needed = TcpFrameCodec.headerLength - _headerBytes;
        final take = needed < chunk.length - offset
            ? needed
            : chunk.length - offset;
        _header.setRange(_headerBytes, _headerBytes + take, chunk, offset);
        _headerBytes += take;
        offset += take;

        if (_headerBytes < TcpFrameCodec.headerLength) break;

        final length = ByteData.sublistView(_header).getUint32(0, Endian.big);
        _headerBytes = 0;
        if (length == 0 || length > maxFrameLength) {
          reset();
          throw FormatException(
            'Invalid TCP frame length $length (max $maxFrameLength)',
          );
        }
        _expectedLength = length;
      }

      final expected = _expectedLength!;
      final needed = expected - _payloadBytes;
      final take = needed < chunk.length - offset
          ? needed
          : chunk.length - offset;
      _payload.add(Uint8List.fromList(chunk.sublist(offset, offset + take)));
      _payloadBytes += take;
      offset += take;

      if (_payloadBytes == expected) {
        frames.add(_payload.takeBytes());
        _expectedLength = null;
        _payload = BytesBuilder(copy: false);
        _payloadBytes = 0;
      }
    }

    return frames;
  }

  void reset() {
    _headerBytes = 0;
    _expectedLength = null;
    _payload = BytesBuilder(copy: false);
    _payloadBytes = 0;
  }
}
