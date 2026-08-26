import 'package:flutter/material.dart';

import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'manager.dart';

class SchultePage extends StatelessWidget {
  final SchulteManager _manager = SchulteManager();

  SchultePage({super.key});

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

  /// 显示区：左用时，右下一个数字
  Widget _buildDisplayArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<int>(
        valueListenable: _manager.nextNumber,
        builder: (_, n, __) => Text(
          S.nextNumber(n),
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
          return ValueListenableBuilder<SchulteBoard>(
            valueListenable: _manager.board,
            builder: (_, board, __) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _manager.handleTap(d.localPosition, w, h),
              child: CustomPaint(
                size: Size(w, h),
                painter: SchulteBoardPainter(board: board),
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

  SchulteBoardPainter({required this.board});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / board.cols;
    final cellH = size.height / board.rows;
    final n = board.regions.length;

    // 1. 填充：同区域所有格子合并为单个 Path（多子路径）一次填充，
    //    内部共享边无抗锯齿缝隙→区域内部无白线，仅外轮廓有白线
    for (final region in board.regions) {
      final paint = Paint()
        ..color = _regionColor(region, n)
        ..style = PaintingStyle.fill;
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
      canvas.drawPath(path, paint);
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
  }

  Color _regionColor(SchulteRegion region, int n) {
    final hue = (region.id * 360.0 / n) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.45, 0.78).toColor();
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
  bool shouldRepaint(covariant SchulteBoardPainter old) => board != old.board;
}
