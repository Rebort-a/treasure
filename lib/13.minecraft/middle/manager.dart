import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../base/constant.dart';
import '../base/player.dart';
import '../base/vector.dart';
import 'chunk_manager.dart';
import 'common.dart';
import 'control_manager.dart';

/// 游戏管理器
class Manager with ChangeNotifier implements TickerProvider {
  late final Ticker _ticker;
  late double _lastTime;
  late double _deltaTime;

  late final Player _player;
  late final ControlManager _controlManager;
  late final ChunkManager _chunkManager;

  SceneInfo _lastInfo = const SceneInfo(
    position: Vector3.zero,
    orientation: Vector3.zero,
    blocks: [],
  );

  Manager() {
    _initialize();
  }

  /// 初始化游戏
  void _initialize() {
    _player = Player(position: Vector3(24, 64, 24));
    _controlManager = ControlManager(_player);
    _chunkManager = ChunkManager();
    _chunkManager.updateChunks(_player.position);
    _updateVisibleBlocks();
    _startGameLoop();
  }

  /// 开始游戏循环
  void _startGameLoop() {
    _lastTime = 0;
    _deltaTime = 0;
    _ticker = createTicker(_update);
    _ticker.start();
  }

  /// 游戏更新
  void _update(Duration elapsed) {
    final currentTime = elapsed.inMilliseconds / 1000.0;
    _deltaTime = currentTime - _lastTime;
    _lastTime = currentTime;

    final double deltaTime = _deltaTime.clamp(
      Constants.minDeltaTime,
      Constants.maxDeltaTime,
    );

    // 更新玩家输入
    _controlManager.updatePlayerMovement(deltaTime);

    // 获取碰撞检测所需方块
    final nearbyBlocks = _chunkManager.getCollisionBlocks(_player);
    _player.update(deltaTime, nearbyBlocks);

    // 分批处理加载队列
    _chunkManager.processLoadQueue();

    // 恢复旧版的更新阈值，减少无效渲染更新
    if (_shouldUpdate()) {
      // 更新区块加载状态
      _chunkManager.updateChunks(_player.position);

      _updateVisibleBlocks();

      notifyListeners();
    }
  }

  bool _shouldUpdate() {
    return !(_lastInfo.position == _player.position) ||
        !(_lastInfo.orientation == _player.orientation);
  }

  /// 更新可见方块
  void _updateVisibleBlocks() {
    final blocks = _chunkManager.getRenderBlocks(_player);
    _lastInfo = SceneInfo(
      position: _player.position,
      orientation: _player.orientation,
      blocks: blocks,
    );
  }

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  @override
  void dispose() {
    _ticker.stop();
    _controlManager.dispose();
    super.dispose();
  }

  // 公开属性
  FocusNode get focusNode => _controlManager.focusNode;
  SceneInfo get sceneInfo => _lastInfo;
  ControlManager get controlManager => _controlManager;
  String get debugInfo =>
      'FPS: ${(1 / _deltaTime.clamp(0.001, 1000)).toStringAsFixed(0)}';
}
