import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/block.dart';
import '../base/constant.dart';
import '../base/vector.dart';
import '../base/matrix.dart';
import '../middle/common.dart';
import 'face_merger.dart';
import 'occlusion_culler.dart';
import 'frustum.dart';

/// 场景渲染器
class ScenePainter extends CustomPainter {
  final SceneInfo sceneInfo;
  final String debugInfo;
  final OcclusionCuller occlusionCuller;
  late FrustumManager _frustum;
  late ColMat4 _viewProjectionMatrix;
  late Vector3 _cameraForward;
  final RenderDebugConfig debugConfig;
  final FaceMeshCache faceMeshCache;
  final int _debugSignature;

  ScenePainter(
    this.sceneInfo,
    this.debugInfo, {
    RenderDebugConfig? debugConfig,
    FaceMeshCache? faceMeshCache,
  }) : debugConfig = debugConfig ?? RenderDebugConfig(),
       faceMeshCache = faceMeshCache ?? FaceMeshCache(),
       _debugSignature = (debugConfig ?? RenderDebugConfig()).signature,
       occlusionCuller = OcclusionCuller() {
    _updateFrustum(Size(800, 600));
  }

  int _totalBlocks = 0;
  int _frustumCulled = 0;
  int _occlusionCulled = 0;
  int _renderedFaces = 0;
  int _mergedFaces = 0;

  @override
  void paint(Canvas canvas, Size size) {
    _resetStats();
    _updateFrustum(size);
    if (debugConfig.enableOcclusionCulling) {
      _updateOcclusionCuller();
    }

    _renderScene(canvas, size);
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.sceneInfo.position != sceneInfo.position ||
        oldDelegate.sceneInfo.orientation != sceneInfo.orientation ||
        oldDelegate.sceneInfo.revision != sceneInfo.revision ||
        oldDelegate.sceneInfo.targetedBlock != sceneInfo.targetedBlock ||
        oldDelegate.sceneInfo.targetedFaceNormal !=
            sceneInfo.targetedFaceNormal ||
        oldDelegate.debugInfo != debugInfo ||
        oldDelegate._debugSignature != _debugSignature;
  }

  void _renderScene(Canvas canvas, Size size) {
    _drawSkyBackground(canvas, size);
    _render3DGeometry(canvas, size);

    if (debugConfig.showDebugInfo) {
      _drawDebugOverlay(canvas, size);
    } else {
      _drawPositionDisplay(canvas, size);
    }

    if (debugConfig.showFrustum) {
      _drawFrustum(canvas, size);
    }
  }

  void _resetStats() {
    _totalBlocks = 0;
    _frustumCulled = 0;
    _occlusionCulled = 0;
    _renderedFaces = 0;
    _mergedFaces = 0;
  }

  void _updateFrustum(Size size) {
    _cameraForward = sceneInfo.orientation.normalized;
    final viewMatrix = ColMat4.lookAtLH(
      sceneInfo.position,
      sceneInfo.position + _cameraForward,
      Vector3Unit.up,
    );
    final projectionMatrix = ColMat4.perspectiveLH(
      Constants.fieldOfView * math.pi / 180,
      size.width / math.max(size.height, 1),
      Constants.nearClip,
      Constants.farClip,
    );
    _viewProjectionMatrix = projectionMatrix * viewMatrix;
    _frustum = FrustumManager.fromViewProjectionMatrix(_viewProjectionMatrix);
  }

  void _updateOcclusionCuller() {
    occlusionCuller.clear();

    // 改进的遮挡物选择策略
    final maxOccluderDistance = Constants.renderDistance * 0.8;
    final maxOccluderDistanceSquared =
        maxOccluderDistance * maxOccluderDistance;
    final potentialOccluders =
        sceneInfo.blocks.where((block) {
          if (block.type.isTransparent) return false;

          final toBlock = block.position.toVector3() - sceneInfo.position;
          if (toBlock.magnitudeSquare > maxOccluderDistanceSquared) {
            return false;
          }

          return toBlock.dot(_cameraForward) > -Constants.blockSize.toDouble();
        }).toList()..sort((a, b) {
          final distanceA =
              (a.position.toVector3() - sceneInfo.position).magnitudeSquare;
          final distanceB =
              (b.position.toVector3() - sceneInfo.position).magnitudeSquare;
          return distanceA.compareTo(distanceB);
        });

    final selectedOccluders = potentialOccluders.take(32).toList();

    for (final block in selectedOccluders) {
      occlusionCuller.addOccluder(block.collider.aabb.toAABB());
    }
  }

  /// 绘制天空背景
  void _drawSkyBackground(Canvas canvas, Size size) {
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFF87CEEB), const Color(0xFF98D8E8)],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = skyGradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        ),
    );
  }

  void _render3DGeometry(Canvas canvas, Size size) {
    final visibleBlocks = _getVisibleBlocks();
    if (visibleBlocks.isEmpty) return;

    if (debugConfig.enableFaceMerging) {
      _renderWithFaceMerging(canvas, size, visibleBlocks);
    } else {
      _renderIndividualBlocks(canvas, size, visibleBlocks);
    }

    if (debugConfig.showBlockOutline) _drawBlockOutlines(canvas, size);
  }

  /// 绘制目标方块轮廓（红色=可摧毁，绿色=可放置）
  void _drawBlockOutlines(Canvas canvas, Size size) {
    final target = sceneInfo.targetedBlock;
    final faceNormal = sceneInfo.targetedFaceNormal;
    if (target == null) return;

    // 红色轮廓：目标方块（可摧毁）
    _drawBlockOutline(canvas, size, target, Colors.red.withValues(alpha: 0.8));

    // 绿色轮廓：放置位置（可放置）
    if (faceNormal != null) {
      final placePos = target.position + faceNormal * Constants.blockSize;
      final half = Constants.blockSizeHalf;
      _drawWireBox(
        canvas,
        size,
        Vector3(
          placePos.x.toDouble(),
          placePos.y.toDouble(),
          placePos.z.toDouble(),
        ),
        half.toDouble(),
        Colors.green.withValues(alpha: 0.6),
      );
    }
  }

  void _drawBlockOutline(Canvas canvas, Size size, Block block, Color color) {
    final half = Constants.blockSizeHalf.toDouble();
    _drawWireBox(canvas, size, block.position.toVector3(), half, color);
  }

  void _drawWireBox(
    Canvas canvas,
    Size size,
    Vector3 center,
    double half,
    Color color,
  ) {
    // 8 个顶点
    final corners = [
      Vector3(center.x - half, center.y - half, center.z - half),
      Vector3(center.x + half, center.y - half, center.z - half),
      Vector3(center.x + half, center.y + half, center.z - half),
      Vector3(center.x - half, center.y + half, center.z - half),
      Vector3(center.x - half, center.y - half, center.z + half),
      Vector3(center.x + half, center.y - half, center.z + half),
      Vector3(center.x + half, center.y + half, center.z + half),
      Vector3(center.x - half, center.y + half, center.z + half),
    ];

    final screenPts = corners.map((v) => _project3DTo2D(v, size)).toList();

    if (screenPts.any((p) => p == Offset.infinite)) return;

    // 收集可见面的边（去重）
    final toCamera = (sceneInfo.position - center).normalized;
    final drawnEdges = <String>{};

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // 6 个面的法向量和顶点
    void addFaceEdges(List<int> verts, Vector3 normal) {
      if (normal.dot(toCamera) <= 0) return;
      for (int i = 0; i < 4; i++) {
        final a = verts[i], b = verts[(i + 1) % 4];
        final key = a < b ? '$a-$b' : '$b-$a';
        if (drawnEdges.add(key)) {
          canvas.drawLine(screenPts[a], screenPts[b], paint);
        }
      }
    }

    addFaceEdges([0, 1, 2, 3], Vector3(0, 0, -1)); // -Z
    addFaceEdges([4, 5, 6, 7], Vector3(0, 0, 1)); // +Z
    addFaceEdges([0, 4, 7, 3], Vector3(-1, 0, 0)); // -X
    addFaceEdges([1, 5, 6, 2], Vector3(1, 0, 0)); // +X
    addFaceEdges([3, 2, 6, 7], Vector3(0, 1, 0)); // +Y
    addFaceEdges([0, 1, 5, 4], Vector3(0, -1, 0)); // -Y
  }

  void _renderWithFaceMerging(Canvas canvas, Size size, List<Block> blocks) {
    // 合并面
    final mergedFaces = FaceMerger.filterVisibleFaces(
      faceMeshCache.resolve(blocks),
      sceneInfo.position,
    );
    _mergedFaces = mergedFaces.length;

    // Canvas 没有深度缓冲。BSP 会在其他面的平面处切开跨越前后两侧的
    // 大面，再生成稳定的从远到近顺序，避免屏幕边缘出现漏出的三角形。
    final sortedFaces = debugConfig.enableDepthSorting
        ? FaceDepthSorter.sort(mergedFaces, sceneInfo.position, _cameraForward)
        : mergedFaces;

    // 渲染合并后的面
    for (final face in sortedFaces) {
      _renderMergedFace(canvas, size, face);
      _renderedFaces++;
    }
  }

  void _renderIndividualBlocks(Canvas canvas, Size size, List<Block> blocks) {
    final sortedBlocks = _sortBlocksByDepth(blocks);

    for (final block in sortedBlocks) {
      _renderSingleBlock(canvas, size, block);
    }
  }

  List<Block> _getVisibleBlocks() {
    _totalBlocks = sceneInfo.blocks.length;
    final List<Block> visibleBlocks = [];

    for (final block in sceneInfo.blocks) {
      final blockAABB = block.collider.aabb.toAABB();
      // 视锥体裁剪
      if (debugConfig.enableFrustumCulling) {
        if (!_frustum.intersectsAABB(blockAABB)) {
          _frustumCulled++;
          continue;
        }
      }

      // 遮挡剔除
      if (debugConfig.enableOcclusionCulling) {
        final occlusionResult = occlusionCuller.checkOcclusion(
          blockAABB,
          sceneInfo.position,
        );

        if (occlusionResult == OcclusionResult.fullyOccluded) {
          _occlusionCulled++;
          continue;
        }
      }

      if (debugConfig.enableNearClip) {
        final relativePos = block.position.toVector3() - sceneInfo.position;
        final viewSpacePos = _transformToViewSpace(relativePos);
        if (viewSpacePos.z + Constants.blockSizeHalf <= Constants.nearClip) {
          continue;
        }
      }

      visibleBlocks.add(block);
    }

    return visibleBlocks;
  }

  List<Block> _sortBlocksByDepth(List<Block> blocks) {
    if (!debugConfig.enableDepthSorting) return blocks;

    blocks.sort((a, b) {
      final depthA = _cameraDepth(a.position.toVector3());
      final depthB = _cameraDepth(b.position.toVector3());
      return depthB.compareTo(depthA);
    });
    return blocks;
  }

  void _renderMergedFace(Canvas canvas, Size size, MergedFace face) {
    final screenVertices = _projectPolygonToScreen(
      face.vertices.map((vertex) => vertex.toVector3()).toList(),
      size,
    );

    if (screenVertices.length < 3) return;

    final clippedVertices = _clipToScreenBounds(screenVertices, size);
    if (clippedVertices.length < 3) return;

    final fogFactor = _calcFogFactor(face.bounds.center.toVector3());
    _drawPolygonFace(
      canvas,
      face.blockType,
      clippedVertices,
      face.normal,
      fogFactor,
      face.powerLevel,
    );
    _drawMergedFaceGrid(canvas, size, face);
  }

  void _drawMergedFaceGrid(Canvas canvas, Size size, MergedFace face) {
    if (face.blockType == BlockType.glass) return;

    final paint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1;

    for (final line in face.gridLines) {
      final start = _project3DTo2D(line.start.toVector3(), size);
      final end = _project3DTo2D(line.end.toVector3(), size);
      if (start == Offset.infinite || end == Offset.infinite) continue;
      canvas.drawLine(start, end, paint);
    }
  }

  void _renderSingleBlock(Canvas canvas, Size size, Block block) {
    final visibleFaces = _getVisibleFaces(block);
    if (visibleFaces.isEmpty) return;

    final sortedFaces = _sortFacesByDepth(visibleFaces);

    for (final face in sortedFaces) {
      _renderBlockFace(canvas, size, block, face);
      _renderedFaces++;
    }
  }

  List<BlockFace> _getVisibleFaces(Block block) {
    if (!debugConfig.enableBackfaceCulling) {
      return block.faces;
    } else {
      return block.getVisibleFaces(sceneInfo.position);
    }
  }

  List<BlockFace> _sortFacesByDepth(List<BlockFace> faces) {
    if (!debugConfig.enableDepthSorting) return faces;

    faces.sort((a, b) {
      final depthA = _calculateFaceDepth(a);
      final depthB = _calculateFaceDepth(b);
      return depthB.compareTo(depthA);
    });
    return faces;
  }

  double _calculateFaceDepth(BlockFace face) =>
      _cameraDepth(face.center.toVector3());

  void _renderBlockFace(Canvas canvas, Size size, Block block, BlockFace face) {
    final screenVertices = _projectPolygonToScreen(
      face.vertices.map((vertex) => vertex.toVector3()).toList(),
      size,
    );
    final clippedVertices = _clipToScreenBounds(screenVertices, size);

    if (clippedVertices.length < 3) return;

    final fogFactor = _calcFogFactor(block.position.toVector3());
    _drawPolygonFace(
      canvas,
      block.type,
      clippedVertices,
      face.normal,
      fogFactor,
      block.powerLevel,
    );

    // 绘制调试信息
    if (debugConfig.showFaceNormals) {
      _drawFaceNormal(canvas, size, face, block.position.toVector3());
    }
  }

  /// 先在世界空间裁剪近平面，再投影到屏幕，避免相机后方顶点产生巨型多边形。
  List<Offset> _projectPolygonToScreen(List<Vector3> vertices, Size size) {
    return _clipPolygonToNearPlane(vertices)
        .map((vertex) => _project3DTo2D(vertex, size))
        .where((vertex) => vertex != Offset.infinite)
        .toList();
  }

  List<Vector3> _clipPolygonToNearPlane(List<Vector3> vertices) {
    if (!debugConfig.enableNearClip || vertices.isEmpty) return vertices;

    final output = <Vector3>[];
    var previous = vertices.last;
    var previousDepth = _cameraDepth(previous);
    var previousInside = previousDepth >= Constants.nearClip;

    for (final current in vertices) {
      final currentDepth = _cameraDepth(current);
      final currentInside = currentDepth >= Constants.nearClip;

      if (currentInside != previousInside) {
        final denominator = currentDepth - previousDepth;
        if (denominator.abs() > Constants.epsilon) {
          final t = (Constants.nearClip - previousDepth) / denominator;
          output.add(previous + (current - previous) * t);
        }
      }
      if (currentInside) output.add(current);

      previous = current;
      previousDepth = currentDepth;
      previousInside = currentInside;
    }
    return output;
  }

  double _cameraDepth(Vector3 point) =>
      (point - sceneInfo.position).dot(_cameraForward);

  /// 裁剪到屏幕边界
  List<Offset> _clipToScreenBounds(List<Offset> vertices, Size size) {
    if (!debugConfig.enableScreenClipping) {
      return vertices.where((v) => v != Offset.infinite).toList();
    }
    return _clipPolygonToScreen(vertices, size);
  }

  /// 3D点投影到2D屏幕（透视投影）
  // Offset _project3DTo2D(Vector3 point, Size size) {
  //   final relativePoint = point - sceneInfo.position;
  //   final rotatedPoint = _transformToViewSpace(relativePoint);

  //   // 处理近裁剪面：避免除以0或负数（导致投影异常）
  //   final zValue = rotatedPoint.z;
  //   final divisor = zValue > Constants.nearClip ? zValue : Constants.nearClip;
  //   final scale = Constants.focalLength / divisor;

  //   // 屏幕中心为原点，转换为屏幕坐标（x向右，y向上）
  //   final x = size.width / 2 + rotatedPoint.x * scale;
  //   final y = size.height / 2 - rotatedPoint.y * scale;

  //   return Offset(x, y);
  // }

  /// 3D到2D投影变换
  Offset _project3DTo2D(Vector3 point, Size size) {
    final worldPoint = Vector4(point.x, point.y, point.z, 1);
    final clipPoint = _viewProjectionMatrix.multiplyVector4(worldPoint);
    if (clipPoint.w <= Constants.epsilon) return Offset.infinite;

    final ndcX = clipPoint.x / clipPoint.w;
    final ndcY = clipPoint.y / clipPoint.w;

    final screenX =
        (ndcX * Constants.ndcScale + Constants.ndcOffset) * size.width;
    final screenY =
        (Constants.screenYFlip -
            (ndcY * Constants.ndcScale + Constants.ndcOffset)) *
        size.height;

    return Offset(screenX, screenY);
  }

  /// 变换到视图空间（用于可见性判断）
  Vector3 _transformToViewSpace(Vector3 point) {
    final forward = _cameraForward;
    final right = Vector3.up.cross(forward).normalized;
    final up = forward.cross(right).normalized;

    return Vector3(
      point.dot(right), // X: 右方向
      point.dot(up), // Y: 上方向
      point.dot(forward), // Z: 前方向（深度）
    );
  }

  /// 雾效颜色（与天空背景一致）
  static const Color _fogColor = Color(0xFF87CEEB);

  /// 红石灯亮色
  static const Color _lampOnColor = Color(0xFFFFEB3B);

  /// 红石灯灭色
  static const Color _lampOffColor = Color(0xFF424242);

  /// 获取方块颜色（红石方块根据 powerLevel 变化）
  Color _getBlockColor(BlockType type, int powerLevel) {
    switch (type) {
      case BlockType.redstoneDust:
        // 暗红 → 亮红，根据信号强度
        final ratio = powerLevel / Constants.redstoneMaxPower;
        return Color.lerp(
          const Color(0xFF440000),
          const Color(0xFFFF0000),
          ratio,
        )!;
      case BlockType.redstoneLamp:
        return powerLevel > 0 ? _lampOnColor : _lampOffColor;
      case BlockType.redstoneTorch:
        return const Color(0xFFFF4444);
      case BlockType.lever:
        return powerLevel > 0
            ? const Color(0xFFA5D6A7) // 激活：亮绿
            : const Color(0xFF795548); // 未激活：暗棕
      default:
        return type.color;
    }
  }

  void _drawPolygonFace(
    Canvas canvas,
    BlockType blockType,
    List<Offset> vertices,
    Vector3Int normal, [
    double fogFactor = 0.0,
    int powerLevel = 0,
  ]) {
    final path = Path()..addPolygon(vertices, true);
    final baseColor = _getBlockColor(blockType, powerLevel);
    final shadedColor = _applyFaceLighting(baseColor, normal);
    final finalColor = fogFactor > 0
        ? Color.lerp(shadedColor, _fogColor, fogFactor)!
        : shadedColor;

    canvas.drawPath(path, Paint()..color = finalColor);

    if (blockType != BlockType.glass) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  /// 计算雾效因子（0=无雾，1=全雾）
  double _calcFogFactor(Vector3 worldPos) {
    final dist = (worldPos - sceneInfo.position).magnitude;
    if (dist <= Constants.fogStart) return 0.0;
    if (dist >= Constants.fogEnd) return 1.0;
    return (dist - Constants.fogStart) /
        (Constants.fogEnd - Constants.fogStart);
  }

  /// 应用面光照
  Color _applyFaceLighting(Color baseColor, Vector3Int normal) {
    final brightness = switch ((normal.z, normal.y)) {
      (< 0, _) => Constants.lightingBackFace, // 背面
      (> 0, _) => Constants.lightingFrontFace, // 正面
      (0, > 0) => Constants.lightingTopFace, // 顶面
      (0, < 0) => Constants.lightingBottomFace, // 底面
      _ => Constants.lightingDefault, // 侧面
    };

    return baseColor.withValues(
      red: (baseColor.r * brightness).clamp(0.0, 1.0),
      green: (baseColor.g * brightness).clamp(0.0, 1.0),
      blue: (baseColor.b * brightness).clamp(0.0, 1.0),
    );
  }

  void _drawFrustum(Canvas canvas, Size size) {
    final invViewProj = _viewProjectionMatrix.inverse();

    final corners = _frustum.getCorners(invViewProj);
    final screenCorners = corners
        .map((corner) => _project3DTo2D(corner, size))
        .toList();

    if (screenCorners.any((corner) => corner == Offset.infinite)) return;

    // 绘制视锥体边线
    final lines = [
      [0, 1], [1, 3], [3, 2], [2, 0], // 近平面
      [4, 5], [5, 7], [7, 6], [6, 4], // 远平面
      [0, 4], [1, 5], [2, 6], [3, 7], // 连接线
    ];

    for (final line in lines) {
      if (line[0] < screenCorners.length && line[1] < screenCorners.length) {
        canvas.drawLine(
          screenCorners[line[0]],
          screenCorners[line[1]],
          Paint()
            ..color = Colors.yellow.withValues(alpha: 0.5)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  // ===========================================================================
  // 调试信息
  // ===========================================================================

  void _drawDebugOverlay(Canvas canvas, Size size) {
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      shadows: [
        Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1)),
      ],
    );

    final debugText =
        '''
Position: (${sceneInfo.position.x.toStringAsFixed(1)}, ${sceneInfo.position.y.toStringAsFixed(1)}, ${sceneInfo.position.z.toStringAsFixed(1)})
Orientation: (${sceneInfo.orientation.x.toStringAsFixed(1)}, ${sceneInfo.orientation.y.toStringAsFixed(1)}, ${sceneInfo.orientation.z.toStringAsFixed(1)})
Total Blocks: $_totalBlocks
Frustum Culled: $_frustumCulled
Occlusion Culled: $_occlusionCulled
Rendered Faces: $_renderedFaces
Merged Faces: $_mergedFaces
$debugInfo
''';

    final textSpan = TextSpan(text: debugText, style: textStyle);
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, const Offset(10, 10));
  }

  /// 绘制Position坐标（黑色圆角背景+垂直排列）
  void _drawPositionDisplay(Canvas canvas, Size size) {
    // 1. 构建坐标文本（垂直排列x/y/z）
    final position = sceneInfo.position;
    final posText =
        '''X: ${position.x.toStringAsFixed(1)}
Y: ${position.y.toStringAsFixed(1)}
Z: ${position.z.toStringAsFixed(1)}''';

    // 2. 配置文本样式（白色清晰显示）
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.2, // 行高，优化垂直间距
    );

    // 3. 测量文本尺寸（用于计算背景大小）
    final textSpan = TextSpan(text: posText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3, // 固定3行，避免异常换行
    );
    textPainter.layout(); // 执行测量

    // 4. 配置显示参数（边缘间距+内边距+圆角）
    const edgeTopMargin = 32.0; // 距离窗口边缘的距离
    const edgeLeftMargin = 10.0;
    const paddingH = 8.0; // 文本水平内边距
    const paddingV = 4.0; // 文本垂直内边距
    const radius = 4.0; // 圆角半径

    // 5. 计算背景矩形位置和大小
    final bgWidth = textPainter.width + paddingH * 2;
    final bgHeight = textPainter.height + paddingV * 2;
    final bgRect = Rect.fromLTWH(
      edgeLeftMargin, // 左边缘间距
      edgeTopMargin, // 上边缘间距
      bgWidth,
      bgHeight,
    );

    // 6. 绘制黑色圆角背景
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(radius)),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // 7. 绘制文本（居中对齐背景）
    textPainter.paint(
      canvas,
      Offset(
        edgeLeftMargin + paddingH, // 文本水平偏移（边缘间距+内边距）
        edgeTopMargin + paddingV, // 文本垂直偏移（边缘间距+内边距）
      ),
    );
  }

  /// 绘制面法向量（调试用）
  void _drawFaceNormal(
    Canvas canvas,
    Size size,
    BlockFace face,
    Vector3 blockPosition,
  ) {
    final faceCenter = _project3DTo2D(face.center.toVector3(), size);
    final normalEnd = _project3DTo2D(
      face.center.toVector3() + face.normal.toVector3() * 0.5,
      size,
    );

    canvas.drawLine(
      faceCenter,
      normalEnd,
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2,
    );
  }

  List<Offset> _clipPolygonToScreen(List<Offset> polygon, Size size) {
    final screen = Offset.zero & size;
    List<Offset> clipped = polygon;

    // 定义裁剪边界判断函数
    bool insideLeft(Offset p) => p.dx >= screen.left;
    bool insideRight(Offset p) => p.dx <= screen.right;
    bool insideBottom(Offset p) => p.dy <= screen.bottom;
    bool insideTop(Offset p) => p.dy >= screen.top;

    // 裁剪左边界
    clipped = _clipPolygonEdge(
      clipped,
      insideLeft,
      (a, b) => _intersectVertical(a, b, screen.left),
    );
    // 裁剪右边界
    clipped = _clipPolygonEdge(
      clipped,
      insideRight,
      (a, b) => _intersectVertical(a, b, screen.right),
    );
    // 裁剪下边界
    clipped = _clipPolygonEdge(
      clipped,
      insideBottom,
      (a, b) => _intersectHorizontal(a, b, screen.bottom),
    );
    // 裁剪上边界
    clipped = _clipPolygonEdge(
      clipped,
      insideTop,
      (a, b) => _intersectHorizontal(a, b, screen.top),
    );

    return clipped;
  }

  List<Offset> _clipPolygonEdge(
    List<Offset> input,
    bool Function(Offset) isInside,
    Offset Function(Offset, Offset) getIntersection,
  ) {
    final output = <Offset>[];
    final len = input.length;

    for (int i = 0; i < len; i++) {
      final current = input[i];
      final prev = input[(i - 1 + len) % len];

      final curIn = isInside(current);
      final prevIn = isInside(prev);

      if (curIn && prevIn) {
        output.add(current);
      } else if (curIn && !prevIn) {
        output.add(getIntersection(prev, current));
        output.add(current);
      } else if (!curIn && prevIn) {
        output.add(getIntersection(prev, current));
      }
    }

    return output;
  }

  Offset _intersectHorizontal(Offset a, Offset b, double y) {
    final t = (y - a.dy) / (b.dy - a.dy);
    return Offset(a.dx + t * (b.dx - a.dx), y);
  }

  Offset _intersectVertical(Offset a, Offset b, double x) {
    final t = (x - a.dx) / (b.dx - a.dx);
    return Offset(x, a.dy + t * (b.dy - a.dy));
  }
}
