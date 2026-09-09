import 'dart:convert';

import '../00.common/engine/net_real_engine.dart';
import '../00.common/game/step.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import 'base.dart';
import 'foundation_manager.dart';

/// 联机模式：各自模拟 + Host 下发 AI 决策 + 拥有者权威 hit 仲裁。
/// - host（最小 id）：跑 AI 决策/刷怪/命中判定，经 action 广播
/// - client：只跑移动/子弹飞行/砖墙销毁，AI 与 hit 由 action 驱动
class NetTankManager extends FoundationalTankManager {
  late final NetRealGameEngine engine;

  int _pendingSync = 0; // host 等待就绪的 client 数
  final List<int> _playerIds = []; // 其他玩家 identity（重开重建用）

  NetTankManager({required String userName, required RoomInfo roomInfo}) {
    engine = NetRealGameEngine(
      userName: userName,
      roomInfo: roomInfo,
      navigatorHandler: pageNavigator,
      searchHandler: _handleSearch,
      resourceHandler: _handleResource,
      syncHandler: _handleSync,
      actionHandler: _handleAction,
      exitHandler: _handleEnd,
    );
    initTicker();
  }

  @override
  int get identity => engine.identity;

  /// host = 玩家坦克 key 的最小值（与引擎 _publisherId 一致）
  @override
  bool get isAuthority {
    final keys = tanks.entries
        .where((e) => e.value.isPlayer)
        .map((e) => e.key)
        .toList();
    if (keys.isEmpty) return false;
    keys.sort();
    return identity == keys.first;
  }

  // ---- 握手 ----

  void _handleSearch(int id) {
    // 仅 host 触发：确保双方玩家存在，发全量快照
    if (!tanks.containsKey(identity)) addPlayerTank(identity);
    if (!tanks.containsKey(id)) addPlayerTank(id);
    if (!_playerIds.contains(id)) _playerIds.add(id);
    _pendingSync++;
    engine.sendNetworkMessage(MessageType.resource, json.encode(toJson()));
  }

  void _handleResource(NetworkMessage message) {
    fromJson(json.decode(message.content) as Map<String, dynamic>);
    resumeGame(); // client 开始模拟（玩家 idle，AI 等 host 决策）
    engine.sendNetworkMessage(MessageType.sync, 'ready');
  }

  void _handleSync(int id) {
    if (_pendingSync <= 0) return;
    _pendingSync--;
    if (_pendingSync == 0) {
      engine.gameStep.value = GameStep.action; // host 进入游戏阶段
      resumeGame(); // host 开始跑 AI/刷怪
    }
  }

  // ---- 远端 action 分发 ----

  void _handleAction(NetworkMessage message) {
    final c = json.decode(message.content) as Map<String, dynamic>;
    final actionType = c['actionType'] as String;
    switch (actionType) {
      case 'move':
        final t = tanks[message.id];
        if (t != null) {
          final d = Direction.fromName(c['dir'] as String);
          t.direction = d;
          t.turretDirection = d;
          t.moving = true;
        }
        break;
      case 'stop':
        final t = tanks[message.id];
        if (t != null) t.moving = false;
        break;
      case 'fire':
        final t = tanks[message.id];
        if (t != null) fire(t);
        break;
      case 'aiTurn':
        final t = tanks[c['key'] as int];
        if (t != null) {
          final d = Direction.fromName(c['dir'] as String);
          t.direction = d;
          t.turretDirection = d;
        }
        break;
      case 'aiFire':
        final t = tanks[c['key'] as int];
        if (t != null) {
          t.turretDirection = Direction.fromName(c['dir'] as String);
          fire(t);
        }
        break;
      case 'spawn':
        final key = c['key'] as int;
        final tank = Tank.fromJson(c['tank'] as Map<String, dynamic>);
        tanks[key] = tank;
        if (!tank.isPlayer) enemiesOnField++;
        break;
      case 'hit':
        final key = c['key'] as int;
        final isBase = c['base'] as bool;
        if (isBase) {
          applyBaseHit();
        } else {
          applyHit(key);
        }
        break;
      case 'restart':
        // client 请求重开，host 重新发牌
        if (isAuthority) _restartMatch();
        break;
    }
  }

  void _handleEnd(int id) {
    tanks.remove(id);
    livesByPlayer.remove(id);
    _playerIds.remove(id);
  }

  // ---- 玩家输入：本地立即响应 + 广播 ----

  @override
  void updatePlayerDirection(Direction dir) {
    final t = tanks[identity];
    if (t == null || !t.isAlive) return;
    t.direction = dir;
    t.turretDirection = dir;
    t.moving = true;
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': 'move', 'dir': dir.name}),
    );
  }

  @override
  void updatePlayerStop() {
    final t = tanks[identity];
    if (t != null) t.moving = false;
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': 'stop'}),
    );
  }

  @override
  void updatePlayerFire() {
    final t = tanks[identity];
    if (t == null) return;
    fire(t); // 拥有者权威：本地立即开火
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': 'fire'}),
    );
  }

  // ---- 广播钩子（host 发 action） ----

  @override
  void broadcastAiTurn(int tankKey, Direction dir) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': 'aiTurn', 'key': tankKey, 'dir': dir.name}),
    );
  }

  @override
  void broadcastAiFire(int tankKey, Direction dir) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': 'aiFire', 'key': tankKey, 'dir': dir.name}),
    );
  }

  @override
  void broadcastSpawn(int tankKey, Tank tank) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': 'spawn', 'key': tankKey, 'tank': tank.toJson()}),
    );
  }

  @override
  void broadcastHit(int tankKey, bool isBase) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': 'hit', 'key': tankKey, 'base': isBase}),
    );
  }

  @override
  void handleRemoveTankCallback(int tankKey) {}

  @override
  void handleGameOverCallback() {
    // 不关闭连接，保留 socket 供重开使用；真正退出由 leavePage 处理
  }

  /// 联机重开：host 重置并发 resource 重新握手；client 请求 host 重开
  @override
  void requestRestart() {
    if (isAuthority) {
      _restartMatch();
    } else {
      engine.sendNetworkMessage(
        MessageType.action,
        json.encode({'actionType': 'restart'}),
      );
    }
  }

  void _restartMatch() {
    if (!isAuthority) return;
    suspendGame();
    resetState();
    addPlayerTank(identity);
    for (final id in _playerIds) {
      addPlayerTank(id);
    }
    engine.gameStep.value = GameStep.action;
    if (_playerIds.isEmpty) {
      resumeGame();
      return;
    }
    _pendingSync = _playerIds.length;
    engine.sendNetworkMessage(MessageType.resource, json.encode(toJson()));
  }

  @override
  void leavePage() {
    engine.leavePage();
  }
}
