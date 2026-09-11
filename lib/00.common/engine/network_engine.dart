import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../config/network_config.dart';
import '../widget/dialog/template_dialog.dart';
import '../tool/notifiers.dart';
import '../network/network_message.dart';
import '../network/network_reliability.dart';
import '../network/network_room.dart';
import '../network/connection.dart' as conn;

class NetworkEngine {
  final ListNotifier<NetworkMessage> messageList = ListNotifier([]);
  final ScrollController scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();

  late conn.Connection _connection;
  final List<NetworkMessage> _sendBuffer = [];
  bool _isSending = false;
  Completer<void>? _sendCompleter;

  bool _isDisposed = false;
  bool _isClosing = false;
  bool _isClosed = true;

  int identity = 0;
  final ValueNotifier<int> identityNotifier = ValueNotifier<int>(0);

  final String userName;
  final RoomInfo roomInfo;
  final AlwaysNotifier<void Function(BuildContext)> navigatorHandler;
  void Function(NetworkMessage message) messageHandler = (_) {};
  VoidCallback? onReconnected;

  // ==================== 消息确认机制 ====================
  static const int _maxReceivedMessageIds = 1000;
  static const int _maxAckRetries = 5;
  static const Duration _ackRetryInterval = Duration(seconds: 2);
  final AckRetryTracker _pendingAcks = AckRetryTracker(
    retryInterval: _ackRetryInterval,
    maxRetries: _maxAckRetries,
  );
  final MessageIdCache _receivedMessageIds = MessageIdCache(
    capacity: _maxReceivedMessageIds,
  );
  Timer? _ackRetryTimer;

  // ==================== 断线重连 ====================
  bool _isReconnecting = false;
  final ValueNotifier<int> _reconnectNotifier = ValueNotifier(0);
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  bool _reconnectDialogShown = false;

  // ==================== 加密 ====================
  final String? encryptionKey;

  NetworkEngine({
    required this.userName,
    required this.roomInfo,
    required this.navigatorHandler,
  }) : encryptionKey = roomInfo.encryptionKey {
    messageList.addCallBack(_scrollToBottom);
    _connectToServer();
    _startKeyboard();
    _startAckRetry();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  // ==================== 连接管理 ====================

  Future<void> _connectToServer() async {
    _connection = await conn.Connection.connect(
      roomInfo.address,
      roomInfo.port,
    );
    _isClosed = false;
    _connection.listen(onData: _handleSocketData, onDone: _handleSocketDone);

    // scheme 2: 发送 connect 请求触发服务器回复 accept
    if (networkMode == NetworkMode.webSocket) {
      _connection.send(utf8.encode('{"connect":true}'));
    }
  }

  void _handleSocketData(List<int> data) {
    if (_isClosed || _isDisposed) return;
    final message = NetworkMessage.fromSocketData(
      data,
      encryptionKey: encryptionKey,
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
      MessageType.emoji ||
      MessageType.typing ||
      MessageType.broadcast ||
      MessageType.accept ||
      MessageType.ack ||
      MessageType.search ||
      MessageType.match ||
      MessageType.resource ||
      MessageType.sync ||
      MessageType.action ||
      MessageType.exit ||
      MessageType.notify ||
      MessageType.text => message.content,
    };
    debugPrint('${message.source} ${message.id} ${message.type} $summary');

    // 收到 ACK → 从待确认队列移除
    if (message.type == MessageType.ack) {
      _handleAck(message.content);
      return;
    }

    // 服务器关闭房间（id==0）→ 弹窗并退出
    if (message.type == MessageType.exit && message.id == 0) {
      _isClosing = true;
      _pendingAcks.clear();
      _reconnectTimer?.cancel();
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

    // 消息去重（LRU 淘汰：超出上限移除最旧条目，防长会话内存单调增长）
    if (message.messageId != null) {
      if (!_receivedMessageIds.add(message.messageId!)) return;
      if (message.id != identity && ackRequiredTypes.contains(message.type)) {
        _sendAck(message.messageId!);
      }
    }

    if ((message.type == MessageType.accept) && (identity == 0)) {
      identity = message.id;
      identityNotifier.value = message.id;
      sendNetworkMessage(MessageType.notify, "join in room");
    }

    if (message.type.index < MessageType.notify.index) {
      messageHandler(message);
    } else if (message.type.index >= MessageType.notify.index) {
      // typing 消息不加入消息列表，仅用于 UI 提示
      if (message.type != MessageType.typing) {
        messageList.add(message);
      }
    }
  }

  // ==================== 消息确认机制 ====================

  void _startAckRetry() {
    _ackRetryTimer = Timer.periodic(_ackRetryInterval, (_) {
      _retryPendingAcks();
    });
  }

  void _retryPendingAcks() {
    if (_isClosed || _isDisposed || _pendingAcks.isEmpty) return;

    final batch = _pendingAcks.poll(DateTime.now());
    for (final message in batch.messages) {
      _rawSend(message);
    }
    if (batch.hasTimeout) _handleAckTimeout();
  }

  void _handleAck(String messageId) {
    _pendingAcks.acknowledge(messageId);
  }

  void _sendAck(String messageId) {
    final ack = NetworkMessage.ack(messageId, identity);
    _rawSend(ack);
  }

  void _handleAckTimeout() {
    if (_isClosing || _isDisposed) return;
    // ACK 超时 → 触发断线重连
    _pendingAcks.clear();
    _attemptReconnect();
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

    // 关闭旧连接
    _connection.close();

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
          );
        };
      }

      // 已达最大重试次数，不再重试
      if (_reconnectNotifier.value >= _maxReconnectAttempts) {
        _isReconnecting = false;
        return;
      }

      try {
        _connection = await conn.Connection.connect(
          roomInfo.address,
          roomInfo.port,
        );
        _isClosed = false;
        _isReconnecting = false;

        // 重新监听
        _connection.listen(
          onData: _handleSocketData,
          onDone: _handleSocketDone,
        );

        // 重新进入房间
        _onReconnected();
      } catch (_) {
        _doReconnect(); // 继续重试
      }
    });
  }

  void _onReconnected() {
    // 清空旧状态
    _pendingAcks.clear();
    _receivedMessageIds.clear();
    _sendBuffer.clear();
    identity = 0;
    identityNotifier.value = 0; // 重新等待 accept 分配新 ID

    // 关闭重连对话框
    navigatorHandler.value = (context) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    };

    // 通知子类重连完成（用于重置游戏状态）
    onReconnected?.call();
  }

  // ==================== 消息发送 ====================

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

  void sendNetworkMessage(MessageType type, String content) {
    if (identity == 0 || _isDisposed) return;

    final message = NetworkMessage(
      id: identity,
      type: type,
      source: userName,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // 为需要 ACK 的消息生成唯一 ID
    message.ensureMessageId();

    // 加入待确认队列
    if (message.messageId != null) {
      _pendingAcks.track(message);
    }

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
    if (identity == 0 || _isDisposed) return;
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

    try {
      while (_sendBuffer.isNotEmpty) {
        final message = _sendBuffer.first;
        _rawSend(message);
        await _connection.flush();
        _sendBuffer.removeAt(0);
      }
    } catch (e) {
      _sendBuffer.clear();
    } finally {
      _isSending = false;
      _sendCompleter?.complete();
      _sendCompleter = null;
    }
  }

  /// 底层发送（加密后写入连接）
  void _rawSend(NetworkMessage message) {
    if (_isClosed) return;
    _connection.send(message.toSocketData(encryptionKey: encryptionKey));
  }

  // ==================== 生命周期 ====================

  void leavePage() {
    closeSocket();
    _navigateToBack();
  }

  Future<void> closeSocket() async {
    if (!_isClosed && !_isClosing) {
      _isClosing = true;
      _stopKeyboard();
      _ackRetryTimer?.cancel();
      _reconnectTimer?.cancel();

      sendNetworkMessage(MessageType.notify, 'leave room');

      // 等待发送队列清空
      if (_isSending) {
        _sendCompleter ??= Completer<void>();
        await _sendCompleter!.future;
      }
      await _pushMessage();

      _isClosed = true;
      await _connection.close();
    }
  }

  void _navigateToBack() {
    navigatorHandler.value = (BuildContext context) {
      Navigator.pop(context);
    };

    if (!_isDisposed) {
      _isDisposed = true;
      messageList.removeCallBack(_scrollToBottom);
      _ackRetryTimer?.cancel();
      _reconnectTimer?.cancel();
    }
  }

  void _startKeyboard() {
    HardwareKeyboard.instance.addHandler(_handleChatKeyboardEvent);
  }

  void _stopKeyboard() {
    HardwareKeyboard.instance.removeHandler(_handleChatKeyboardEvent);
  }

  bool _handleChatKeyboardEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      sendInputText();
      return true;
    }
    return false;
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
