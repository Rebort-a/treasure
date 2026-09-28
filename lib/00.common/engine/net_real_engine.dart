import 'dart:convert';

import '../game/step.dart';
import '../network/network_message.dart';
import 'net_game_engine.dart';

class NetRealGameEngine extends NetGameEngine {
  final int? maxPlayers;
  final void Function(int) searchHandler;
  final void Function(NetworkMessage) resourceHandler;
  final void Function(NetworkMessage) syncHandler;
  final void Function(NetworkMessage) actionHandler;
  final void Function(int) exitHandler;
  final Map<int, String> _participants = {};
  final Map<int, String> _waiting = {};
  int? publisherId;
  bool _searchEchoed = false;

  NetRealGameEngine({
    required super.room,
    required this.searchHandler,
    required this.resourceHandler,
    required this.syncHandler,
    required this.actionHandler,
    required this.exitHandler,
    this.maxPlayers,
  });

  @override
  void start() {
    if (isActive || ended.value || identity == 0) return;
    publisherId = identity;
    _participants[identity] = requestId;
    super.start();
  }

  @override
  void sendNetworkMessage(MessageType type, String content, {int? targetId}) {
    if (type == MessageType.text ||
        type == MessageType.image ||
        type == MessageType.file ||
        type == MessageType.emoji) {
      return;
    }
    if (type == MessageType.resource) {
      content = jsonEncode({
        'players': _participants.map((id, request) => MapEntry('$id', request)),
        'data': content,
      });
    }
    if (type == MessageType.exit) content = jsonEncode({'request': requestId});
    super.sendNetworkMessage(type, content, targetId: targetId);
  }

  @override
  void handleMessage(NetworkMessage message) {
    if (message.type == MessageType.search) {
      if (message.id == identity && message.sessionId == requestId) {
        _searchEchoed = true;
        return;
      }
      if (!_searchEchoed ||
          message.id == identity ||
          message.sessionId == null ||
          publisherId != identity) {
        return;
      }
      if (_participants[message.id] == message.sessionId) return;
      _waiting[message.id] = message.sessionId!;
      if (maxPlayers != null && _participants.length >= maxPlayers!) {
        super.sendNetworkMessage(
          MessageType.match,
          jsonEncode({'waitingFor': message.sessionId}),
          targetId: message.id,
        );
      }
      _admitNext();
      return;
    }
    if (message.type == MessageType.match &&
        gameStep.value == GameStep.start &&
        message.targetId == identity) {
      final data = jsonDecode(message.content) as Map<String, dynamic>;
      if (data['waitingFor'] == requestId) publisherId = message.id;
      return;
    }
    if (message.type == MessageType.resource && message.sessionId != null) {
      final envelope = jsonDecode(message.content) as Map<String, dynamic>;
      final raw = envelope['players'] as Map<String, dynamic>;
      if (raw['$identity'] != requestId || raw.length < 2) return;
      if (gameStep.value != GameStep.start && message.sessionId != sessionId) {
        return;
      }
      if (!raw.containsKey('${message.id}')) return;
      publisherId = message.id;
      sessionId = message.sessionId!;
      _participants
        ..clear()
        ..addAll(
          raw.map((id, request) => MapEntry(int.parse(id), request as String)),
        );
      gameStep.value = GameStep.synchronizing;
      resourceHandler(
        NetworkMessage(
          id: message.id,
          type: message.type,
          source: message.source,
          content: envelope['data'] as String,
          sessionId: sessionId,
        ),
      );
      return;
    }
    if (message.type == MessageType.exit && message.id != identity) {
      if (gameStep.value == GameStep.start &&
          !_participants.containsKey(message.id)) {
        if (publisherId == message.id) publisherId = identity;
        // 可能已有空位，或新发布者需要重新收到当前排队请求。
        super.sendNetworkMessage(MessageType.search, 'search');
      }
      if (message.sessionId == null ||
          _waiting[message.id] == message.sessionId) {
        _waiting.remove(message.id);
      }
      if (!_participants.containsKey(message.id) ||
          (message.sessionId != null && message.sessionId != sessionId)) {
        return;
      }
      if (message.sessionId != null &&
          (jsonDecode(message.content) as Map<String, dynamic>)['request'] !=
              _participants[message.id]) {
        return;
      }
      _participants.remove(message.id);
      if (publisherId == message.id) {
        // 所有参与者使用同一份成员快照，选举 ID 最小的成员作为发布者。
        final remaining = _participants.keys.toList()..sort();
        publisherId = remaining.isEmpty ? identity : remaining.first;
      }
      exitHandler(message.id);
      _admitNext();
      return;
    }
    if (message.sessionId != sessionId ||
        !_participants.containsKey(message.id)) {
      return;
    }
    if (message.type == MessageType.sync) syncHandler(message);
    if (message.type == MessageType.action &&
        gameStep.value == GameStep.action) {
      actionHandler(message);
    }
  }

  void _admitNext() {
    if (publisherId != identity ||
        _waiting.isEmpty ||
        (maxPlayers != null && _participants.length >= maxPlayers!)) {
      return;
    }
    final next = _waiting.entries.first;
    _waiting.remove(next.key);
    _participants[next.key] = next.value;
    searchHandler(next.key);
  }

  /// 仅在游戏完成全员同步后调用，不能在刚收到资源时调用。
  bool completeSynchronization() {
    if (!isActive || (!readyToOpen.value && _participants.length < 2)) {
      return false;
    }
    gameStep.value = GameStep.action;
    readyToOpen.value = true;
    return true;
  }
}
