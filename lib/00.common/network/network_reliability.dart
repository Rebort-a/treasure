import 'network_message.dart';

/// 有界、按插入顺序淘汰的消息 ID 去重缓存。
class MessageIdCache {
  final int capacity;
  final Set<String> _ids = {};

  MessageIdCache({required this.capacity}) : assert(capacity > 0);

  int get length => _ids.length;

  /// 新 ID 返回 true；重复 ID 返回 false。
  bool add(String id) {
    if (_ids.contains(id)) return false;
    _ids.add(id);
    while (_ids.length > capacity) {
      _ids.remove(_ids.first);
    }
    return true;
  }

  bool contains(String id) => _ids.contains(id);

  void clear() => _ids.clear();
}

class AckRetryBatch {
  final List<NetworkMessage> messages;
  final bool hasTimeout;

  const AckRetryBatch({required this.messages, required this.hasTimeout});
}

/// ACK 待确认队列的纯状态机，不直接依赖 Timer 或 Socket，便于确定性测试。
class AckRetryTracker {
  final Duration retryInterval;
  final int maxRetries;
  final Map<String, _PendingAck> _pending = {};

  AckRetryTracker({required this.retryInterval, required this.maxRetries})
    : assert(maxRetries >= 0);

  bool get isEmpty => _pending.isEmpty;
  int get length => _pending.length;

  void track(NetworkMessage message, {DateTime? now}) {
    final id = message.messageId;
    if (id == null) return;
    _pending[id] = _PendingAck(message: message, sentAt: now ?? DateTime.now());
  }

  void acknowledge(String messageId) => _pending.remove(messageId);

  AckRetryBatch poll(DateTime now) {
    final retry = <NetworkMessage>[];
    bool hasTimeout = false;

    for (final entry in _pending.entries.toList()) {
      final pending = entry.value;
      if (now.difference(pending.sentAt) < retryInterval) continue;

      if (pending.retryCount >= maxRetries) {
        _pending.remove(entry.key);
        hasTimeout = true;
      } else {
        pending.retryCount++;
        pending.sentAt = now;
        retry.add(pending.message);
      }
    }

    return AckRetryBatch(messages: retry, hasTimeout: hasTimeout);
  }

  void clear() => _pending.clear();
}

class _PendingAck {
  final NetworkMessage message;
  int retryCount = 0;
  DateTime sentAt;

  _PendingAck({required this.message, required this.sentAt});
}

/// 第 [attempt] 次重连前的指数退避：1、2、4、8、16 秒。
Duration reconnectDelayForAttempt(int attempt, {int maxExponent = 4}) {
  if (attempt < 0) {
    throw ArgumentError.value(attempt, 'attempt', 'must be non-negative');
  }
  final exponent = attempt > maxExponent ? maxExponent : attempt;
  return Duration(seconds: 1 << exponent);
}
