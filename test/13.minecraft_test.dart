import 'package:flutter_test/flutter_test.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:treasure/13.minecraft/base/block.dart';
import 'package:treasure/13.minecraft/base/constant.dart';
import 'package:treasure/13.minecraft/base/player.dart';
import 'package:treasure/13.minecraft/base/vector.dart';
import 'package:treasure/13.minecraft/base/voxel_coordinates.dart';
import 'package:treasure/13.minecraft/middle/chunk_manager.dart';
import 'package:treasure/13.minecraft/middle/common.dart';
import 'package:treasure/13.minecraft/middle/raycast.dart';
import 'package:treasure/13.minecraft/middle/redstone_manager.dart';
import 'package:treasure/13.minecraft/upper/face_merger.dart';
import 'package:treasure/13.minecraft/upper/scene_render.dart';

void main() {
  group('Voxel coordinates', () {
    test('negative chunk groups use floor division and positive offsets', () {
      expect(
        VoxelCoordinates.chunkToGroup(const Vector3Int(-1, -4, -7), 3),
        const Vector3Int(-1, -2, -3),
      );
      expect(
        VoxelCoordinates.chunkOffsetInGroup(const Vector3Int(-1, -4, -7), 3),
        const Vector3Int(2, 2, 2),
      );
    });

    test('block centers follow horizontal odd and vertical even grid', () {
      expect(
        VoxelCoordinates.snapBlockCenter(const Vector3(-0.1, -0.1, 2.9)),
        const Vector3Int(-1, -2, 3),
      );
    });
  });

  group('World and raycast', () {
    late ChunkManager chunks;

    setUp(() {
      chunks = ChunkManager(seed: 42);
      chunks.updateChunks(const Vector3(24, 26, 24));
    });

    test('deterministic terrain contains a solid surface', () {
      final column = <Block>[];
      for (var y = 40; y >= -20; y -= Constants.blockSize) {
        final block = chunks.getBlock(Vector3Int(23, y, 23));
        if (block != null) column.add(block);
      }

      expect(column, isNotEmpty);
      expect(column.any((block) => block.type == BlockType.stone), isTrue);
    });

    test('negative world coordinates load without range errors', () {
      final negativeChunks = ChunkManager(seed: 42);
      expect(
        () => negativeChunks.updateChunks(const Vector3(-24, 24, -24)),
        returnsNormally,
      );
      expect(
        negativeChunks.getBlock(const Vector3Int(-25, 20, -25)),
        isNotNull,
      );
    });

    test('raycast downward returns a hit and a valid face normal', () {
      final hit = raycast(
        const Vector3(23, 50, 23),
        const Vector3(0, -1, 0),
        chunks,
        60,
      );

      expect(hit, isNotNull);
      expect(hit!.faceNormal, const Vector3Int(0, 1, 0));
    });
  });

  group('Player physics', () {
    test('ground support is stable and disappears with the block', () {
      final ground = Block(
        position: const Vector3Int(1, 0, 1),
        type: BlockType.grass,
      );
      final player = Player(position: const Vector3(1, 3.25, 1));

      player.update(0.016, [ground]);
      expect(player.isGrounded, isTrue);

      player.update(0.016, const []);
      expect(player.isGrounded, isFalse);
    });

    test('diagonal and pitched movement keep the configured speed', () {
      final player = Player(position: const Vector3(1, 10, 1))
        ..rotateView(0, 0.7)
        ..move(const Vector2(1, 1), Constants.moveSpeed);

      final horizontalSpeed = Vector2(
        player.velocity.x,
        player.velocity.z,
      ).magnitude;
      expect(horizontalSpeed, closeTo(Constants.moveSpeed, 1e-6));
    });
  });

  group('Redstone', () {
    test(
      'lever powers dust with one-level decay and turns lamp off cleanly',
      () {
        final chunks = ChunkManager(seed: 7)
          ..updateChunks(const Vector3(24, 64, 24));
        final redstone = RedstoneManager();
        const leverPos = Vector3Int(23, 64, 23);
        const dust1Pos = Vector3Int(25, 64, 23);
        const dust2Pos = Vector3Int(27, 64, 23);
        const lampPos = Vector3Int(29, 64, 23);

        for (final entry in const [
          (leverPos, BlockType.lever),
          (dust1Pos, BlockType.redstoneDust),
          (dust2Pos, BlockType.redstoneDust),
          (lampPos, BlockType.redstoneLamp),
        ]) {
          expect(chunks.placeBlock(entry.$1, entry.$2), isTrue);
          redstone.onBlockPlaced(chunks, entry.$1, entry.$2);
        }

        expect(redstone.toggleLever(chunks, leverPos), isTrue);
        expect(chunks.getBlock(dust1Pos)!.powerLevel, 14);
        expect(chunks.getBlock(dust2Pos)!.powerLevel, 13);
        expect(chunks.getBlock(lampPos)!.powerLevel, 15);

        expect(redstone.toggleLever(chunks, leverPos), isFalse);
        expect(chunks.getBlock(dust1Pos)!.powerLevel, 0);
        expect(chunks.getBlock(dust2Pos)!.powerLevel, 0);
        expect(chunks.getBlock(lampPos)!.powerLevel, 0);
      },
    );
  });

  group('Greedy meshing', () {
    test('L-shaped surfaces are not filled into a rectangle', () {
      final blocks = [
        Block(position: const Vector3Int(1, 0, 1), type: BlockType.stone),
        Block(position: const Vector3Int(3, 0, 1), type: BlockType.stone),
        Block(position: const Vector3Int(1, 0, 3), type: BlockType.stone),
      ];

      final topFaces = FaceMerger.mergeVisibleFaces(
        blocks,
        const Vector3(2, 10, 2),
      ).where((face) => face.normal == Vector3Int.up).toList();

      expect(topFaces, hasLength(2));
      final totalArea = topFaces.fold<int>(0, (sum, face) {
        final size = face.bounds.size;
        return sum + size.x * size.z;
      });
      expect(totalArea, 12);
    });

    test('merged rectangles retain internal block grid lines', () {
      final face = MergedFace(
        blockType: BlockType.stone,
        powerLevel: 0,
        normal: Vector3Int.up,
        minBounds: const Vector3Int(0, 1, 0),
        maxBounds: const Vector3Int(6, 1, 4),
      );

      expect(face.gridLines, hasLength(3));
      expect(
        face.gridLines,
        contains((
          start: const Vector3Int(2, 1, 0),
          end: const Vector3Int(2, 1, 4),
        )),
      );
      expect(
        face.gridLines,
        contains((
          start: const Vector3Int(0, 1, 2),
          end: const Vector3Int(6, 1, 2),
        )),
      );
    });
  });

  group('Scene rendering', () {
    test('scene painter renders a generated world without exceptions', () {
      final player = Player(position: const Vector3(24, 34, 24));
      final chunks = ChunkManager(seed: 42)..updateChunks(player.position);
      final painter = ScenePainter(
        SceneInfo(
          position: player.position,
          orientation: player.orientation,
          blocks: chunks.getRenderBlocks(player),
        ),
        'test',
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(320, 180)),
        returnsNormally,
      );
      recorder.endRecording();
    });
  });
}
