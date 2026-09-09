// 验证：每次随机种子生成不同世界，且自适应出生点在多种子下都能落地。
// flutter test test/minecraft/spawn_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/13.minecraft/base/block.dart';
import 'package:treasure/13.minecraft/base/player.dart';
import 'package:treasure/13.minecraft/base/vector.dart';
import 'package:treasure/13.minecraft/middle/chunk_manager.dart';

/// 复刻 Manager._initialize 的出生逻辑（不依赖 Flutter Ticker）。
(int topY, Player) spawnAndDrop(ChunkManager cm, int x, int z) {
  final surfaceY = cm.surfaceHeightAt(x, z);
  cm.updateChunks(Vector3(x.toDouble(), surfaceY.toDouble(), z.toDouble()));
  while (cm.hasPendingChunks) {
    cm.processLoadQueue();
  }
  // 扫描真实最高非穿透方块
  var topY = surfaceY;
  for (var y = surfaceY + 12; y >= surfaceY - 4; y -= 2) {
    final b = cm.getBlock(Vector3Int(x, y, z));
    if (b != null && !b.type.isPenetrate) {
      topY = y;
      break;
    }
  }
  final player = Player(
        position: Vector3(x.toDouble(), topY + 5.25, z.toDouble()),
      )..isGrounded = false;
  // 自由下落 + 落地
  for (var i = 0; i < 80; i++) {
    player.update(0.016, cm.getCollisionBlocks(player));
  }
  return (topY, player);
}

void main() {
  test('不同种子生成不同世界', () {
    final a = ChunkManager(seed: 1);
    final b = ChunkManager(seed: 2);
    // 在一片区域里，两个世界的地表高度不会处处相同
    var anyDiff = false;
    for (var x = 1; x <= 31 && !anyDiff; x += 2) {
      for (var z = 1; z <= 31 && !anyDiff; z += 2) {
        if (a.surfaceHeightAt(x, z) != b.surfaceHeightAt(x, z)) {
          anyDiff = true;
        }
      }
    }
    expect(anyDiff, isTrue, reason: '不同种子应生成不同世界');
  });

  test('多种子下自适应出生均能落地且不卡地形', () {
    for (final seed in [1, 2, 3, 7, 42, 100, 999, 20260908, 1 << 30, 12345]) {
      final cm = ChunkManager(seed: seed);
      final (topY, player) = spawnAndDrop(cm, 23, 23);

      expect(
        player.isGrounded,
        isTrue,
        reason: 'seed=$seed 未落地',
      );
      // 落地后眼高应稳定在 topY+3.25（脚踩在 topY+1 顶面）
      expect(
        (player.position.y - (topY + 3.25)).abs(),
        lessThan(0.01),
        reason: 'seed=$seed 落地高度异常 y=${player.position.y} topY=$topY',
      );
    }
  });
}
