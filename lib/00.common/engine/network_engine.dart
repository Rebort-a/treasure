import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../chat/chat_channel.dart';
import '../l10n/strings.dart';
import '../widget/dialog/template_dialog.dart';
import '../tool/notifiers.dart';
import '../network/network_message.dart';
import '../network/reconnect_policy.dart';
import '../network/network_room.dart';
import '../network/room_session.dart';
import '../network/connection.dart' as conn;

class NetworkEngine implements ChatChannel {
  @override
  final ListNotifier<NetworkMessage> messageList = ListNotifier([]);
  @override
  final ScrollController scrollController = ScrollController();
  @override
  final TextEditingController textController = TextEditingController();

  late conn.Connection _connection;
  bool _hasConnection = false;
  final List<NetworkMessage> _sendBuffer = [];
  bool _isSending = false;
  Completer<void>? _sendCompleter;

  bool _isDisposed = false;
  bool _isClosing = false;
  bool _isClosed = true;
  bool _exitRequested = false;
  Completer<void>? _closeCompleter;

  @override
  int identity = 0;
  final ValueNotifier<int> identityNotifier = ValueNotifier<int>(0);
  final ValueNotifier<RoomSession> roomSession = ValueNotifier(
    const RoomSession(),
  );

  @override
  final String userName;
  late String roomName = roomInfo.name;
  final RoomInfo roomInfo;
  final AlwaysNotifier<void Function(BuildContext)> navigatorHandler;
  final Set<void Function(NetworkMessage)> _listeners = {};
  void addMessageListener(void Function(NetworkMessage) listener) =>
      _listeners.add(listener);
  void removeMessageListener(void Function(NetworkMessage) listener) =>
      _listeners.remove(listener);
  void _dispatch(NetworkMessage message) {
    for (final listener in List.of(_listeners)) {
      if (_listeners.contains(listener)) listener(message);
    }
  }

  // ==================== 断线重连 ====================
  bool _isReconnecting = false;
  final ValueNotifier<int> _reconnectNotifier = ValueNotifier(0);
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  bool _reconnectDialogShown = false;
  bool _reconnectDialogVisible = false;

  // ==================== 加密 ====================
  String? encryptionKey;

  NetworkEngine({
    required this.userName,
    required this.roomInfo,
    required this.navigatorHandler,
  }) : encryptionKey = roomInfo.encryptionKey {
    messageList.addCallBack(_scrollToBottom);
    _connectToServer();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  // ==================== 连接管理 ====================

  Future<void> _connectToServer() async {
    try {
      final connection = await conn.Connection.connect(
        roomInfo.address,
        roomInfo.port,
      );
      if (_isClosing || _isDisposed) {
        await connection.close();
        return;
      }
      _connection = connection;
      _hasConnection = true;
    } catch (_) {
      _attemptReconnect();
      return;
    }
    _isClosed = false;
    _connection.listen(onData: _handleSocketData, onDone: _handleSocketDone);

    _sendHandshake();
  }

  void _sendHandshake() {
    _connection.send(
      utf8.encode(
        jsonEncode({
          'connect': true,
          'password': roomInfo.password ?? '',
          'name': userName,
        }),
      ),
    );
  }

  void _handleSocketData(List<int> data) {
    if (_isClosed || _isClosing || _isDisposed) return;
    final message = NetworkMessage.fromSocketData(
      data,
      encryptionKey: identity == 0 ? null : encryptionKey,
    );
    if (message == null) {
      debugPrint('[Net] 丢弃畸形消息（${data.length} bytes）');
      return;
    }
    _processNetworkMessage(message);
  }

  void _processNetworkMessage(NetworkMessage message) {
    final summary = switch (message.type) {
      MessageType.image => _summarizeMedia(message.content, 'image'),
      MessageType.file => _summarizeMedia(message.content, 'file'),
      MessageType.resource => '[resource, ${message.content.length} chars]',
      MessageType.emoji ||
      MessageType.typing ||
      MessageType.broadcast ||
      MessageType.accept ||
      MessageType.search ||
      MessageType.match ||
      MessageType.sync ||
      MessageType.action ||
      MessageType.exit ||
      MessageType.notify ||
      MessageType.text => message.content,
      MessageType.roomControl => message.content,
    };
    debugPrint('${message.source} ${message.id} ${message.type} $summary');

    // 服务器关闭房间（id==0）→ 弹窗并退出
    if (message.type == MessageType.exit && message.id == 0) {
      _isClosing = true;
      _dispatch(message);
      unawaited(closeSocket());
      navigatorHandler.value = (context) {
        DialogTemplate.promptDialog(
          context: context,
          title: S.disconnected,
          content: S.roomClosed,
          before: () => true,
          after: () => _navigateToBack(),
        );
      };
      return;
    }

    // 其他成员退出 → 传给游戏引擎处理

    if (message.type == MessageType.accept &&
        message.id == 0 &&
        identity == 0) {
      final accepted = jsonDecode(message.content) as Map<String, dynamic>;
      identity = accepted['clientId'] as int;
      encryptionKey = accepted['key'] as String?;
      roomName = message.source;
      roomSession.value = RoomSession(game: accepted['roomType'] as int);
      identityNotifier.value = identity;
      sendNetworkMessage(MessageType.notify, S.joinedRoom);
      return;
    }

    if (message.type == MessageType.roomControl) {
      if (message.id == 0) {
        try {
          final control = jsonDecode(message.content) as Map<String, dynamic>;
          if (control['error'] == 'invalidPassword') {
            _isClosing = true;
            unawaited(closeSocket());
            navigatorHandler.value = (context) {
              DialogTemplate.promptDialog(
                context: context,
                title: S.joinRoom,
                content: S.incorrectRoomPassword,
                before: () => true,
                after: _navigateToBack,
              );
            };
            return;
          }
          final next = RoomSession.fromJson(message.content);
          roomSession.value = next;
        } catch (_) {
          debugPrint('[Net] Invalid room snapshot');
        }
      }
      return;
    }

    _dispatch(message);
    if (!_isDisposed &&
        !_isClosing &&
        message.sessionId == null &&
        const {
          MessageType.notify,
          MessageType.text,
          MessageType.emoji,
          MessageType.image,
          MessageType.file,
        }.contains(message.type)) {
      messageList.add(message);
    }
  }

  // ==================== 断线重连 ====================

  void _handleSocketDone() {
    if (_isClosing || _isClosed || _isDisposed) return;
    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_isReconnecting || _isClosing || _isDisposed) return;

    _isReconnecting = true;
    _reconnectNotifier.value = 0;
    _reconnectDialogShown = false;
    _isClosed = true;
    identity = 0;
    identityNotifier.value = 0;

    // 关闭旧连接
    if (_hasConnection) _connection.close();

    _doReconnect();
  }

  void _doReconnect() {
    if (_isDisposed || _isClosing) return;

    // 指数退避延迟
    final delay = reconnectDelayForAttempt(_reconnectNotifier.value);
    _reconnectTimer = Timer(delay, () async {
      if (_isDisposed || _isClosing) return;

      _reconnectNotifier.value++;

      // 只在第一次显示弹窗，后续通过 ValueNotifier 更新内容
      if (!_reconnectDialogShown) {
        _reconnectDialogShown = true;
        navigatorHandler.value = (context) {
          if (!_isReconnecting || _isClosing || _isDisposed) return;
          _reconnectDialogVisible = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => ValueListenableBuilder<int>(
              valueListenable: _reconnectNotifier,
              builder: (_, attempts, __) => AlertDialog(
                title: Text(S.disconnected),
                content: Text(
                  attempts >= _maxReconnectAttempts
                      ? S.cannotReconnect
                      : S.reconnecting(attempts, _maxReconnectAttempts),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _isClosing = true;
                      _reconnectTimer?.cancel();
                      Navigator.pop(context);
                      _navigateToBack();
                    },
                    child: Text(
                      attempts >= _maxReconnectAttempts ? S.close : S.cancel,
                    ),
                  ),
                ],
              ),
            ),
          ).whenComplete(() => _reconnectDialogVisible = false);
        };
      }

      // 已达最大重试次数，不再重试
      if (_reconnectNotifier.value >= _maxReconnectAttempts) {
        _isReconnecting = false;
        return;
      }

      try {
        final connection = await conn.Connection.connect(
          roomInfo.address,
          roomInfo.port,
        );
        if (_isClosing || _isDisposed) {
          await connection.close();
          return;
        }
        _connection = connection;
        _hasConnection = true;
        _isClosed = false;
        _isReconnecting = false;

        // 重新监听
        _connection.listen(
          onData: _handleSocketData,
          onDone: _handleSocketDone,
        );

        // 重新进入房间
        _onReconnected();
        _sendHandshake();
      } catch (_) {
        _doReconnect(); // 继续重试
      }
    });
  }

  void _onReconnected() {
    // 清空旧状态
    _sendBuffer.clear();
    identity = 0;
    identityNotifier.value = 0; // 重新等待 accept 分配新 ID

    // 关闭重连对话框
    navigatorHandler.value = (context) {
      if (_reconnectDialogVisible) Navigator.of(context).pop();
    };
  }

  // ==================== 消息发送 ====================

  @override
  void sendInputText() {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    // 检查是否是纯 emoji 消息（单个或少量 emoji）
    if (_isEmojiOnly(text)) {
      sendEmojiMessage(text);
    } else {
      sendNetworkMessage(MessageType.text, text);
    }
    textController.clear();
  }

  /// 检查文本是否只包含 emoji
  bool _isEmojiOnly(String text) {
    // 移除空格和常见标点
    final cleaned = text.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
    if (cleaned.isEmpty) return false;

    // 检查是否大部分字符是 emoji（简单检测）
    int emojiCount = 0;
    for (var rune in cleaned.runes) {
      if (rune >= 0x1F600 && rune <= 0x1F64F) emojiCount++; // 表情
      if (rune >= 0x1F300 && rune <= 0x1F5FF) emojiCount++; // 符号
      if (rune >= 0x1F680 && rune <= 0x1F6FF) emojiCount++; // 交通
      if (rune >= 0x1F900 && rune <= 0x1F9FF) emojiCount++; // 补充
      if (rune >= 0x1FA00 && rune <= 0x1FAFF) emojiCount++; // 补充符号与象形文字
      if (rune >= 0x1F1E6 && rune <= 0x1F1FF) emojiCount++; // 旗语区域指示符
      if (rune >= 0x2600 && rune <= 0x26FF) emojiCount++; // 杂项
      if (rune >= 0x2700 && rune <= 0x27BF) emojiCount++; // 装饰
    }

    // 如果超过一半字符是 emoji，且总字符数少于等于8，认为是纯 emoji
    return emojiCount > 0 &&
        emojiCount >= cleaned.length / 2 &&
        cleaned.length <= 8;
  }

  void sendNetworkMessage(
    MessageType type,
    String content, {
    int? targetId,
    String? sessionId,
  }) {
    if (identity == 0 || _isClosing || _isDisposed) return;

    final message = NetworkMessage(
      id: identity,
      type: type,
      source: userName,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      targetId: targetId,
      sessionId: sessionId,
    );

    _sendBuffer.add(message);
    _pushMessage();
  }

  /// 发送 emoji 表情消息
  void sendEmojiMessage(String emoji) {
    sendNetworkMessage(MessageType.emoji, emoji);
  }

  /// 发送图片消息（Base64 编码）
  void sendImageMessage(
    String base64Image, {
    String? fileName,
    String? blurHash,
  }) {
    final content = jsonEncode({
      'data': base64Image,
      if (fileName != null) 'name': fileName,
      if (blurHash != null) 'hash': blurHash,
    });
    sendNetworkMessage(MessageType.image, content);
  }

  /// 发送文件消息
  void sendFileMessage(String fileName, int fileSize, String base64Data) {
    final content = jsonEncode({
      'name': fileName,
      'size': fileSize,
      'data': base64Data,
    });
    sendNetworkMessage(MessageType.file, content);
  }

  /// 发送正在输入状态
  void sendTypingStatus() {
    if (identity == 0 || _isClosing || _isDisposed) return;
    final message = NetworkMessage(
      id: identity,
      type: MessageType.typing,
      source: userName,
      content: 'typing',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _rawSend(message);
  }

  Future<void> _pushMessage() async {
    if (_isClosed || _isSending || _sendBuffer.isEmpty) return;

    _isSending = true;
    final connection = _connection;

    try {
      while (!_isClosed &&
          identical(connection, _connection) &&
          _sendBuffer.isNotEmpty) {
        // 先出队，避免等待写入期间重连清空队列后再次移除同一条消息。
        final message = _sendBuffer.removeAt(0);
        connection.send(message.toSocketData(encryptionKey: encryptionKey));
        await connection.flush();
      }
    } catch (e) {
      if (identical(connection, _connection)) _sendBuffer.clear();
    } finally {
      _isSending = false;
      _sendCompleter?.complete();
      _sendCompleter = null;
      if (!_isClosed && _sendBuffer.isNotEmpty) {
        unawaited(_pushMessage());
      }
    }
  }

  /// 底层发送（加密后写入连接）
  void _rawSend(NetworkMessage message) {
    if (_isClosed) return;
    _connection.send(message.toSocketData(encryptionKey: encryptionKey));
  }

  // ==================== 生命周期 ====================

  void leavePage() {
    if (_isDisposed) return;
    unawaited(closeSocket());
    _navigateToBack();
  }

  /// 只关闭连接，不负责导航或销毁界面资源；重复调用共享同一个关闭结果。
  Future<void> closeSocket() {
    if (_closeCompleter case final pending?) return pending.future;
    final completion = Completer<void>();
    _closeCompleter = completion;
    _closeConnection().then(
      (_) => completion.complete(),
      onError: (Object error, StackTrace stack) =>
          completion.completeError(error, stack),
    );
    return completion.future;
  }

  Future<void> _closeConnection() async {
    final notify = !_isClosed && !_isClosing && identity != 0;
    _isClosing = true;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    if (notify) {
      _sendBuffer.add(
        NetworkMessage(
          id: identity,
          type: MessageType.notify,
          source: userName,
          content: 'leave room',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    identity = 0;
    identityNotifier.value = 0;
    try {
      // 关闭前发送完已有消息，关闭开始后不再接受新消息。
      if (_isSending) {
        _sendCompleter ??= Completer<void>();
        await _sendCompleter!.future;
      }
      await _pushMessage();
    } finally {
      _isClosed = true;
      _sendBuffer.clear();
      if (_hasConnection) {
        _hasConnection = false;
        await _connection.close();
      }
    }
  }

  void _navigateToBack() {
    if (_isDisposed || _exitRequested) return;
    _exitRequested = true;
    navigatorHandler.value = (BuildContext context) {
      if (!_isDisposed && context.mounted) Navigator.pop(context);
    };
  }

  /// 由聊天室页面持有者调用；游戏结束不得调用此方法。
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    // 先结束依赖房间身份的游戏会话，再销毁通知器。
    unawaited(closeSocket());
    _listeners.clear();
    messageList.removeCallBack(_scrollToBottom);
    messageList.dispose();
    scrollController.dispose();
    textController.dispose();
    identityNotifier.dispose();
    roomSession.dispose();
    _reconnectNotifier.dispose();
  }

  String _summarizeMedia(String content, String type) {
    try {
      final json = jsonDecode(content);
      if (type == 'file') {
        final name = json['name'] as String? ?? 'file';
        final size = json['size'] as int? ?? 0;
        final sizeStr = size < 1024
            ? '$size B'
            : size < 1024 * 1024
            ? '${(size / 1024).toStringAsFixed(1)} KB'
            : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
        return '[$name, $sizeStr]';
      }
      final name = json['name'] as String?;
      return name != null ? '[$name]' : '[$type]';
    } catch (_) {
      return '[$type]';
    }
  }
}
