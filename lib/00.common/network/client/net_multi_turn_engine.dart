import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../protocol/network_message.dart';
import 'base/net_multi_engine.dart';
import 'room_chat_engine.dart';
import 'socket_client.dart';

/// 多人合作回合引擎：共享一个局面，由发布者校验并提交动作。
///
/// 与双人前后手引擎不同，这里按成员 ID 顺序轮转。每一步发布完整快照，
/// 收齐所有成员的应用层 ready 后才开放下一步；传输 ACK 不能替代状态同步。
/// 新成员沿用现有 gameId 并接收当前局面，发布者退出则使用共同快照接管。
class NetMultiTurnEngine extends NetMultiEngine {
  final currentPlayer = ValueNotifier<int?>(null);
  final revision = ValueNotifier(0);
  final pendingAction = ValueNotifier(false);
  final synchronized = ValueNotifier(false);
  Map<String, dynamic> Function()? _saveState;
  void Function(Map<String, dynamic>)? _loadState;
  bool Function(Map<String, dynamic>)? _applyAction;
  final Set<int> _readyPlayers = {};
  int _goRevision = -1;
  int _issuedRevision = 0;
  int? _snapshotPublisher;
  bool _disposed = false;

  NetMultiTurnEngine(super.client);

  static NetMultiTurnEngine forClient(SocketClient client) {
    final engine = RoomChatEngine.forClient(client);
    if (engine is! NetMultiTurnEngine) {
      throw StateError('Cooperative turn room is not authenticated');
    }
    return engine;
  }

  @override
  int get minimumParticipants => 1;

  bool get canAct =>
      isActive &&
      synchronized.value &&
      !pendingAction.value &&
      currentPlayer.value == identity;

  void configureTurns({
    required Map<String, dynamic> Function() saveState,
    required void Function(Map<String, dynamic>) loadState,
    required bool Function(Map<String, dynamic>) applyAction,
  }) {
    // 先检查/取得本局配置权，防止重复创建 Manager 时破坏仍在运行的一局。
    configureGame(
      searchHandler: (_) => _publishSnapshot(),
      resourceHandler: _receiveSnapshot,
      syncHandler: _receiveSync,
      actionHandler: _receiveAction,
      exitHandler: _memberExited,
    );
    _saveState = saveState;
    _loadState = loadState;
    _applyAction = applyAction;
    currentPlayer.value = null;
    revision.value = 0;
    pendingAction.value = false;
    synchronized.value = false;
    _readyPlayers.clear();
    _goRevision = -1;
    _issuedRevision = 0;
    _snapshotPublisher = null;
  }

  /// 只有当前操作者能发请求，不在请求方乐观推进棋盘。
  bool submitAction(Map<String, dynamic> action) {
    if (!canAct || publisherId == null) return false;
    pendingAction.value = true;
    sendGameMessage(
      MessageType.action,
      jsonEncode({'revision': revision.value, 'data': action}),
      recipientIds: {publisherId!},
    );
    return true;
  }

  List<int> get _turnOrder => participants.keys.toList()..sort();

  void _memberExited(int id) {
    synchronized.value = false;
    _readyPlayers.remove(id);
    if (currentPlayer.value == id) {
      // 成员删除后寻找离开者之后的第一人，避免总是回到队首。
      final order = _turnOrder;
      currentPlayer.value = order.isEmpty
          ? null
          : order.firstWhere(
              (candidate) => candidate > id,
              orElse: () => order.first,
            );
    }
  }

  void _publishSnapshot() {
    if (!isActive || publisherId != identity || participants.isEmpty) return;
    final order = _turnOrder;
    if (!participants.containsKey(currentPlayer.value)) {
      currentPlayer.value = order.first;
    }
    synchronized.value = false;
    pendingAction.value = false;
    _readyPlayers.clear();
    // 名单变化也产生新修订，迟到的动作和 ready 都不能推进新名单的局面。
    final nextRevision =
        (revision.value > _issuedRevision ? revision.value : _issuedRevision) +
        1;
    _issuedRevision = nextRevision;
    sendGameMessage(
      MessageType.resource,
      jsonEncode({
        'revision': nextRevision,
        'turn': currentPlayer.value,
        'state': _saveState!(),
      }),
    );
  }

  void _receiveSnapshot(NetworkMessage message) {
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    final number = data['revision'];
    final turn = data['turn'];
    if (number is! int ||
        number < revision.value ||
        (publisherId == identity && number < _issuedRevision) ||
        turn is! int ||
        !participants.containsKey(turn) ||
        data['state'] is! Map<String, dynamic>) {
      _openIfReady();
      return;
    }
    // 发布者在最后一份快照尚未收齐时退出，新发布者可能恰好发出相同修订号。
    // 此时必须重新装载共同局面，不能因本地修订号相同保留另一份棋盘。
    final changedPublisher = _snapshotPublisher != message.id;
    if (number > revision.value || changedPublisher) {
      _loadState!(data['state'] as Map<String, dynamic>);
      _snapshotPublisher = message.id;
      if (changedPublisher) _goRevision = -1;
      revision.value = number;
      currentPlayer.value = turn;
      synchronized.value = false;
      pendingAction.value = false;
    }
    sendGameMessage(
      MessageType.sync,
      jsonEncode({'phase': 'ready', 'revision': number}),
      recipientIds: {publisherId!},
    );
    _publishGoIfReady();
    _openIfReady();
  }

  void _receiveSync(NetworkMessage message) {
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    final number = data['revision'];
    if (number is! int) return;
    switch (data['phase']) {
      case 'ready':
        if (publisherId != identity || number != _issuedRevision) return;
        _readyPlayers.add(message.id);
        _publishGoIfReady();
      case 'go':
        if (message.id != publisherId || number < revision.value) return;
        _goRevision = number;
        _openIfReady();
      case 'rejected':
        if (message.id == publisherId && number == revision.value) {
          pendingAction.value = false;
        }
    }
  }

  void _publishGoIfReady() {
    if (publisherId != identity ||
        revision.value != _issuedRevision ||
        _goRevision == revision.value ||
        !_readyPlayers.containsAll(participants.keys)) {
      return;
    }
    // 发布者先开放本地接收，避免其他人先收到 go、立即发动作时被误当同步期丢弃。
    _goRevision = revision.value;
    _openIfReady();
    sendGameMessage(
      MessageType.sync,
      jsonEncode({'phase': 'go', 'revision': revision.value}),
    );
  }

  void _openIfReady() {
    if (_goRevision == revision.value &&
        (publisherId != identity || _issuedRevision == revision.value) &&
        completeSynchronization()) {
      synchronized.value = true;
    }
  }

  void _receiveAction(NetworkMessage message) {
    if (publisherId != identity ||
        !synchronized.value ||
        message.id != currentPlayer.value) {
      return;
    }
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    if (data['revision'] != revision.value) return;
    final action = data['data'];
    if (action is! Map<String, dynamic> || !_applyAction!(action)) {
      sendGameMessage(
        MessageType.sync,
        jsonEncode({'phase': 'rejected', 'revision': revision.value}),
        recipientIds: {message.id},
      );
      return;
    }
    final order = _turnOrder;
    currentPlayer.value = order[(order.indexOf(message.id) + 1) % order.length];
    _publishSnapshot();
  }

  @override
  void releaseGame() {
    super.releaseGame();
    _saveState = null;
    _loadState = null;
    _applyAction = null;
    _readyPlayers.clear();
    synchronized.value = false;
    pendingAction.value = false;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
    currentPlayer.dispose();
    revision.dispose();
    pendingAction.dispose();
    synchronized.dispose();
  }
}
