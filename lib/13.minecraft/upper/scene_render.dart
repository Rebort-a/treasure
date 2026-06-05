import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../base/block.dart';
import '../base/constant.dart';
import 'face_merger.dart';
import '../base/matrix.dart';
import 'occlusion_culler.dart';
import '../base/vector.dart';
import 'frustum.dart';
import '../middle/common.dart';

/// 渲染调试配置
class RenderDebugConfig {
  /// 近裁剪面剔除
  bool enableNearClip = true;

  /// 背面剔除
  bool enableBackfaceCulling = true;

  /// 深度排序
  bool enableDepthSorting = true;

  /// 屏幕裁剪
  bool enableScreenClipping = true;

  /// 视锥体裁剪
  bool enableFrustumCulling = true;

  /// 遮挡剔除
  bool enableOcclusionCulling = true;

  // 合并渲染
  bool enableFaceMerging = true;

  /// 调试信息
  bool showDebugInfo = true;

  /// 面法向量
  bool showFaceNormals = false;

  /// 顶点坐标
  bool showVertexPositions = false;

  /// 视锥体
  bool showFrustum = false;
}

/// 场景渲染器
class ScenePainter extends CustomPainter {
  final SceneInfo sceneInfo;
  final String debugInfo;
  final OcclusionCuller occlusionCuller;
  late FrustumManager _frustum;
  final RenderDebugConfig debugConfig = RenderDebugConfig();

  ScenePainter(this.sceneInfo, this.debugInfo)
    : occlusionCuller = OcclusionCuller() {
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
    _updateOcclusionCuller();

    _renderScene(canvas, size);
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.sceneInfo.position != sceneInfo.position ||
        oldDelegate.sceneInfo.orientation != sceneInfo.orientation;
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
    final viewMatrix = ColMat4.lookAtLH(
      sceneInfo.position,
      sceneInfo.position + sceneInfo.orientation.normalized,
      Vector3Unit.up,
    );
    final projectionMatrix = ColMat4.perspectiveLH(
      Constants.fieldOfView * math.pi / 180,
      size.width / size.height,
      Constants.nearClip,
      Constants.farClip,
    );
    final vpMatrix = projectionMatrix * viewMatrix;
    _frustum = FrustumManager.fromViewProjectionMatrix(vpMatrix);
  }

  void _updateOcclusionCuller() {
    occlusionCuller.clear();

    // 改进的遮挡物选择策略
    final potentialOccluders = sceneInfo.blocks.where((block) {
      final blockPos = block.position.toVector3();
      final toBlock = blockPos - sceneInfo.position;
      final distance = toBlock.magnitudeSquare;

      // 1. 距离检查：选择渲染距离内的方块
      if (distance > Constants.renderDistance * 0.8) {
        return false;
      }

      // 2. 方向检查：放宽条件，允许部分前方的方块作为遮挡物
      final dotProduct = toBlock.dot(sceneInfo.orientation.normalized);

      return dotProduct > -1.0;
    }).toList();

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
  }

  void _renderWithFaceMerging(Canvas canvas, Size size, List<Block> blocks) {
    // 合并面
    final mergedFaces = FaceMerger.mergeVisibleFaces(
      blocks,
      sceneInfo.position,
    );
    _mergedFaces = mergedFaces.length;

    // 深度排序
    final sortedFaces = _sortMergedFacesByDepth(mergedFaces);

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
      final distA =
          (a.position.toVector3() - sceneInfo.position).magnitudeSquare;
      final distB =
          (b.position.toVector3() - sceneInfo.position).magnitudeSquare;
      return distB.compareTo(distA);
    });
    return blocks;
  }

  List<MergedFace> _sortMergedFacesByDepth(List<MergedFace> faces) {
    if (!debugConfig.enableDepthSorting) return faces;

    faces.sort((a, b) {
      final distA =
          (a.bounds.center.toVector3() - sceneInfo.position).magnitudeSquare;
      final distB =
          (b.bounds.center.toVector3() - sceneInfo.position).magnitudeSquare;
      return distB.compareTo(distA);
    });
    return faces;
  }

  void _renderMergedFace(Canvas canvas, Size size, MergedFace face) {
    final screenVertices = face.vertices
        .map((vertex) => _project3DTo2D(vertex.toVector3(), size))
        .where((vertex) => vertex != Offset.infinite)
        .toList();

    if (screenVertices.length < 3) return;

    final clippedVertices = _clipToScreenBounds(screenVertices, size);
    if (clippedVertices.length < 3) return;

    _drawPolygonFace(canvas, face.blockType, clippedVertices, face.normal);
  }

  void _renderSingleBlock(Canvas canvas, Size size, Block block) {
    final visibleFaces = _getVisibleFaces(block);
    if (visibleFaces.isEmpty) return;

    final sortedFaces = _sortFacesByDepth(
      visibleFaces,
      block.position.toVector3(),
    );

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

  List<BlockFace> _sortFacesByDepth(
    List<BlockFace> faces,
    Vector3 blockPosition,
  ) {
    if (!debugConfig.enableDepthSorting) return faces;

    faces.sort((a, b) {
      final depthA = _calculateFaceDepth(a, blockPosition);
      final depthB = _calculateFaceDepth(b, blockPosition);
      return depthB.compareTo(depthA);
    });
    return faces;
  }

  double _calculateFaceDepth(BlockFace face, Vector3 blockPosition) {
    return (face.center.toVector3() - sceneInfo.position).magnitudeSquare;
  }

  void _renderBlockFace(Canvas canvas, Size size, Block block, BlockFace face) {
    final worldVertices = face.vertices;
    final screenVertices = _projectVerticesToScreen(worldVertices, size);
    final clippedVertices = _clipToScreenBounds(screenVertices, size);

    if (clippedVertices.length < 3) return;

    _drawPolygonFace(canvas, block.type, clippedVertices, face.normal);

    // 绘制调试信息
    if (debugConfig.showFaceNormals) {
      _drawFaceNormal(canvas, size, face, block.position.toVector3());
    }
  }

  /// 投影顶点到屏幕空间
  List<Offset> _projectVerticesToScreen(List<Vector3Int> vertices, Size size) {
    return vertices
        .map((vertex) => _project3DTo2D(vertex.toVector3(), size))
        .toList();
  }

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
    // 构建视图投影矩阵
    final viewMatrix = ColMat4.lookAtLH(
      sceneInfo.position,
      sceneInfo.position + sceneInfo.orientation.normalized,
      Vector3Unit.up,
    );

    final projectionMatrix = ColMat4.perspectiveLH(
      Constants.fieldOfView * math.pi / 180,
      size.width / size.height,
      Constants.nearClip,
      Constants.farClip,
    );

    final vpMatrix = projectionMatrix * viewMatrix;
    final worldPoint = Vector4(point.x, point.y, point.z, 1);
    final clipPoint = vpMatrix.multiplyVector4(worldPoint);

    double ndcX, ndcY;

    if (clipPoint.w <= 0) {
      // 处理相机后面的点
      final w = 0.001; // 避免除零
      ndcX = clipPoint.x / w;
      ndcY = clipPoint.y / w;
    } else {
      // 正常透视除法
      ndcX = clipPoint.x / clipPoint.w;
      ndcY = clipPoint.y / clipPoint.w;
    }

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
    final forward = sceneInfo.orientation.normalized;
    final right = Vector3.up.cross(forward).normalized;
    final up = forward.cross(right).normalized;

    return Vector3(
      point.dot(right), // X: 右方向
      point.dot(up), // Y: 上方向
      point.dot(forward), // Z: 前方向（深度）
    );
  }

  void _drawPolygonFace(
    Canvas canvas,
    BlockType blockType,
    List<Offset> vertices,
    Vector3Int normal,
  ) {
    final path = Path()..addPolygon(vertices, true);
    final baseColor = blockType.color;
    final shadedColor = _applyFaceLighting(baseColor, normal);

    canvas.drawPath(path, Paint()..color = shadedColor);

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
    final viewMatrix = ColMat4.lookAtLH(
      sceneInfo.position,
      sceneInfo.position + sceneInfo.orientation.normalized,
      Vector3Unit.up,
    );
    final projectionMatrix = ColMat4.perspectiveLH(
      Constants.fieldOfView * math.pi / 180,
      size.width / size.height,
      Constants.nearClip,
      Constants.farClip,
    );
    final vpMatrix = projectionMatrix * viewMatrix;
    final invViewProj = vpMatrix.inverse();

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
