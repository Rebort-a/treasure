import 'dart:convert';

import 'package:flutter/material.dart';

import '../00.common/model/app_item_type.dart';
import '../00.common/network/client/net_real_engine.dart';
import '../00.common/game/map.dart';
import '../00.common/network/protocol/network_message.dart';
import '../00.common/network/client/socket_client.dart';
import '../00.common/tool/convert_utils.dart';
import 'base.dart';
import 'foundation_manager.dart';

enum TankAction {
  move,
  stop,
  aim,
  aimStop,
  fire,
  aiPlan,
  aiFire,
  spawn,
  spawnItem,
  pickup,
  hit,
}

/// 联机玩家输入只发送 action，等待服务器回传后再应用。
///
/// 新玩家加入时，所有端重新加载同一份 resource 并完成同步屏障。
/// AI、生成、道具和命中由权威方产生，但包括权威方自己在内，所有端都要
/// 等服务器回环后才应用事件。
class NetTankManager extends TankGameManager {
  late final NetRealEngine realEngine;

  final Set<int> _pendingSyncIds = {};
  final Set<int> _pendingEnemySpawns = {};
  final Set<int> _pendingAiPlans = {};
  final Set<int> _pendingAiFires = {};
  final Set<Offset> _pendingPowerUpSpawns = {};
  final Set<Offset> _pendingPowerUpPickups = {};
  int _matchId = 0;
  int _syncId = 0;
  bool _fireRequestPending = false;

  NetTankManager({required SocketClient room}) {
    realEngine = NetRealEngine.forClient(room)
      ..configureGame(
        maxPlayers: OnlineItemType.tryFromRoomType(room.roomType)
            ?.maxGamePlayers,
        searchHandler: _handleSearch,
        resourceHandler: _handleResource,
        syncHandler: _handleSync,
        actionHandler: _handleAction,
        exitHandler: _handleEnd,
      );
    initTicker();
    realEngine.ended.addListener(suspendGame);
  }

  @override
  int get identity => realEngine.identity;

  int? get authorityId => realEngine.publisherId;

  @override
  bool get isAuthority => identity == authorityId;

  @override
  bool get deferAuthorityActions => true;

  @override
  int get pendingEnemySpawnCount => _pendingEnemySpawns.length;

  @override
  int get pendingPowerUpSpawnCount => _pendingPowerUpSpawns.length;

  @override
  bool isAiPlanPending(int tankKey) => _pendingAiPlans.contains(tankKey);

  @override
  bool isAiFirePending(int tankKey) => _pendingAiFires.contains(tankKey);

  @override
  bool isPowerUpSpawnPending(Offset position) =>
      _pendingPowerUpSpawns.contains(position);

  @override
  bool isPowerUpPickupPending(Offset position) =>
      _pendingPowerUpPickups.contains(position);

  // ---- 全员资源同步 ----

  void _handleSearch(int id) {
    suspendGame();
    // 生成资源时不提前改变本地对局；由资源回环统一加载新名单。
    final previousTanks = Map<int, Tank>.of(tanks);
    final previousLives = Map<int, int>.of(livesByPlayer);
    final previousSpawns = Map<int, int>.of(playerSpawnUsed);
    late final Map<String, dynamic> proposed;
    try {
      if (!tanks.containsKey(identity)) addPlayerTank(identity);
      if (!tanks.containsKey(id)) addPlayerTank(id);
      proposed = toJson();
    } finally {
      tanks
        ..clear()
        ..addAll(previousTanks);
      livesByPlayer
        ..clear()
        ..addAll(previousLives);
      playerSpawnUsed
        ..clear()
        ..addAll(previousSpawns);
    }
    _syncId++;
    _sendSnapshot(proposed);
  }

  void _handleResource(NetworkMessage message) {
    try {
      final knownHostId = authorityId;
      if (knownHostId != null && message.id != knownHostId) return;

      final envelope = json.decode(message.content) as Map<String, dynamic>;
      final incomingMatch = (envelope['match'] as num?)?.toInt() ?? 0;
      if (incomingMatch < _matchId) return;
      final incomingSync = (envelope['sync'] as num?)?.toInt() ?? 0;
      if (incomingMatch == _matchId && incomingSync < _syncId) return;
      final state = envelope['state'];
      if (state is! Map<String, dynamic>) return;

      suspendGame();
      _matchId = incomingMatch;
      _syncId = incomingSync;
      _fireRequestPending = false;
      _clearPendingWorldEvents();
      fromJson(state);
      _pendingSyncIds
        ..clear()
        ..addAll(
          tanks.entries
              .where((entry) => entry.value.isPlayer)
              .map((entry) => entry.key),
        );
      realEngine.sendGameMessage(
        MessageType.sync,
        json.encode({'match': _matchId, 'sync': _syncId}),
      );
    } on Object catch (error) {
      debugPrint('[Tank] ignored invalid resource: $error');
    }
  }

  void _handleSync(NetworkMessage message) {
    try {
      final content = json.decode(message.content) as Map<String, dynamic>;
      final matchId = (content['match'] as num?)?.toInt() ?? -1;
      final syncId = (content['sync'] as num?)?.toInt() ?? -1;
      if (matchId != _matchId || syncId != _syncId) return;
      if (!_pendingSyncIds.remove(message.id)) return;
      _resumeWhenSynchronized();
    } on Object catch (error) {
      debugPrint('[Tank] ignored invalid sync: $error');
    }
  }

  void _resumeWhenSynchronized() {
    if (_pendingSyncIds.isNotEmpty) return;
    if (!realEngine.completeSynchronization()) return;
    resumeGame();
  }

  // ---- 服务器回环 action 分发 ----

  void _handleAction(NetworkMessage message) {
    try {
      final content = json.decode(message.content) as Map<String, dynamic>;
      final incomingMatch = (content['match'] as num?)?.toInt() ?? 0;
      final incomingSync = (content['sync'] as num?)?.toInt() ?? 0;
      if (incomingMatch != _matchId || incomingSync != _syncId) return;

      final rawAction = content['actionType'];
      if (rawAction is! String) return;
      final action = TankAction.values.asNameMap()[rawAction];
      if (action == null) return;

      final hostId = authorityId;
      switch (action) {
        case TankAction.move:
          final tank = tanks[message.id];
          if (tank == null || !tank.isPlayer || !tank.isAlive) return;
          tank
            ..angle = (content['ang'] as num).toDouble()
            ..turretAngle = (content['tAng'] as num).toDouble()
            ..moving = true;
          break;
        case TankAction.stop:
          final tank = tanks[message.id];
          if (tank == null || !tank.isPlayer) return;
          tank.moving = false;
          break;
        case TankAction.aim:
          final tank = tanks[message.id];
          if (tank == null || !tank.isPlayer || !tank.isAlive) return;
          tank.turretAngle = (content['ang'] as num).toDouble();
          if (message.id == identity) playerAiming = true;
          break;
        case TankAction.aimStop:
          if (message.id == identity) playerAiming = false;
          break;
        case TankAction.fire:
          final tank = tanks[message.id];
          final rawBullet = content['bullet'];
          if (tank == null ||
              !tank.isPlayer ||
              !tank.isAlive ||
              rawBullet is! Map<String, dynamic>) {
            return;
          }
          final bullet = Bullet.fromJson(rawBullet);
          if (bullet.ownerId != message.id) return;
          applyFire(message.id, bullet);
          if (message.id == identity) _fireRequestPending = false;
          break;
        case TankAction.aiPlan:
          if (message.id != hostId) return;
          final key = (content['key'] as num).toInt();
          final destination = ConvertUtils.offsetFromJson(
            content['dest'] as Map<String, dynamic>,
          );
          final direction = Direction.fromName(content['dir'] as String);
          final firing = content['firing'] as bool;
          final duration = (content['duration'] as num).toDouble();
          _pendingAiPlans.remove(key);
          applyAiPlan(key, destination, direction, firing, duration);
          break;
        case TankAction.aiFire:
          if (message.id != hostId) return;
          final key = (content['key'] as num).toInt();
          final tank = tanks[key];
          final rawBullet = content['bullet'];
          if (tank == null ||
              tank.isPlayer ||
              rawBullet is! Map<String, dynamic>) {
            return;
          }
          final bullet = Bullet.fromJson(rawBullet);
          if (bullet.ownerId != key) return;
          _pendingAiFires.remove(key);
          applyFire(key, bullet);
          break;
        case TankAction.spawn:
          if (message.id != hostId) return;
          final key = (content['key'] as num).toInt();
          final tank = Tank.fromJson(content['tank'] as Map<String, dynamic>);
          _pendingEnemySpawns.remove(key);
          applyEnemySpawn(key, tank);
          break;
        case TankAction.spawnItem:
          if (message.id != hostId) return;
          final item = PowerUp.fromJson(
            content['item'] as Map<String, dynamic>,
          );
          _pendingPowerUpSpawns.remove(item.position);
          applySpawnItem(item);
          break;
        case TankAction.pickup:
          if (message.id != hostId) return;
          final playerKey = (content['key'] as num).toInt();
          final type = PowerUpType.fromName(content['type'] as String);
          final position = ConvertUtils.offsetFromJson(
            content['px'] as Map<String, dynamic>,
          );
          _pendingPowerUpPickups.remove(position);
          applyConfirmedPickup(playerKey, type, position);
          break;
        case TankAction.hit:
          final ownerId = (content['owner'] as num).toInt();
          final expectedSender = ownerId >= 0 ? ownerId : hostId;
          if (message.id != expectedSender) return;
          final key = (content['key'] as num).toInt();
          if (content['base'] as bool) {
            applyBaseHit();
          } else {
            applyConfirmedHit(
              key,
              (content['dmg'] as num?)?.toInt() ?? Bullet.baseDamage,
            );
          }
          break;
      }
    } on Object catch (error) {
      debugPrint('[Tank] ignored invalid action: $error');
    }
  }

  void _handleEnd(int id) {
    tanks.remove(id);
    livesByPlayer.remove(id);
    playerSpawnUsed.remove(id);
    if (_pendingSyncIds.remove(id)) _resumeWhenSynchronized();
  }

  // ---- 玩家输入：只发送，等待服务器回环后应用 ----

  @override
  void updatePlayerMove(double angle) {
    final tank = tanks[identity];
    if (tank == null || !tank.isAlive) return;
    _sendAction(TankAction.move, {
      'ang': angle,
      'tAng': playerAiming ? tank.turretAngle : angle,
    });
  }

  @override
  void updatePlayerAim(double angle) {
    final tank = tanks[identity];
    if (tank == null || !tank.isAlive) return;
    _sendAction(TankAction.aim, {'ang': angle});
  }

  @override
  void updatePlayerAimStop() {
    _sendAction(TankAction.aimStop);
  }

  @override
  void updatePlayerStop() {
    if (!tanks.containsKey(identity)) return;
    _sendAction(TankAction.stop);
  }

  @override
  void updatePlayerFire() {
    final tank = tanks[identity];
    if (tank == null || !tank.canFire || _fireRequestPending || !tank.isAlive) {
      return;
    }
    final bullet = buildBullet(identity, tank);
    if (bullet == null) return;
    _fireRequestPending = true;
    _sendAction(TankAction.fire, {'bullet': bullet.toJson()});
  }

  // ---- 权威方只生成并广播，等待服务器回环后统一应用 ----

  @override
  void broadcastAiPlan(
    int tankKey,
    Offset destination,
    Direction direction,
    bool firing,
    double duration,
  ) {
    _pendingAiPlans.add(tankKey);
    _sendAction(TankAction.aiPlan, {
      'key': tankKey,
      'dest': ConvertUtils.offsetToJson(destination),
      'dir': direction.name,
      'firing': firing,
      'duration': duration,
    });
  }

  @override
  void broadcastAiFire(int tankKey, Bullet bullet) {
    _pendingAiFires.add(tankKey);
    _sendAction(TankAction.aiFire, {'key': tankKey, 'bullet': bullet.toJson()});
  }

  @override
  void broadcastSpawn(int tankKey, Tank tank) {
    _pendingEnemySpawns.add(tankKey);
    _sendAction(TankAction.spawn, {'key': tankKey, 'tank': tank.toJson()});
  }

  @override
  void broadcastHit(int tankKey, bool isBase, int damage, int ownerId) {
    _sendAction(TankAction.hit, {
      'key': tankKey,
      'base': isBase,
      'dmg': damage,
      'owner': ownerId,
    });
  }

  @override
  void broadcastSpawnItem(PowerUp p) {
    _pendingPowerUpSpawns.add(p.position);
    _sendAction(TankAction.spawnItem, {'item': p.toJson()});
  }

  @override
  void broadcastPickup(int playerKey, PowerUpType type, Offset position) {
    _pendingPowerUpPickups.add(position);
    _sendAction(TankAction.pickup, {
      'key': playerKey,
      'type': type.name,
      'px': ConvertUtils.offsetToJson(position),
    });
  }

  void _clearPendingWorldEvents() {
    _pendingEnemySpawns.clear();
    _pendingAiPlans.clear();
    _pendingAiFires.clear();
    _pendingPowerUpSpawns.clear();
    _pendingPowerUpPickups.clear();
  }

  void _sendAction(
    TankAction action, [
    Map<String, dynamic> payload = const {},
  ]) {
    realEngine.sendGameMessage(
      MessageType.action,
      json.encode({
        'actionType': action.name,
        'match': _matchId,
        'sync': _syncId,
        ...payload,
      }),
    );
  }

  void _sendSnapshot([Map<String, dynamic>? proposed]) {
    realEngine.sendGameMessage(
      MessageType.resource,
      json.encode({
        'match': _matchId,
        'sync': _syncId,
        'state': proposed ?? toJson(),
      }),
    );
  }

  @override
  void leavePage() {
    realEngine.leavePage();
  }

  @override
  void dispose() {
    realEngine.ended.removeListener(suspendGame);
    realEngine.releaseGame();
    super.dispose();
  }
}
