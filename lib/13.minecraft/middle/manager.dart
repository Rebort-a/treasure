import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../base/block.dart';
import '../base/aabb.dart';
import '../base/constant.dart';
import '../base/player.dart';
import '../base/vector.dart';
import 'chunk_manager.dart';
import 'common.dart';
import 'control_manager.dart';
import 'raycast.dart';
import 'redstone_manager.dart';

/// 游戏管理器
class Manager with ChangeNotifier implements TickerProvider {
  late final Ticker _ticker;
  late double _lastTime;
  late double _deltaTime;

  late final Player _player;
  late final ControlManager _controlManager;
  late final ChunkManager _chunkManager;
  late final RedstoneManager _redstoneManager;

  // 方块交互
  RaycastHit? targetedBlock;
  double destroyProgress = 0.0;
  bool _needsUpdate = false;
  int _sceneRevision = 0;

  // 背包系统（类型 → 数量，slotOrder 记录栏位顺序）
  final Map<BlockType, int> _inventoryCounts = {};
  final List<BlockType> _slotOrder = [];
  int selectedSlot = 0;

  SceneInfo _lastInfo = const SceneInfo(
    position: Vector3.zero,
    orientation: Vector3.zero,
    blocks: [],
  );

  Manager() {
    _initialize();
  }

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  /// 初始化游戏
  void _initialize() {
    // 每次进入页面使用随机种子，保证世界各不相同
    _chunkManager = ChunkManager(seed: math.Random().nextInt(1 << 31));
    _redstoneManager = RedstoneManager();

    // 在出生列地表上方出生：避免卡进地形，也不会从过高处坠落
    _player = Player(position: _spawnPosition())..rotateView(0, -0.5);
    _controlManager = ControlManager(_player, this);

    _chunkManager.updateChunks(_player.position);
    _addStarterInventory();
    _updateVisibleBlocks();
    _startGameLoop();
  }

  /// 计算出生坐标：先按噪声估算地表高度，加载出生列所在区块后，再取
  /// 该列最高实体方块（含树木、仙人掌），在其上方 42.25 处出生。
  /// X/Z 取奇数，使该列正好存在地形方块（地形按奇数坐标生成）。
  Vector3 _spawnPosition() {
    const spawnX = 23;
    const spawnZ = 23;
    final surfaceY = _chunkManager.surfaceHeightAt(spawnX, spawnZ);
    final probe = Vector3(
      spawnX.toDouble(),
      surfaceY.toDouble(),
      spawnZ.toDouble(),
    );
    // 先加载出生列区块，以便探测含树木在内的真实最高实体方块
    _chunkManager.updateChunks(probe);
    while (_chunkManager.hasPendingChunks) {
      _chunkManager.processLoadQueue();
    }
    final topY = _highestSolidAt(spawnX, surfaceY, spawnZ);
    return Vector3(spawnX.toDouble(), topY + 42.25, spawnZ.toDouble());
  }

  /// 扫描 (x, surfaceY, z) 列，返回最高非穿透方块的中心 y。
  /// 须在出生列区块已加载后调用，结果含树木、仙人掌等结构。
  int _highestSolidAt(int x, int surfaceY, int z) {
    for (var y = surfaceY + 12; y >= surfaceY - 4; y -= Constants.blockSize) {
      final block = _chunkManager.getBlock(Vector3Int(x, y, z));
      if (block != null && !block.type.isPenetrate) return y;
    }
    return surfaceY;
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

    // 射线检测 + 摧毁进度
    _performRaycast();
    _controlManager.updateDestroyProgress(deltaTime);

    // 分批处理加载队列
    if (_chunkManager.processLoadQueue()) {
      _sceneRevision++;
      _needsUpdate = true;
    }

    // 恢复旧版的更新阈值，减少无效渲染更新
    if (_shouldUpdate()) {
      // 更新区块加载状态
      _chunkManager.updateChunks(_player.position);

      _updateVisibleBlocks();

      notifyListeners();
    }
  }

  bool _shouldUpdate() {
    if (_needsUpdate) {
      _needsUpdate = false;
      return true;
    }
    return !(_lastInfo.position == _player.position) ||
        !(_lastInfo.orientation == _player.orientation) ||
        destroyProgress > 0;
  }

  /// 更新可见方块
  void _updateVisibleBlocks() {
    final blocks = _chunkManager.getRenderBlocks(_player);
    _lastInfo = SceneInfo(
      position: _player.position,
      orientation: _player.orientation,
      blocks: blocks,
      targetedBlock: targetedBlock?.block,
      targetedFaceNormal: targetedBlock?.faceNormal,
      revision: _sceneRevision,
    );
  }

  /// 射线检测（使用放置距离，摧毁距离在 ControlManager 中判断）
  void _performRaycast() {
    targetedBlock = raycast(
      _player.position,
      _player.orientation,
      _chunkManager,
      Constants.placeReach * Constants.blockSize,
    );
  }

  /// 目标方块是否在摧毁距离内
  bool get isTargetInDestroyRange {
    final target = targetedBlock;
    if (target == null) return false;
    final dist =
        (target.block.position.toVector3() - _player.position).magnitude;
    return dist <= Constants.destroyReach * Constants.blockSize;
  }

  /// 摧毁目标方块并拾取
  bool destroyTargetedBlock() {
    final target = targetedBlock;
    if (target == null) return false;
    final pos = target.block.position;
    final type = target.block.type;
    if (type == BlockType.bedrock) return false;
    if (!_canAddInventory(type)) return false;
    if (_chunkManager.destroyBlock(pos)) {
      addInventory(type);
      _redstoneManager.onBlockDestroyed(_chunkManager, pos, type);
      targetedBlock = null;
      _sceneRevision++;
      _needsUpdate = true;
      return true;
    }
    return false;
  }

  /// 在目标面放置方块（点击拉杆则切换状态）
  bool placeBlock() {
    final target = targetedBlock;
    if (target == null) return false;

    // 点击拉杆 → 切换开关
    if (target.block.type == BlockType.lever) {
      _redstoneManager.toggleLever(_chunkManager, target.block.position);
      _sceneRevision++;
      _needsUpdate = true;
      return true;
    }

    final selectedType = currentSelectedType;
    if (selectedType == null) return false;

    final n = target.faceNormal;
    final bs = Constants.blockSize;
    final placePos = Vector3Int(
      target.block.position.x + n.x * bs,
      target.block.position.y + n.y * bs,
      target.block.position.z + n.z * bs,
    );
    final half = Vector3.all(Constants.blockSizeHalf.toDouble());
    final placedBounds = AABB.fromCenterAndHalfSize(placePos.toVector3(), half);
    if (placedBounds.intersects(_player.collider.aabb)) return false;

    if (_chunkManager.placeBlock(placePos, selectedType)) {
      removeInventory(selectedType);
      _redstoneManager.onBlockPlaced(_chunkManager, placePos, selectedType);
      _sceneRevision++;
      _needsUpdate = true;
      return true;
    }
    return false;
  }

  /// 背包栏位类型列表（只读）
  List<BlockType> get slotTypes => List.unmodifiable(_slotOrder);

  /// 获取某类型的数量
  int getCount(BlockType type) => _inventoryCounts[type] ?? 0;

  /// 添加方块到背包
  void addInventory(BlockType type, [int amount = 1]) {
    if (amount <= 0) return;
    if (_inventoryCounts.containsKey(type)) {
      _inventoryCounts[type] = _inventoryCounts[type]! + amount;
    } else if (_slotOrder.length < Constants.hotbarSlotCount) {
      _inventoryCounts[type] = amount;
      _slotOrder.add(type);
    }
  }

  bool _canAddInventory(BlockType type) =>
      _inventoryCounts.containsKey(type) ||
      _slotOrder.length < Constants.hotbarSlotCount;

  void _addStarterInventory() {
    addInventory(BlockType.planks, 32);
    addInventory(BlockType.glass, 24);
    addInventory(BlockType.redstoneDust, 32);
    addInventory(BlockType.redstoneTorch, 8);
    addInventory(BlockType.lever, 8);
    addInventory(BlockType.redstoneLamp, 16);
  }

  /// 从背包移除一个方块
  bool removeInventory(BlockType type) {
    final count = _inventoryCounts[type];
    if (count == null || count <= 0) return false;

    if (count <= 1) {
      _inventoryCounts.remove(type);
      _slotOrder.remove(type);
      if (selectedSlot >= _slotOrder.length && selectedSlot > 0) {
        selectedSlot = _slotOrder.length - 1;
      }
    } else {
      _inventoryCounts[type] = count - 1;
    }
    return true;
  }

  /// 当前选中方块类型
  BlockType? get currentSelectedType =>
      selectedSlot < _slotOrder.length ? _slotOrder[selectedSlot] : null;

  @override
  void dispose() {
    _ticker.dispose();
    _controlManager.dispose();
    super.dispose();
  }

  // 公开属性
  final debugConfig = RenderDebugConfig();
  FocusNode get focusNode => _controlManager.focusNode;
  SceneInfo get sceneInfo => _lastInfo;
  ControlManager get controlManager => _controlManager;
  String get debugInfo =>
      'FPS: ${(1 / _deltaTime.clamp(0.001, 1000)).toStringAsFixed(0)}';
}
