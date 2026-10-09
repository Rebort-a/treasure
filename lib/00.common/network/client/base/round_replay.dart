import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../protocol/network_message.dart';

/// 会话内重开协议：聊天沿用会话，棋盘消息用轮次及名单版本隔离。
/// 最小成员 ID 协调准备屏障，不要求协调者本人参加下一局。
class RoundReplay {
  static const prefix = '@round-replay:';
  final int Function() identity;
  final Map<int, String> Function() availableMembers;
  final void Function(String, Set<int>) send;
  final void Function(List<int>, bool, bool) start;
  final VoidCallback onFinished;
  final VoidCallback onDrain;
  final void Function(int) onMemberLeft;
  final finished = ValueNotifier(false);
  final waiting = ValueNotifier(false);
  final preparing = ValueNotifier(false);

  /// 会话成员包含尚未准备的玩家，与引擎的当前棋盘成员表相互独立。
  final Map<int, String> members = {};
  Set<int> _active = {};
  final Set<int> _requests = {};
  final Set<int> _acks = {};
  Map<String, dynamic>? _proposal;
  bool _closed = false;
  int round = 0;
  int version = 0;
  int? publisher;
  int _serial = 0;

  RoundReplay({
    required this.identity,
    required this.availableMembers,
    required this.send,
    required this.start,
    required this.onFinished,
    required this.onDrain,
    required this.onMemberLeft,
  });

  int? get _coordinator =>
      members.isEmpty ? null : (members.keys.toList()..sort()).first;

  void observe(Map<int, String> roster) {
    final added = roster.keys.any((id) => !members.containsKey(id));
    members.addAll(roster);
    if (!_closed && !finished.value) _active = roster.keys.toSet();
    if (added && round > 0 && _active.contains(identity())) {
      _send({
        'phase': 'roster',
        'round': round,
        'version': version,
        'players': members.keys.toList(),
        'active': _active.toList(),
      });
    }
  }

  /// 大厅新加入者从已确认邀请方的首份快照继承当前轮次。
  void bootstrap(int currentRound, int currentVersion) {
    if (round != 0 || version != 0 || _closed || preparing.value) return;
    if (currentRound < 0 || currentVersion < 0) return;
    round = currentRound;
    version = currentVersion;
    _serial = currentVersion;
  }

  void _send(Map<String, dynamic> data) {
    if (members.isNotEmpty) {
      send('$prefix${jsonEncode(data)}', members.keys.toSet());
    }
  }

  void complete() {
    if (_closed || !_active.contains(identity())) return;
    _finish();
    _send({'phase': 'over', 'round': round});
  }

  void _finish() {
    _closed = true;
    _requests.clear();
    _proposal = null;
    _acks.clear();
    preparing.value = false;
    waiting.value = false;
    finished.value = true;
    onFinished();
  }

  void request() {
    if (!finished.value || waiting.value || preparing.value) return;
    waiting.value = true;
    _send({'phase': 'ready', 'round': _closed ? round + 1 : round});
  }

  void leave() => _send({'phase': 'leave'});

  void remove(int id) {
    if (!members.containsKey(id)) return;
    members.remove(id);
    _active.remove(id);
    _requests.remove(id);
    if (_active.isEmpty && !_closed) _finish();
    _proposal = null;
    _acks.clear();
    preparing.value = false;
    _tryPropose();
  }

  bool accepts(int messageRound, int messageVersion) =>
      messageRound == round && messageVersion == version;

  bool isPending(int messageRound, int messageVersion) =>
      _proposal?['round'] == messageRound &&
      _proposal?['version'] == messageVersion;

  /// 控制消息不依赖当前棋盘轮次，未参加新局的玩家也持续接收。
  bool handle(NetworkMessage message) {
    if (message.type != MessageType.sync ||
        !message.content.startsWith(prefix)) {
      return false;
    }
    if (!members.containsKey(message.id) ||
        message.isRoomMessage ||
        !message.recipientIds.contains(identity())) {
      return true;
    }
    final data = jsonDecode(message.content.substring(prefix.length));
    if (data is! Map<String, dynamic>) return true;
    switch (data['phase']) {
      case 'roster':
        final players = data['players'];
        final active = data['active'];
        final available = availableMembers();
        if (_active.contains(message.id) &&
            data['round'] == round &&
            data['version'] == version &&
            players is List &&
            active is List &&
            active.contains(message.id) &&
            active.every((id) => id is int && players.contains(id)) &&
            players.every((id) => id is int && available.containsKey(id)) &&
            players.toSet().containsAll(members.keys)) {
          members.addAll({
            for (final id in players.cast<int>()) id: available[id]!,
          });
          _active = active.cast<int>().toSet();
        }
      case 'leave':
        if (message.id != identity()) {
          remove(message.id);
          onMemberLeft(message.id);
        }
      case 'over':
        if (data['round'] == round &&
            _active.contains(message.id) &&
            !_closed) {
          _finish();
        }
      case 'ready':
        final target = _closed ? round + 1 : round;
        if (data['round'] != target ||
            (!_closed && _active.contains(message.id))) {
          return true;
        }
        _requests.add(message.id);
        _tryPropose();
      case 'prepare':
        if (message.id != _coordinator || !_validProposal(data)) return true;
        final serial = data['version'] as int;
        if (serial <= version || serial < _serial) return true;
        _serial = serial;
        _proposal = data;
        final players = (data['players'] as List).cast<int>();
        if (players.contains(identity())) {
          preparing.value = true;
          _send({'phase': 'ack', 'round': data['round'], 'version': serial});
        }
      case 'ack':
        if (identity() != _coordinator ||
            data['round'] != _proposal?['round'] ||
            data['version'] != _proposal?['version'] ||
            !(_proposal?['players'] as List? ?? []).contains(message.id)) {
          return true;
        }
        _acks.add(message.id);
        if (_acks.containsAll((_proposal!['players'] as List).cast<int>())) {
          _send({..._proposal!, 'phase': 'begin'});
        }
      case 'begin':
        if (message.id != _coordinator ||
            !_validProposal(data) ||
            (data['version'] as int) <= version ||
            (data['version'] as int) < _serial) {
          return true;
        }
        final players = (data['players'] as List).cast<int>();
        final fresh = data['round'] != round;
        final joining = !_active.contains(identity());
        round = data['round'] as int;
        version = data['version'] as int;
        publisher = data['publisher'] as int;
        _serial = version;
        _active = players.toSet();
        _closed = false;
        _proposal = null;
        _acks.clear();
        _requests.removeAll(players);
        preparing.value = false;
        waiting.value = false;
        finished.value = !players.contains(identity());
        if (!finished.value) start(players, fresh, joining);
        onDrain();
        _tryPropose();
    }
    return true;
  }

  bool _validProposal(Map<String, dynamic> data) {
    final nextRound = data['round'];
    final nextVersion = data['version'];
    final players = data['players'];
    return nextRound is int &&
        nextRound >= round &&
        nextRound <= round + 1 &&
        nextVersion is int &&
        nextVersion > 0 &&
        players is List &&
        players.length >= 2 &&
        players.length <= members.length &&
        players.every((id) => id is int && members.containsKey(id)) &&
        players.toSet().length == players.length &&
        players.contains(data['publisher']) &&
        (_closed || players.toSet().containsAll(_active));
  }

  void _tryPropose() {
    if (identity() != _coordinator || _proposal != null) return;
    final players = (_closed ? _requests : {..._active, ..._requests}).toList()
      ..sort();
    if (players.length < 2 || (!_closed && players.length == _active.length)) {
      return;
    }
    _proposal = {
      'phase': 'prepare',
      'round': _closed ? round + 1 : round,
      'version': ++_serial,
      'players': players,
      // 新局由最先准备者发布；中途加入不更换发布者，避免重新抽取当前棋盘。
      'publisher': _closed
          ? _requests.first
          : _active.contains(publisher)
          ? publisher
          : (_active.toList()..sort()).first,
    };
    _acks.clear();
    _send(_proposal!);
  }

  void dispose() {
    finished.dispose();
    waiting.dispose();
    preparing.dispose();
  }
}
