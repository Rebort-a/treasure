import 'dart:collection';

import '../base/block.dart';
import '../base/constant.dart';
import '../base/vector.dart';
import 'chunk_manager.dart';

/// 简洁且确定性的红石网络。
///
/// - 拉杆和红石火把输出 15 级信号；
/// - 红石粉每经过一格衰减 1；
/// - 红石灯收到任意信号即点亮，但不继续传导；
/// - 网络变化时先清空动态状态，再从所有电源重新传播，避免幽灵信号。
class RedstoneManager {
  static const int _maxPower = 15;
  static const int _step = Constants.blockSize;

  void onBlockPlaced(ChunkManager chunks, Vector3Int pos, BlockType type) {
    _rebuildAround(chunks, pos);
  }

  void onBlockDestroyed(ChunkManager chunks, Vector3Int pos, BlockType type) {
    _rebuildAround(chunks, pos);
  }

  bool toggleLever(ChunkManager chunks, Vector3Int pos) {
    final block = chunks.getBlock(pos);
    if (block == null || block.type != BlockType.lever) return false;

    block.powerLevel = block.powerLevel > 0 ? 0 : _maxPower;
    _rebuildAround(chunks, pos);
    return block.powerLevel > 0;
  }

  void _rebuildAround(ChunkManager chunks, Vector3Int changedPosition) {
    final processed = <Vector3Int>{};
    final seeds = <Vector3Int>[changedPosition, ..._neighbors(changedPosition)];

    for (final seed in seeds) {
      final block = chunks.getBlock(seed);
      if (block == null || !block.type.isRedstone) continue;
      if (processed.contains(seed)) continue;

      final component = _collectComponent(chunks, seed);
      processed.addAll(component.keys);
      _recalculateComponent(chunks, component);
    }
  }

  Map<Vector3Int, Block> _collectComponent(
    ChunkManager chunks,
    Vector3Int start,
  ) {
    final component = <Vector3Int, Block>{};
    final queue = Queue<Vector3Int>()..add(start);

    while (queue.isNotEmpty) {
      final position = queue.removeFirst();
      if (component.containsKey(position)) continue;

      final block = chunks.getBlock(position);
      if (block == null || !block.type.isRedstone) continue;
      component[position] = block;

      for (final neighbor in _neighbors(position)) {
        if (!component.containsKey(neighbor)) queue.add(neighbor);
      }
    }
    return component;
  }

  void _recalculateComponent(
    ChunkManager chunks,
    Map<Vector3Int, Block> component,
  ) {
    final queue = Queue<Vector3Int>();

    for (final entry in component.entries) {
      final block = entry.value;
      switch (block.type) {
        case BlockType.redstoneTorch:
          block.powerLevel = _maxPower;
          queue.add(entry.key);
        case BlockType.lever:
          if (block.powerLevel > 0) {
            block.powerLevel = _maxPower;
            queue.add(entry.key);
          } else {
            block.powerLevel = 0;
          }
        case BlockType.redstoneDust:
        case BlockType.redstoneLamp:
          block.powerLevel = 0;
        default:
          break;
      }
    }

    while (queue.isNotEmpty) {
      final position = queue.removeFirst();
      final source = chunks.getBlock(position);
      if (source == null || source.powerLevel <= 0) continue;

      for (final neighborPosition in _neighbors(position)) {
        final neighbor = component[neighborPosition];
        if (neighbor == null) continue;

        switch (neighbor.type) {
          case BlockType.redstoneDust:
            final nextPower = (source.powerLevel - 1).clamp(0, _maxPower);
            if (nextPower > neighbor.powerLevel) {
              neighbor.powerLevel = nextPower;
              queue.add(neighborPosition);
            }
          case BlockType.redstoneLamp:
            if (neighbor.powerLevel == 0 && source.powerLevel > 0) {
              neighbor.powerLevel = _maxPower;
            }
          case BlockType.redstoneTorch:
          case BlockType.lever:
            // 固定电源不被邻居覆盖。
            break;
          default:
            break;
        }
      }
    }
  }

  List<Vector3Int> _neighbors(Vector3Int pos) => [
    Vector3Int(pos.x + _step, pos.y, pos.z),
    Vector3Int(pos.x - _step, pos.y, pos.z),
    Vector3Int(pos.x, pos.y + _step, pos.z),
    Vector3Int(pos.x, pos.y - _step, pos.z),
    Vector3Int(pos.x, pos.y, pos.z + _step),
    Vector3Int(pos.x, pos.y, pos.z - _step),
  ];
}
