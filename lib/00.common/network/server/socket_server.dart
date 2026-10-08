import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../broadcast_discovery.dart';
import '../protocol/network_message.dart';
import '../protocol/network_room.dart';
import 'server_abstract.dart';

class _RoomClient {
  final ServerConnection connection;
  final int id;
  bool authorized = false;
  bool rejecting = false;
  Timer? authTimer;

  _RoomClient(this.connection, this.id);
}

class SocketServer {
  static const _discoveryInterval = Duration(seconds: 1);

  final ServerTransport _transport = createServerTransport();
  final String roomName;
  final int roomType;
  final String encryptionKey;
  final String? password;
  final Set<_RoomClient> _clients = {}; // 全部连接，含尚未认证的连接。
  final Map<int, String> _members = {}; // 已认证成员
  final Set<int> _searching = {}; // 尚未完成或取消匹配的成员
  final int maxClients;
  final membersNotifier = ValueNotifier<Map<int, String>>(const {});
  int _idCounter = 0;
  bool _isStopping = false;

  Map<int, String> get members => Map.unmodifiable(_members);

  Timer? _broadcastTimer;
  Future<int>? _starting;
  Future<void>? _stopping;

  SocketServer({
    required this.roomName,
    required this.roomType,
    required this.encryptionKey,
    this.password,
    this.maxClients = 64,
  });

  Future<int> start() {
    if (_isStopping) return Future.error(StateError('Room server has stopped'));
    return _starting ??= _start();
  }

  Future<int> _start() async {
    // 传输层就绪后逐条回调 _handleConnection，随后开启周期广播。
    final port = await _transport.start(_handleConnection);
    _startBroadcast();
    return port;
  }

  int get port => _transport.port;

  void _handleConnection(ServerConnection connection) {
    // 未认证连接同样占用名额，因此上限检查放在认证之前。
    if (_isStopping || _clients.length >= maxClients) {
      debugPrint('[Server] 拒绝连接：已达人数上限 $maxClients');
      unawaited(connection.close());
      return;
    }
    _idCounter++;
    final client = _RoomClient(connection, _idCounter);
    // 先登记再挂超时和监听，保证后续回调都能在集合中找到该连接。
    _clients.add(client);
    _startAuthTimeout(client);
    debugPrint(
      '[Server] Client #${client.id} connected. Total: ${_clients.length}',
    );
    _listenClient(client);
  }

  void _listenClient(_RoomClient client) {
    client.connection.listen(
      onData: (bytes) {
        // 已移除的连接仍可能有在途数据，直接丢弃。
        if (!_clients.contains(client)) return;
        // 认证前只处理握手消息，认证通过后才进入业务消息转发流程。
        if (client.authorized) {
          _handleClientMessage(client, bytes);
        } else {
          _authenticate(client, bytes);
        }
      },
      onDone: () => _removeClient(client),
      onError: (error) {
        debugPrint('[Server] Connection #${client.id} error: $error');
        _removeClient(client);
      },
    );
  }

  /// 握手超时看门狗：连接建立后 5 秒内未完成密码认证则踢除，
  /// 防止半开或僵尸连接长期占用 maxClients 名额。
  void _startAuthTimeout(_RoomClient client) {
    client.authTimer = Timer(const Duration(seconds: 5), () {
      if (!client.authorized && _clients.contains(client)) {
        _removeClient(client);
      }
    });
  }

  /// 处理未认证连接发来的数据，只接受一次合法的连接握手。
  void _authenticate(_RoomClient client, List<int> bytes) {
    // 已判定失败，等待关闭，忽略其后的数据以免重复回包。
    if (client.rejecting) return;
    if (_isStopping || !_clients.contains(client)) {
      _removeClient(client);
      return;
    }
    try {
      // 握手走明文消息，要求为房间作用域、id 为 0 且带非空昵称。
      final request = NetworkMessage.fromPlainSocketData(bytes);
      if (request != null &&
          request.type == MessageType.connect &&
          request.id == 0 &&
          request.isRoomMessage &&
          request.source.trim().isNotEmpty) {
        final credentials = jsonDecode(request.content);
        // 无密码房间约定使用空字符串，省去空值分支。
        if (credentials is Map<String, dynamic> &&
            credentials['password'] is String &&
            credentials['password'] == (password ?? '')) {
          // 先置认证标记再取消看门狗，避免回调与认证竞争移除连接。
          client.authorized = true;
          client.authTimer?.cancel();
          _members[client.id] = request.source;
          _publishMembers();
          // 回执携带成员 id、成员名单与加密密钥，客户端据此切换为加密通信。
          _sendTo(
            client,
            NetworkMessage(
              id: 0,
              type: MessageType.accept,
              source: roomName,
              content: jsonEncode({
                'clientId': client.id,
                'roomType': roomType,
                'members': _members.map((id, name) => MapEntry('$id', name)),
                'key': encryptionKey,
              }),
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ).toPlainSocketData(),
          );
          final name = _members[client.id]!;
          _notify(NoticeType.join, memberId: client.id, source: name);
          return;
        }
      }
    } catch (_) {
      // 拒绝无效握手，不向其暴露房间状态。
    }
    // 校验失败：回执 invalidPassword 后延迟关闭，期间不透露房间任何状态。
    client.rejecting = true;
    _sendTo(
      client,
      NetworkMessage(
        id: 0,
        type: MessageType.accept,
        source: roomName,
        content: jsonEncode({'error': 'invalidPassword'}),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ).toPlainSocketData(),
    );
    // 先发送完错误消息，再关闭连接。
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      _removeClient(client);
    });
  }

  /// 构造 UDP 发现应答，供局域网内其他设备检索本房间。
  NetworkMessage _discoveryMessage() {
    return NetworkMessage(
      id: 0,
      type: MessageType.broadcast,
      source: roomName,
      content: RoomInfo.configToJsonString(
        port,
        roomType,
        RoomState.start,
        encryptionKey: encryptionKey,
        hasPassword: password != null,
        count: _members.length,
      ),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ==================== 通用 ====================

  void _startBroadcast() {
    // 停止流程中不再开启新广播。
    if (_isStopping) return;
    // 每秒广播一次房间信息，成员增减会体现在 count 上。
    _broadcastTimer = Timer.periodic(_discoveryInterval, (_) {
      Broadcast.sendMessage(_discoveryMessage().toPlainSocketData());
    });
  }

  void _sendTo(_RoomClient client, List<int> data) {
    if (!_clients.contains(client)) return;
    // 单条连接发送失败只记日志，不影响其他成员的收发。
    try {
      client.connection.send(data);
    } catch (e) {
      debugPrint('[Server] _sendTo #${client.id} failed: $e');
    }
  }

  void _broadcastRaw(List<int> data) {
    // TCP 已由长度前缀恢复消息边界，WebSocket 原生具有帧边界，两条路径
    // 均可在广播前安全校验完整消息。
    if (!_isValidMessage(data)) {
      debugPrint('[Server] 丢弃畸形消息，不转发');
      return;
    }
    // 未认证连接不接收任何房间消息。
    for (final client in _clients) {
      if (client.authorized) _sendTo(client, data);
    }
  }

  /// 发布不可变的成员快照，供 UI 监听刷新。
  void _publishMembers() {
    membersNotifier.value = members;
  }

  /// 校验并转发已认证成员的业务消息。
  void _handleClientMessage(_RoomClient sender, List<int> bytes) {
    // 停止中、未认证或已被移除的连接都不是合法发送者，直接丢弃。
    // 未认证连接的数据由 _authenticate 处理，不会进入本方法。
    if (_isStopping || !sender.authorized || !_clients.contains(sender)) return;

    // 已认证后的消息一律按房间密钥解密；解析失败由下一步统一丢弃。
    final message = NetworkMessage.fromSocketData(
      bytes,
      encryptionKey: encryptionKey,
    );

    // id 必须与发送者本人一致，防止冒充其他成员。
    if (message == null || message.id != sender.id) return;

    // 房间成员不能伪造仅允许服务器发送的控制消息。
    // accept/notify 仅由服务器发出，broadcast 由服务器经 UDP 广播；
    // connect 属握手段专用类型，认证完成后重发只可能是伪造或状态混淆。
    if (const {
      MessageType.accept,
      MessageType.connect,
      MessageType.broadcast,
      MessageType.notify,
    }.contains(message.type)) {
      return;
    }

    // 协议层按类型限定路由形态（match/confirm 须私聊，publish/sync 须群发），
    // 非法路由在此统一拦截。
    if (!message.hasValidRoute) return;

    // 收件人必须是在册成员：名单过期的消息整条丢弃，避免向已离开的成员投递。
    if ((message.recipientId != null &&
            !_members.containsKey(message.recipientId)) ||
        (message.recipientIds?.any((id) => !_members.containsKey(id)) ??
            false)) {
      return;
    }

    // 显示名称使用认证值，不能由客户端冒充其他成员。
    message.source = _members[sender.id]!;

    // 搜索消息除了原样广播，再补发一条展示用通知，供房间成员在聊天流中看到提示。
    if (message.type == MessageType.search) {
      // 新加入搜索的成员还没有见过较早的搜索；只向它补发现存搜索者。
      for (final id in _searching) {
        if (id == sender.id || !_members.containsKey(id)) continue;
        _sendTo(
          sender,
          NetworkMessage(
            id: id,
            source: _members[id]!,
            type: MessageType.search,
            content: '',
            timestamp: message.timestamp,
          ).toSocketData(encryptionKey: encryptionKey),
        );
      }
      _searching.add(sender.id);
      _notify(NoticeType.search, memberId: sender.id, source: message.source);
    } else if (message.type == MessageType.cancelSearch) {
      _searching.remove(sender.id);
    } else if (message.type == MessageType.confirm &&
        MatchConfirmation.tryParse(message.content)?.phase ==
            MatchConfirmationPhase.joined) {
      // 预留和 start 不代表入局；只有新玩家应用层 joined 才撤销搜索状态。
      _searching.remove(sender.id);
      _searching.remove(message.recipientId);
    }

    // 以房间密钥重新封装，接收端用同一密钥解析。
    final forwarded = message.toSocketData(encryptionKey: encryptionKey);

    if (message.isPrivateMessage) {
      // 私聊先向发送者回环，再投递唯一接收者。
      _sendTo(sender, forwarded);
      final target = _clients
          .where(
            (client) => client.authorized && client.id == message.recipientId,
          )
          .firstOrNull;
      if (target != null && target != sender) _sendTo(target, forwarded);
      return;
    }

    final recipients = message.recipientIds;
    // recipientIds 为空表示广播全房间，否则仅投递给指定成员。
    for (final client in _clients) {
      // 未认证连接不接收任何业务消息。
      if (!client.authorized) continue;
      if (recipients == null || recipients.contains(client.id)) {
        _sendTo(client, forwarded);
      }
    }
  }

  /// 以 notify 类型向全房间广播房间级事件（加入/离开/搜索）。
  /// memberId 供客户端增量维护成员表，source 同时作为成员显示名。
  void _notify(
    NoticeType type, {
    required int memberId,
    required String source,
  }) {
    _broadcastRaw(
      NetworkMessage(
        id: 0,
        source: source,
        type: MessageType.notify,
        content: RoomNotification(
          type: type,
          memberId: memberId,
          memberName: source,
        ).content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ).toSocketData(encryptionKey: encryptionKey),
    );
  }

  /// 校验 data 能解密并解析为合法 NetworkMessage
  bool _isValidMessage(List<int> data) {
    try {
      return NetworkMessage.fromSocketData(
            data,
            encryptionKey: encryptionKey,
          ) !=
          null;
    } catch (_) {
      return false;
    }
  }

  /// 统一的连接清理入口，重复调用安全（不在册时直接返回）。
  void _removeClient(_RoomClient client) {
    if (!_clients.contains(client)) return;
    // 无论因何原因断开都取消看门狗，避免定时器悬空触发。
    client.authTimer?.cancel();
    _clients.remove(client);
    _searching.remove(client.id);
    final name = _members.remove(client.id);
    unawaited(client.connection.close());
    // stop 期间不广播（socket 已被 stop 关闭）
    if (_isStopping) return;
    if (name != null) _publishMembers();
    if (client.authorized && name != null) {
      _notify(NoticeType.left, memberId: client.id, source: name);
    }
  }

  /// 关闭房间并释放资源；幂等，重复调用共享同一次关闭。
  Future<void> stop() {
    if (_stopping case final pending?) return pending;
    final completion = Completer<void>();
    _stopping = completion.future;
    // 立即置位，阻断新连接、新消息与周期广播。
    _isStopping = true;
    _stop().then(
      (_) => completion.complete(),
      onError: (Object error, StackTrace stack) =>
          completion.completeError(error, stack),
    );
    return completion.future;
  }

  Future<void> _stop() async {
    // 启动期间也可取消，必须等待迟到的监听端口建立后再关闭。
    try {
      await _starting;
    } catch (_) {}
    _broadcastTimer?.cancel();

    final closedMessage = NetworkMessage(
      id: 0,
      type: MessageType.notify,
      source: roomName,
      content: const RoomNotification(type: NoticeType.close).content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ).toSocketData(encryptionKey: encryptionKey);

    // 通知房间关闭，与游戏退出消息分离。
    for (final client in List.of(_clients)) {
      // 清理过程中取消全部看门狗，避免定时器在关闭途中触发。
      client.authTimer?.cancel();
      if (client.authorized) _sendTo(client, closedMessage);
    }

    // 等消息发出后再关 socket
    if (_clients.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    for (final client in List.of(_clients)) {
      try {
        await client.connection.close();
      } catch (_) {}
    }
    _clients.clear();
    _members.clear();
    _searching.clear();
    // 通知 UI 房间已无成员。
    _publishMembers();

    // UDP 广播房间关闭（await 确保遍历所有网卡发送完毕）
    final serverPort = port;
    if (serverPort != 0) {
      await Broadcast.sendMessage(
        NetworkMessage(
          id: 0,
          type: MessageType.broadcast,
          source: roomName,
          content: RoomInfo.configToJsonString(
            serverPort,
            roomType,
            RoomState.stop,
            encryptionKey: encryptionKey,
          ),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ).toPlainSocketData(),
      );
    }
    await _transport.close();
    // 本实例停止后不再复用，直接释放通知器。
    membersNotifier.dispose();
  }
}
