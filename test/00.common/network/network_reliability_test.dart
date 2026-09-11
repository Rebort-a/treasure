import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/network_message.dart';
import 'package:treasure/00.common/network/network_reliability.dart';

void main() {
  group('MessageIdCache', () {
    test('拒绝重复 ID，并按插入顺序淘汰最旧项', () {
      final cache = MessageIdCache(capacity: 2);

      expect(cache.add('a'), isTrue);
      expect(cache.add('a'), isFalse);
      expect(cache.add('b'), isTrue);
      expect(cache.add('c'), isTrue);

      expect(cache.contains('a'), isFalse);
      expect(cache.contains('b'), isTrue);
      expect(cache.contains('c'), isTrue);
      expect(cache.length, 2);
    });
  });

  group('AckRetryTracker', () {
    NetworkMessage message(String id) => NetworkMessage(
      id: 1,
      type: MessageType.action,
      source: 'tester',
      content: 'move',
      messageId: id,
    );

    test('未到间隔不重试，到达间隔后返回原消息', () {
      final start = DateTime(2026, 9, 11, 12);
      final tracker = AckRetryTracker(
        retryInterval: const Duration(seconds: 2),
        maxRetries: 2,
      )..track(message('m1'), now: start);

      expect(
        tracker.poll(start.add(const Duration(seconds: 1))).messages,
        isEmpty,
      );
      final due = tracker.poll(start.add(const Duration(seconds: 2)));
      expect(due.messages.single.messageId, 'm1');
      expect(due.hasTimeout, isFalse);
    });

    test('ACK 会移除待确认消息', () {
      final tracker = AckRetryTracker(
        retryInterval: const Duration(seconds: 1),
        maxRetries: 1,
      )..track(message('m1'), now: DateTime(2026, 9, 11));

      tracker.acknowledge('m1');

      expect(tracker.isEmpty, isTrue);
    });

    test('达到最大重试次数后报告超时并移除', () {
      final start = DateTime(2026, 9, 11);
      final tracker = AckRetryTracker(
        retryInterval: const Duration(seconds: 1),
        maxRetries: 2,
      )..track(message('m1'), now: start);

      expect(
        tracker.poll(start.add(const Duration(seconds: 1))).messages,
        hasLength(1),
      );
      expect(
        tracker.poll(start.add(const Duration(seconds: 2))).messages,
        hasLength(1),
      );
      final timeout = tracker.poll(start.add(const Duration(seconds: 3)));

      expect(timeout.messages, isEmpty);
      expect(timeout.hasTimeout, isTrue);
      expect(tracker.isEmpty, isTrue);
    });
  });

  test('指数退避为 1/2/4/8/16 秒，并在上限封顶', () {
    expect(List.generate(7, (i) => reconnectDelayForAttempt(i).inSeconds), [
      1,
      2,
      4,
      8,
      16,
      16,
      16,
    ]);
    expect(() => reconnectDelayForAttempt(-1), throwsArgumentError);
  });
}
