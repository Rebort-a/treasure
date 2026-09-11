import 'dart:convert';

import '../00.common/engine/net_real_engine.dart';
import '../00.common/game/step.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import 'base.dart';
import 'foundation_manager.dart';

/// 联机 action 协议类型（收发双方共用，避免裸字符串拼写错误）。
enum TankAction {
  move,
  stop,
  aim,
  aimStop,
  fire,
  aiTurn,
  aiFire,
  spawn,
  hit,
  restart,
}

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
    // 安全查表：未知 actionType 返回 null（优雅忽略，不崩溃）
    final rawAction = c['actionType'];
    if (rawAction is! String) return;
    final action = TankAction.values.asNameMap()[rawAction];
    if (action == null) return;
    switch (action) {
      case TankAction.move:
        final t = tanks[message.id];
        if (t != null) {
          t.angle = (c['ang'] as num).toDouble();
          t.turretAngle = (c['tAng'] as num).toDouble();
          t.moving = true;
        }
        break;
      case TankAction.stop:
        final t = tanks[message.id];
        if (t != null) t.moving = false;
        break;
      case TankAction.aim:
        final t = tanks[message.id];
        if (t != null) t.turretAngle = (c['ang'] as num).toDouble();
        break;
      case TankAction.aimStop:
        // 仅 owner 维护 aiming 状态；client 无需处理
        break;
      case TankAction.fire:
        final t = tanks[message.id];
        if (t != null) fire(t);
        break;
      case TankAction.aiTurn:
        final t = tanks[c['key'] as int];
        if (t != null) {
          final d = Direction.fromName(c['dir'] as String);
          t.angle = d.angle;
          t.turretAngle = d.angle;
        }
        break;
      case TankAction.aiFire:
        final t = tanks[c['key'] as int];
        if (t != null) fire(t);
        break;
      case TankAction.spawn:
        final key = c['key'] as int;
        final tank = Tank.fromJson(c['tank'] as Map<String, dynamic>);
        tanks[key] = tank;
        if (!tank.isPlayer) enemiesOnField++;
        break;
      case TankAction.hit:
        final key = c['key'] as int;
        final isBase = c['base'] as bool;
        if (isBase) {
          applyBaseHit();
        } else {
          applyHit(key);
        }
        break;
      case TankAction.restart:
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
  void updatePlayerMove(double angle) {
    final t = tanks[identity];
    if (t == null || !t.isAlive) return;
    t.angle = angle;
    if (!playerAiming) t.turretAngle = angle;
    t.moving = true;
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({
        'actionType': TankAction.move.name,
        'ang': angle,
        'tAng': t.turretAngle,
      }),
    );
  }

  @override
  void updatePlayerAim(double angle) {
    final t = tanks[identity];
    if (t == null || !t.isAlive) return;
    t.turretAngle = angle;
    playerAiming = true;
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': TankAction.aim.name, 'ang': angle}),
    );
  }

  @override
  void updatePlayerAimStop() {
    playerAiming = false;
  }

  @override
  void updatePlayerStop() {
    final t = tanks[identity];
    if (t != null) t.moving = false;
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': TankAction.stop.name}),
    );
  }

  @override
  void updatePlayerFire() {
    final t = tanks[identity];
    if (t == null) return;
    fire(t); // 拥有者权威：本地立即开火
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': TankAction.fire.name}),
    );
  }

  // ---- 广播钩子（host 发 action） ----

  @override
  void broadcastAiTurn(int tankKey, Direction dir) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({
        'actionType': TankAction.aiTurn.name,
        'key': tankKey,
        'dir': dir.name,
      }),
    );
  }

  @override
  void broadcastAiFire(int tankKey) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({'actionType': TankAction.aiFire.name, 'key': tankKey}),
    );
  }

  @override
  void broadcastSpawn(int tankKey, Tank tank) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({
        'actionType': TankAction.spawn.name,
        'key': tankKey,
        'tank': tank.toJson(),
      }),
    );
  }

  @override
  void broadcastHit(int tankKey, bool isBase) {
    engine.sendNetworkMessage(
      MessageType.action,
      json.encode({
        'actionType': TankAction.hit.name,
        'key': tankKey,
        'base': isBase,
      }),
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
        json.encode({'actionType': TankAction.restart.name}),
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
