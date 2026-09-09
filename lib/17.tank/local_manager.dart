import 'package:flutter/material.dart';

import 'base.dart';
import 'foundation_manager.dart';

/// 单机模式：权威方，玩家与 AI 均由基类共享逻辑驱动。
class LocalTankManager extends FoundationalTankManager {
  @override
  int get identity => 0;

  @override
  bool get isAuthority => true;

  LocalTankManager() {
    initTicker();
    addPlayerTank(identity);
    resumeGame();
  }

  @override
  void handleRemoveTankCallback(int tankKey) {
    // AI 销毁后由 _updateSpawning 继续补充（remainingEnemies > 0 时自动）
  }

  @override
  void handleGameOverCallback() {}

  @override
  void updatePlayerDirection(Direction dir) {
    final tank = tanks[identity];
    if (tank == null || !tank.isAlive) return;
    tank.direction = dir;
    tank.turretDirection = dir;
    tank.moving = true;
  }

  @override
  void updatePlayerStop() {
    final tank = tanks[identity];
    if (tank != null) tank.moving = false;
  }

  @override
  void updatePlayerFire() {
    final tank = tanks[identity];
    if (tank != null) fire(tank);
  }

  @override
  void requestRestart() => resetGame();

  @override
  void leavePage() {
    pageNavigator.value = (context) => Navigator.pop(context);
  }
}
