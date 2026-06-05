import 'package:treasure/13.minecraft/base/aabb.dart';

import 'block.dart';
import 'vector.dart';
import 'constant.dart';

/// 八叉树节点
class OctreeNode {
  final Vector3Int center;
  final int size;

  final AABBInt _aabb;
  final List<Block> _blocks = [];
  final List<OctreeNode> _children = [];

  OctreeNode({required this.center, required this.size})
    : _aabb = AABBInt.fromCenterAndHalfSize(center, Vector3Int.all(size));

  bool get _needSplit => _blocks.length > Constants.maxBlocksPerNode;

  bool get _canSplit => _children.isEmpty && size > Constants.blockSize;

  /// 插入方块
  bool insertBlock(Block block) {
    if (!_contains(block.position)) return false;

    // 如果该位置有block，先移除
    _blocks.removeWhere((b) => b.position == block.position);

    // 优先插入子节点
    for (final child in _children) {
      if (child.insertBlock(block)) {
        _tryMerge();
        return true;
      }
    }

    // 插入当前节点
    _blocks.add(block);

    // 检查是否需要分裂
    if (_needSplit && _canSplit) {
      _splitAndRedistribute();
    }

    return true;
  }

  bool _contains(Vector3Int position) {
    return _aabb.contains(position);
  }

  /// 分裂并重新分配方块
  void _splitAndRedistribute() {
    _split();

    for (final block in _blocks) {
      for (final child in _children) {
        if (child.insertBlock(block)) break;
      }
    }

    _blocks.clear();
  }

  /// 分裂节点
  void _split() {
    final int childHalfSize = size ~/ 2;

    // 生成8个子节点
    for (final dx in [-1, 1]) {
      for (final dy in [-1, 1]) {
        for (final dz in [-1, 1]) {
          final childCenter = Vector3Int(
            center.x + dx * childHalfSize,
            center.y + dy * childHalfSize,
            center.z + dz * childHalfSize,
          );
          _children.add(OctreeNode(center: childCenter, size: childHalfSize));
        }
      }
    }
  }

  /// 删除方块
  bool removeBlock(Block block) {
    if (!_contains(block.position)) return false;

    if (_blocks.remove(block)) return true;

    for (final child in _children) {
      if (child.removeBlock(block)) {
        _tryMerge();
        return true;
      }
    }

    return false;
  }

  /// 查询指定位置方块
  Block? getBlock(Vector3Int position) {
    if (!_contains(position)) return null;

    // 在当前节点查找
    for (final block in _blocks) {
      if (block.position == position) return block;
    }

    // 在子节点查找
    for (final child in _children) {
      final Block? found = child.getBlock(position);
      if (found != null) return found;
    }

    return null;
  }

  List<Block> getAllBlocks() {
    final result = <Block>[];

    // 添加当前节点中的方块
    result.addAll(_blocks);

    // 递归查询子节点
    for (final child in _children) {
      result.addAll(child.blocks);
    }

    return result;
  }

  /// 范围查询
  List<Block> queryRange(AABB queryAABB) {
    final result = <Block>[];

    // 检查节点与查询范围是否相交
    if (!queryAABB.intersects(_aabb.toAABB())) return result;

    // 添加当前节点中的方块
    for (final block in _blocks) {
      if (queryAABB.contains(block.position.toVector3())) {
        result.add(block);
      }
    }

    // 递归查询子节点
    for (final child in _children) {
      result.addAll(child.queryRange(queryAABB));
    }

    return result;
  }

  /// 尝试合并子节点
  void _tryMerge() {
    if (_children.isEmpty) return;

    // 检查所有子节点是否都是叶子节点且总方块数较少
    int totalBlocks = 0;
    for (final child in _children) {
      if (child._children.isNotEmpty) return; // 有非叶子节点，不合并
      totalBlocks += child.blocks.length;
    }

    if (totalBlocks <= Constants.mergeThreshold) {
      _merge();
    }
  }

  /// 合并子节点
  void _merge() {
    for (final child in _children) {
      _blocks.addAll(child.blocks);
      child.clear();
    }
    _children.clear();
  }

  void clear() {
    _children.clear();
    _blocks.clear();
  }

  void clearRecursive() {
    if (_children.isNotEmpty) {
      for (final child in _children) {
        child.clearRecursive();
      }
    }
    clear();
  }

  List<Block> get blocks => _blocks;
}

/// 八叉树管理器
class BlockOctree {
  final OctreeNode _root;

  BlockOctree({required Vector3Int center, required int size})
    : _root = OctreeNode(center: center, size: size);

  // 代理方法
  bool insertBlock(Block block) => _root.insertBlock(block);
  bool removeBlock(Block block) => _root.removeBlock(block);
  Block? getBlock(Vector3Int position) => _root.getBlock(position);
  List<Block> getAllBlocks() => _root.getAllBlocks();
  List<Block> queryRange(AABB queryAABB) => _root.queryRange(queryAABB);
}
