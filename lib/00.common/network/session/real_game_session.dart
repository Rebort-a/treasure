import 'dart:convert';

import '../../game/step.dart';
import '../network_message.dart';
import 'game_session.dart';

/// 实时对局的参与者名单、发布者和每轮资源同步由房内玩家维护。
class RealGameSession extends GameSession {
  final int? maxPlayers;
  final void Function(int) searchHandler;
  final void Function(NetworkMessage) resourceHandler;
  final void Function(NetworkMessage) syncHandler;
  final void Function(NetworkMessage) actionHandler;
  final void Function(int) exitHandler;
  final Map<int, String> _participants = {};
  final Set<int> _invited = {};
  final Set<int> _publishVotes = {};
  int? publisherId;
  bool _awaitingResource = false;
  Map<int, String> get participants => Map.unmodifiable(_participants);

  RealGameSession({
    required super.room,
    required this.searchHandler,
    required this.resourceHandler,
    required this.syncHandler,
    required this.actionHandler,
    required this.exitHandler,
    this.maxPlayers,
  });

  @override
  void startFromRoom() {
    final opponent = room.matchedOpponentId;
    if (opponent <= 0) return;
    startMatched(
      opponentId: opponent,
      publisherId: room.matchInitiated ? identity : opponent,
      isPublisher: room.matchInitiated,
    );
  }

  void startMatched({
    required int opponentId,
    required int publisherId,
    required bool isPublisher,
  }) {
    if (isActive || ended.value) return;
    this.publisherId = publisherId;
    _participants
      ..clear()
      ..addAll({
        identity: room.members.value[identity] ?? userName,
        opponentId: room.members.value[opponentId] ?? '',
      });
    _awaitingResource = true;
    gameStep.value = isPublisher ? GameStep.frontWait : GameStep.rearWait;
    super.activateAfterMatch();
    if (!isActive) return;
    readyToOpen.value = true;
    if (isPublisher) searchHandler(opponentId);
  }

  @override
  void sendNetworkMessage(
    MessageType type,
    String content, {
    int? recipientId,
    Set<int>? recipientIds,
  }) {
    if (!isActive || recipientId != null) return;
    if (type == MessageType.image || type == MessageType.file) return;
    if (type == MessageType.resource) {
      if (publisherId != identity) return;
      content = jsonEncode({
        'players': _participants.keys.toList(),
        'data': content,
      });
    }
    final targets = recipientIds ?? _participants.keys.toSet();
    if (targets.isEmpty ||
        targets.any((id) => !_participants.containsKey(id))) {
      return;
    }
    super.sendNetworkMessage(type, content, recipientIds: targets);
  }

  @override
  void handleMessage(NetworkMessage message) {
    if (!isActive) return;
    if (message.type == MessageType.search && message.isRoomMessage) {
      if (publisherId == identity &&
          message.id != identity &&
          !_participants.containsKey(message.id) &&
          !_invited.contains(message.id) &&
          (maxPlayers == null ||
              _participants.length + _invited.length < maxPlayers!)) {
        _invited.add(message.id);
        room.sendNetworkMessage(MessageType.match, '', recipientId: message.id);
      }
      return;
    }
    if (message.type == MessageType.confirm &&
        message.isPrivateMessage &&
        message.recipientId == identity &&
        _invited.remove(message.id) &&
        publisherId == identity) {
      _participants[message.id] = room.members.value[message.id] ?? '';
      _awaitingResource = true;
      gameStep.value = GameStep.synchronizing;
      searchHandler(message.id);
      return;
    }
    if (!message.isGroupMessage ||
        !(message.recipientIds?.contains(identity) ?? false)) {
      return;
    }
    if (message.type == MessageType.gameExit) {
      if (message.id != identity) _removeMember(message.id);
      return;
    }
    if (message.type == MessageType.publish) {
      if (publisherId != null || !_participants.containsKey(message.id)) {
        return;
      }
      _publishVotes.add(message.id);
      if (_publishVotes.length == _participants.length) {
        publisherId = (_participants.keys.toList()..sort()).first;
        _publishVotes.clear();
        if (publisherId == identity) searchHandler(identity);
      }
      return;
    }
    if (!_participants.containsKey(message.id)) return;
    if (const {
      MessageType.resource,
      MessageType.sync,
      MessageType.action,
    }.contains(message.type)) {
      if (publisherId == null || message.id < publisherId!) {
        publisherId = message.id;
      }
    }
    if (message.type == MessageType.resource) {
      if (message.id != publisherId) return;
      final envelope = jsonDecode(message.content) as Map<String, dynamic>;
      final ids = (envelope['players'] as List<dynamic>).cast<int>();
      if (!ids.contains(identity) ||
          ids.length < 2 ||
          ids.toSet().length != ids.length ||
          !ids.toSet().containsAll(message.recipientIds!)) {
        return;
      }
      _participants
        ..clear()
        ..addEntries(
          ids.map((id) => MapEntry(id, room.members.value[id] ?? '')),
        );
      _awaitingResource = false;
      gameStep.value = GameStep.synchronizing;
      resourceHandler(
        NetworkMessage(
          id: message.id,
          type: message.type,
          source: message.source,
          content: envelope['data'] as String,
          recipientIds: message.recipientIds,
        ),
      );
      return;
    }
    if (message.type == MessageType.sync) syncHandler(message);
    if (message.type == MessageType.action &&
        gameStep.value == GameStep.action) {
      actionHandler(message);
    }
    if (message.type == MessageType.text) messageList.add(message);
  }

  void _removeMember(int id) {
    if (_participants.remove(id) == null) return;
    _invited.remove(id);
    final lostPublisher = publisherId == id;
    _awaitingResource = true;
    gameStep.value = GameStep.synchronizing;
    exitHandler(id);
    if (lostPublisher) {
      publisherId = null;
      _publishVotes.clear();
      if (_participants.isNotEmpty) {
        sendNetworkMessage(MessageType.publish, '');
      }
    } else if (publisherId == identity && _participants.isNotEmpty) {
      searchHandler(identity);
    }
  }

  @override
  void memberLeft(int memberId) => _removeMember(memberId);

  bool completeSynchronization() {
    if (!isActive || _awaitingResource || _participants.length < 2) {
      return false;
    }
    gameStep.value = GameStep.action;
    readyToOpen.value = true;
    return true;
  }
}
