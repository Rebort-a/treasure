import 'dart:io';

import 'package:flutter/foundation.dart';

const String multicastAddress = '224.0.0.251';
const int multicastPort = 4545;
const String netmask24 = '255.255.255.0';
const String netmask16 = '255.255.0.0';

class Broadcast {
  static bool get _enabled => !kIsWeb;

  // 复用长生命周期发送 socket，避免每次 sendMessage 都新建+关闭
  // （发现广播每秒一次，原来 60 socket/分钟 churn）
  static RawDatagramSocket? _sendSocket;

  static Future<RawDatagramSocket> initSocket() async {
    RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
      ttl: 255,
    );
    socket.broadcastEnabled = true;
    return socket;
  }

  static Future<void> sendMessage(List<int> data) async {
    if (!_enabled) return;
    _sendSocket ??= await initSocket();
    final sendSocket = _sendSocket!;
    sendSocket.send(data, InternetAddress(multicastAddress), multicastPort);
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        sendBroadcast(sendSocket, address, netmask24, multicastPort, data);
        sendBroadcast(sendSocket, address, netmask16, multicastPort, data);
      }
    }
  }

  /// 关闭并释放持久发送 socket（应用退出或不再需要广播时调用）。
  /// 不在 SocketServer.stop 自动调用：多个房间可能共享此 socket，
  /// 自动关闭会破坏其他房间的广播。
  static void dispose() {
    _sendSocket?.close();
    _sendSocket = null;
  }

  static void sendBroadcast(
    RawDatagramSocket socket,
    InternetAddress address,
    String netmask,
    int port,
    List<int> data,
  ) {
    if (address.type == InternetAddressType.IPv4) {
      final broadcastAddress = _getBroadcastAddress(address.address, netmask);
      socket.send(data, InternetAddress(broadcastAddress), port);
    }
  }

  static bool isIPv4(String address) {
    return RegExp(
      r'^(?:(?:^|\.)(?:2(?:5[0-5]|[0-4]\d)|1?\d?\d)){4}$',
    ).hasMatch(address);
  }

  static String _getBroadcastAddress(String localAddress, String netmask) {
    final localParts = localAddress.split('.').map(int.parse).toList();
    final netmaskParts = netmask.split('.').map(int.parse).toList();
    return List.generate(4, (i) {
      return (localParts[i] | (~netmaskParts[i] & 0xFF)).toString();
    }).join('.');
  }
}

class Discovery {
  RawDatagramSocket? _socket;

  static Future<RawDatagramSocket> initSocket() async {
    RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      multicastPort,
      reuseAddress: true,
      ttl: 255,
    );
    socket.broadcastEnabled = true;
    socket.readEventsEnabled = true;
    socket.joinMulticast(InternetAddress(multicastAddress));
    return socket;
  }

  void startReceive(
    void Function(String address, List<int> data) callback,
  ) async {
    if (!Broadcast._enabled) return;
    _socket = await initSocket();
    _socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final dgram = _socket!.receive();
        if (dgram != null) {
          callback(dgram.address.address, dgram.data);
        }
      }
    });
  }

  void stopReceive() {
    _socket?.close();
    _socket = null;
  }
}
