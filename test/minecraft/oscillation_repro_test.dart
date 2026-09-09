// 回归测试：octree 范围查询不得遗漏中心落在节点边界上的方块。
//
// 历史缺陷：玩家静止站在地表方块上时，若该方块中心 y 恰好落在 octree
// 孙节点内部边界（surfaceY ≡ 0 mod 4 且非 16 的倍数，如 4/8/12/20/24/28），
// 节点级粗筛用严格 epsilon 相交会把方块所在子节点整体误剔除 → 地面支撑
// 查不到脚下方块 → isGrounded 翻转 → 重力与碰撞每帧来回拉扯，玩家 y 在
// surfaceY+3.25（toStringAsFixed(1) 的舍入中点）附近高频振荡，右上角
// 高度在 X.2/X.3 之间反复跳动，屏幕方块也随相机上下抖动。
// surfaceY ≡ 2 mod 4 时方块在节点中部，始终能查到，故稳定。
//
// flutter test test/minecraft/oscillation_repro_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/13.minecraft/base/block.dart';
import 'package:treasure/13.minecraft/base/player.dart';
import 'package:treasure/13.minecraft/base/vector.dart';
import 'package:treasure/13.minecraft/middle/chunk_manager.dart';

void main() {
  ChunkManager _loadWorld() {
    final cm = ChunkManager(seed: 20260908);
    cm.updateChunks(Vector3(24, 30, 24));
    for (var i = 0; i < 200 && cm.hasPendingChunks; i++) {
      cm.processLoadQueue();
    }
    return cm;
  }

  int? _surfaceY(ChunkManager cm, int x, int z) {
    for (var y = 60; y >= -60; y -= 2) {
      final b = cm.getBlock(Vector3Int(x, y, z));
      if (b != null && !b.type.isPenetrate) return y;
    }
    return null;
  }

  (int, int, int)? _findSurface(ChunkManager cm, bool Function(int) pred) {
    for (var x = 1; x <= 99; x += 2) {
      for (var z = 1; z <= 99; z += 2) {
        final sy = _surfaceY(cm, x, z);
        if (sy != null && pred(sy)) return (sy, x, z);
      }
    }
    return null;
  }

  test('内部孙节点边界上的脚下方块在静止查询中必须命中且不抖动', () {
    final cm = _loadWorld();
    // 内部边界：4 的倍数但非 16 的倍数（16k+4/8/12），历史上会抖动
    final boundary = _findSurface(cm, (sy) => sy % 4 == 0 && sy % 16 != 0);
    // 中部：≡ 2 mod 4，历史上稳定
    final mid = _findSurface(cm, (sy) => sy % 4 == 2);

    expect(boundary, isNotNull, reason: '世界应存在内部边界高度的地表');
    expect(mid, isNotNull, reason: '世界应存在中部高度的地表');

    bool simulate(int sy, int x, int z) {
      final eyeY = (sy + 3.25).toDouble();
      final player = Player(position: Vector3(x.toDouble(), eyeY, z.toDouble()))
        ..velocity = Vector3.zero
        ..isGrounded = true;

      final disps = <String>{};
      for (var i = 0; i < 40; i++) {
        player.update(0.016, cm.getCollisionBlocks(player));
        if (i >= 20) disps.add(player.position.y.toStringAsFixed(1));
      }
      return disps.length == 1; // 稳定 → 只有一个显示值
    }

    void expectFootBlockFound(int sy, int x, int z) {
      final eyeY = (sy + 3.25).toDouble();
      final player = Player(position: Vector3(x.toDouble(), eyeY, z.toDouble()))
        ..isGrounded = true;
      final rest = cm.getCollisionBlocks(player);
      final foot = cm.getBlock(Vector3Int(x, sy, z));
      expect(foot, isNotNull);
      expect(
        rest.any((b) => b.position == foot!.position),
        isTrue,
        reason: '静止时脚下方块必须出现在碰撞查询结果中',
      );
    }

    final (bsy, bx, bz) = boundary!;
    final (msy, mx, mz) = mid!;

    // 关键回归断言：修复前这里为 false（方块丢失 + 振荡）
    expectFootBlockFound(bsy, bx, bz);
    expect(simulate(bsy, bx, bz), isTrue, reason: '内部边界高度不应再振荡');

    expectFootBlockFound(msy, mx, mz);
    expect(simulate(msy, mx, mz), isTrue, reason: '中部高度保持稳定');
  });
}
