import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/13.minecraft/base/block.dart';
import 'package:treasure/13.minecraft/base/vector.dart';
import 'package:treasure/13.minecraft/middle/chunk_manager.dart';
import 'package:treasure/13.minecraft/middle/raycast.dart';

void main() {
  group('Raycast', () {
    late ChunkManager chunkManager;

    setUp(() {
      chunkManager = ChunkManager();
      // 加载玩家附近的区块
      chunkManager.updateChunks(Vector3(24, 26, 24));
    });

    test('chunk loads and has blocks', () {
      // 检查地表方块是否存在
      final block = chunkManager.getBlock(Vector3Int(23, 17, 23));
      print('Block at (23, 17, 23): ${block?.type.name ?? "null"}');

      final block2 = chunkManager.getBlock(Vector3Int(25, 17, 25));
      print('Block at (25, 17, 25): ${block2?.type.name ?? "null"}');

      final block3 = chunkManager.getBlock(Vector3Int(23, 17, 25));
      print('Block at (23, 17, 25): ${block3?.type.name ?? "null"}');

      // 检查空气方块
      final air = chunkManager.getBlock(Vector3Int(23, 25, 23));
      print('Block at (23, 25, 23): ${air?.type.name ?? "null"}');

      // 打印一些方块来了解地面在哪
      for (int y = 30; y >= 10; y -= 2) {
        final b = chunkManager.getBlock(Vector3Int(23, y, 23));
        if (b != null) {
          print('  Block at y=$y: ${b.type.name}');
        }
      }
    });

    test('raycast downward hits ground', () {
      // 模拟玩家在 (24.5, 26.0, 24.8) 向下看
      final position = Vector3(24.5, 26.0, 24.8);
      final direction = Vector3(0, -0.45, 0.89).normalized;
      final maxDist = 20.0; // interactReach=10, blockSize=2

      print('Raycast from $position direction $direction maxDist=$maxDist');

      final hit = raycast(position, direction, chunkManager, maxDist);

      if (hit != null) {
        print('HIT: ${hit.block.type.name} at ${hit.block.position} '
            'face=(${hit.faceNormal.x}, ${hit.faceNormal.y}, ${hit.faceNormal.z})');
      } else {
        print('MISS: no block hit');

        // 逐个检查射线路径上的方块
        print('\nChecking blocks along ray path:');
        for (int y = 27; y >= 15; y -= 2) {
          for (int z = 23; z <= 45; z += 2) {
            final b = chunkManager.getBlock(Vector3Int(23, y, z));
            if (b != null && b.type != BlockType.air) {
              print('  FOUND: ${b.type.name} at (23, $y, $z)');
            }
          }
        }
      }

      expect(hit, isNotNull, reason: 'Raycast should hit a block');
    });

    test('raycast forward from ground level', () {
      // 模拟玩家在地面上向前看
      final position = Vector3(23, 19, 23);
      final direction = Vector3(0, 0, 1).normalized; // 向前看
      final maxDist = 20.0;

      print('Raycast forward from $position');

      final hit = raycast(position, direction, chunkManager, maxDist);

      if (hit != null) {
        print('HIT: ${hit.block.type.name} at ${hit.block.position}');
      } else {
        print('MISS');
      }
    });
  });
}
