import 'dart:collection';

import '../base/block.dart';
import '../base/constant.dart';
import '../base/vector.dart';
import 'chunk_manager.dart';

/// 红石信号管理器
///
/// 简化版红石系统：红石粉传导信号，红石火把/拉杆为电源，红石灯响应信号。
class RedstoneManager {
  static const int _maxPower = 15;
  static const int _bs = Constants.blockSize;

  /// 方块放置时触发红石更新
  void onBlockPlaced(ChunkManager chunks, Vector3Int pos, BlockType type) {
    if (type.isRedstone) {
      _propagateFrom(chunks, pos);
    } else {
      // 非红石方块放置可能阻断信号
      _propagateFrom(chunks, pos);
    }
  }

  /// 方块摧毁时触发红石更新
  void onBlockDestroyed(ChunkManager chunks, Vector3Int pos, BlockType type) {
    // 清除该位置的电源
    final block = chunks.getBlock(pos);
    block?.powerLevel = 0;

    // 重新计算周围信号
    _propagateFrom(chunks, pos);

    // 如果摧毁的是电源，需要更大范围重新计算
    if (type == BlockType.redstoneTorch || type == BlockType.lever) {
      for (final neighbor in _getNeighbors(pos)) {
        _propagateFrom(chunks, neighbor);
      }
    }
  }

  /// 切换拉杆状态（返回新状态：true=激活）
  bool toggleLever(ChunkManager chunks, Vector3Int pos) {
    final block = chunks.getBlock(pos);
    if (block == null || block.type != BlockType.lever) return false;

    // 拉杆通过 powerLevel 表示状态：0=关，15=开
    final isActive = block.powerLevel > 0;
    block.powerLevel = isActive ? 0 : _maxPower;

    // 重新传播信号
    _propagateFrom(chunks, pos);
    return !isActive;
  }

  /// 从指定位置开始传播红石信号
  void _propagateFrom(ChunkManager chunks, Vector3Int start) {
    // BFS 传播
    final Queue<(Vector3Int, int)> queue = Queue();
    final Set<Vector3Int> visited = {};
    final List<(Vector3Int, Block)> toUpdate = [];

    // 从起始位置的邻居开始
    for (final neighbor in _getNeighbors(start)) {
      final block = chunks.getBlock(neighbor);
      if (block == null) continue;
      if (_shouldPropagateTo(block.type)) {
        queue.add((neighbor, 0));
      }
    }

    // 也检查起始位置本身
    final startBlock = chunks.getBlock(start);
    if (startBlock != null && _isPowerSource(startBlock)) {
      queue.add((start, 0));
    }

    while (queue.isNotEmpty) {
      final (pos, dist) = queue.removeFirst();
      if (visited.contains(pos)) continue;
      if (dist > _maxPower) continue;
      visited.add(pos);

      final block = chunks.getBlock(pos);
      if (block == null) continue;

      int receivedPower = _calculateReceivedPower(chunks, pos, visited);
      int newPower = receivedPower;

      // 电源方块自身产生信号
      if (_isPowerSource(block)) {
        newPower = _maxPower;
      }

      // 红石火把：反转信号（被强信号熄灭）
      if (block.type == BlockType.redstoneTorch) {
        final belowPos = Vector3Int(pos.x, pos.y - _bs, pos.z);
        final belowBlock = chunks.getBlock(belowPos);
        if (belowBlock != null && belowBlock.powerLevel >= _maxPower) {
          newPower = 0; // 被强信号熄灭
        } else {
          newPower = _maxPower;
        }
      }

      // 红石粉：接收信号后衰减
      if (block.type == BlockType.redstoneDust) {
        if (receivedPower > 0) {
          newPower = (receivedPower - 1).toInt().clamp(0, _maxPower);
        } else {
          newPower = 0;
        }
      }

      // 红石灯：任何信号 ≥ 1 即点亮（通过 powerLevel 表示）
      if (block.type == BlockType.redstoneLamp) {
        newPower = receivedPower > 0 ? _maxPower : 0;
      }

      // 更新电源
      if (block.powerLevel != newPower) {
        block.powerLevel = newPower;
        toUpdate.add((pos, block));

        // 继续传播给邻居
        for (final neighbor in _getNeighbors(pos)) {
          if (!visited.contains(neighbor)) {
            final nBlock = chunks.getBlock(neighbor);
            if (nBlock != null && _shouldPropagateTo(nBlock.type)) {
              queue.add((neighbor, dist + 1));
            }
          }
        }
      }
    }
  }

  /// 计算某位置从邻居接收到的最强信号
  int _calculateReceivedPower(
    ChunkManager chunks,
    Vector3Int pos,
    Set<Vector3Int> visited,
  ) {
    int maxPower = 0;

    for (final neighbor in _getNeighbors(pos)) {
      final nBlock = chunks.getBlock(neighbor);
      if (nBlock == null) continue;
      if (nBlock.powerLevel <= 0) continue;

      // 红石火把输出的是全强度
      int signalStrength = nBlock.powerLevel;

      // 红石粉传导时衰减
      if (nBlock.type == BlockType.redstoneDust) {
        signalStrength = nBlock.powerLevel - 1;
      }

      if (signalStrength > maxPower) {
        maxPower = signalStrength;
      }
    }

    return maxPower.clamp(0, _maxPower);
  }

  /// 是否为电源方块
  bool _isPowerSource(Block block) {
    switch (block.type) {
      case BlockType.redstoneTorch:
        return true;
      case BlockType.lever:
        return block.powerLevel > 0;
      default:
        return false;
    }
  }

  /// 是否应该向该方块传播信号
  bool _shouldPropagateTo(BlockType type) {
    return type == BlockType.redstoneDust ||
        type == BlockType.redstoneLamp ||
        type == BlockType.redstoneTorch ||
        type == BlockType.lever;
  }

  /// 获取 6 个相邻位置（上、下、前、后、左、右）
  List<Vector3Int> _getNeighbors(Vector3Int pos) {
    return [
      Vector3Int(pos.x, pos.y + _bs, pos.z),
      Vector3Int(pos.x, pos.y - _bs, pos.z),
      Vector3Int(pos.x + _bs, pos.y, pos.z),
      Vector3Int(pos.x - _bs, pos.y, pos.z),
      Vector3Int(pos.x, pos.y, pos.z + _bs),
      Vector3Int(pos.x, pos.y, pos.z - _bs),
    ];
  }
}
