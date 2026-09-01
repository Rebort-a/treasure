import 'package:flutter/material.dart';

import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'manager.dart';

class SchultePage extends StatefulWidget {
  const SchultePage({super.key});

  @override
  State<SchultePage> createState() => _SchultePageState();
}

class _SchultePageState extends State<SchultePage>
    with SingleTickerProviderStateMixin {
  late final SchulteManager _manager = SchulteManager();
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _manager.tapFeedback.addListener(_onFeedback);
    _ctrl.addStatusListener(_onStatus);
  }

  /// 反馈状态变化：非空时瞬间满显，然后单向淡出（打断未完成的动画）
  void _onFeedback() {
    if (_manager.tapFeedback.value != null) {
      _ctrl.stop();
      _ctrl.value = 1; // 瞬间满显，点击即见反馈
      _ctrl.reverse(); // 从满显单向淡出
    }
  }

  /// 动画状态：完全消失→清空反馈状态
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _manager.clearFeedback();
    }
  }

  @override
  void dispose() {
    _manager.tapFeedback.removeListener(_onFeedback);
    _ctrl.dispose();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) =>
            _manager.leavePage(),
        child: Scaffold(appBar: _buildAppBar(), body: _buildBody()),
      );

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(S.schulte),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _manager.leavePage,
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _manager.resetGame,
        ),
        IconButton(
          icon: const Icon(Icons.tune),
          onPressed: _manager.showSelector,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        _buildDisplayArea(),
        Expanded(child: _buildBoardArea()),
      ],
    );
  }

  /// 1. 文本显示区：进行中显示下一个数字，结束后显示完成用时
  Widget _buildDisplayArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<String>(
        valueListenable: _manager.displayInfo,
        builder: (_, value, __) => Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 棋盘区：铺满可用区域（矩形，非正方形），点击命中
  Widget _buildBoardArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _manager.handleTap(d.localPosition, w, h),
            child: ValueListenableBuilder<SchulteBoard>(
              valueListenable: _manager.board,
              builder: (_, board, __) =>
                  ValueListenableBuilder<SchulteTapFeedback?>(
                valueListenable: _manager.tapFeedback,
                builder: (_, feedback, __) => CustomPaint(
                  size: Size(w, h),
                  painter: SchulteBoardPainter(
                    board: board,
                    feedback: feedback,
                    progress: _ctrl,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 舒尔特棋盘绘制器：不规则区域填充（扰动四边形）+ 海岸线白线 + 数字
/// 颜色精确到像素点：填充沿扰动角点，与海岸线轮廓完全重合
class SchulteBoardPainter extends CustomPainter {
  final SchulteBoard board;
  final SchulteTapFeedback? feedback;
  final Animation<double> progress;

  SchulteBoardPainter({
    required this.board,
    this.feedback,
    required this.progress,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / board.cols;
    final cellH = size.height / board.rows;
    final n = board.regions.length;

    // 1. 填充：同区域所有格子合并为单个 Path（多子路径）一次填充，
    //    内部共享边无抗锯齿缝隙→区域内部无白线，仅外轮廓有白线
    for (final region in board.regions) {
      canvas.drawPath(
        _regionPath(region, cellW, cellH),
        Paint()
          ..color = _regionColor(region, n)
          ..style = PaintingStyle.fill,
      );
    }

    // 2. 海岸线白线（角点噪声折线，同角点偏移一致 → 段间连续，与填充边界重合）
    _drawCoastlines(canvas, cellW, cellH);

    // 3. 数字（质心，字号随区域大小）
    for (final region in board.regions) {
      if (region.cells.isEmpty) continue;
      final center = Offset(
        region.centroid.dx * cellW + cellW / 2,
        region.centroid.dy * cellH + cellH / 2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: region.number.toString(),
          style: TextStyle(
            fontSize: region.fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }

    // 4. 点击反馈：被点击区域叠加半透明蒙层 + 中心 ✓/✗（progress 驱动淡入淡出）
    _drawFeedback(canvas, cellW, cellH);
  }

  /// 区域填充 Path：沿每个格子的扰动角点画四边形闭合子路径
  /// （同区域多格子合并为单 Path，内部共享边无抗锯齿缝隙）
  Path _regionPath(SchulteRegion region, double cellW, double cellH) {
    final path = Path();
    for (final c in region.cells) {
      final p1 = _corner(c.col, c.row, cellW, cellH);
      final p2 = _corner(c.col + 1, c.row, cellW, cellH);
      final p3 = _corner(c.col + 1, c.row + 1, cellW, cellH);
      final p4 = _corner(c.col, c.row + 1, cellW, cellH);
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
      path.close();
    }
    return path;
  }

  Color _regionColor(SchulteRegion region, int n) {
    final hue = (region.id * 360.0 / n) % 360;
    // 低饱和低亮度作素淡底色，为反馈蒙层让出对比空间
    return HSLColor.fromAHSL(1.0, hue, 0.28, 0.70).toColor();
  }

  /// 收集每格外边界段（邻居不属于本区域的边），用扰动角点画折线
  void _drawCoastlines(Canvas canvas, double cellW, double cellH) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    for (final region in board.regions) {
      final path = Path();
      for (final c in region.cells) {
        // 上边
        if (board.regionIdAt(c.col, c.row - 1) != region.id) {
          final p1 = _corner(c.col, c.row, cellW, cellH);
          final p2 = _corner(c.col + 1, c.row, cellW, cellH);
          path.moveTo(p1.dx, p1.dy);
          path.lineTo(p2.dx, p2.dy);
        }
        // 下边
        if (board.regionIdAt(c.col, c.row + 1) != region.id) {
          final p1 = _corner(c.col, c.row + 1, cellW, cellH);
          final p2 = _corner(c.col + 1, c.row + 1, cellW, cellH);
          path.moveTo(p1.dx, p1.dy);
          path.lineTo(p2.dx, p2.dy);
        }
        // 左边
        if (board.regionIdAt(c.col - 1, c.row) != region.id) {
          final p1 = _corner(c.col, c.row, cellW, cellH);
          final p2 = _corner(c.col, c.row + 1, cellW, cellH);
          path.moveTo(p1.dx, p1.dy);
          path.lineTo(p2.dx, p2.dy);
        }
        // 右边
        if (board.regionIdAt(c.col + 1, c.row) != region.id) {
          final p1 = _corner(c.col + 1, c.row, cellW, cellH);
          final p2 = _corner(c.col + 1, c.row + 1, cellW, cellH);
          path.moveTo(p1.dx, p1.dy);
          path.lineTo(p2.dx, p2.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  /// 点击反馈覆盖层：沿被点击区域 cells 构造蒙层 Path（复用扰动角点，与填充边界重合），
  /// 叠加半透明绿/红色蒙层 + 中心 ✓/✗，透明度由 progress 驱动（瞬间满显后单向淡出）
  void _drawFeedback(Canvas canvas, double cellW, double cellH) {
    final fb = feedback;
    if (fb == null) return;
    final t = progress.value;
    if (t <= 0) return;
    if (fb.regionId < 0 || fb.regionId >= board.regions.length) return;
    final region = board.regions[fb.regionId];
    if (region.cells.isEmpty) return;

    final path = _regionPath(region, cellW, cellH);
    final overlayColor = fb.isCorrect ? Colors.green : Colors.red;
    canvas.drawPath(
      path,
      Paint()
        ..color = overlayColor.withValues(alpha: 0.55 * t)
        ..style = PaintingStyle.fill,
    );

    // 中心 ✓/✗ 图标（质心换算同数字绘制）
    final center = Offset(
      region.centroid.dx * cellW + cellW / 2,
      region.centroid.dy * cellH + cellH / 2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: fb.isCorrect ? '✓' : '✗',
        style: TextStyle(
          fontSize: region.fontSize * 1.8,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: t),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  /// 格子角点像素坐标 + 稳定噪声偏移（基于角点坐标哈希，同角点同偏移）
  Offset _corner(int colCorner, int rowCorner, double cellW, double cellH) {
    final baseX = colCorner * cellW;
    final baseY = rowCorner * cellH;
    final amp = cellW * 0.14;
    final h = _hash(colCorner, rowCorner);
    final dx = ((h & 0xFF) / 255 - 0.5) * 2 * amp;
    final dy = (((h >> 8) & 0xFF) / 255 - 0.5) * 2 * amp;
    return Offset(baseX + dx, baseY + dy);
  }

  /// 稳定整数哈希
  int _hash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return h;
  }

  @override
  bool shouldRepaint(covariant SchulteBoardPainter old) =>
      board != old.board || feedback != old.feedback;
}
