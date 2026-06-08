import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/widget/notifier_navigator.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/parchment_texture.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'manager.dart';

class SudokuPage extends StatelessWidget {
  final Manager _manager = Manager();

  SudokuPage({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, Object? result) =>
        _manager.leavePage(),
    child: _buildPage(),
  );

  Widget _buildPage() {
    return ValueListenableBuilder<bool>(
      valueListenable: _manager.nightTheme,
      builder: (context, isNightMode, _) {
        return Scaffold(
          appBar: _buildAppBar(isNightMode),
          body: _buildBody(isNightMode),
        );
      },
    );
  }

  AppBar _buildAppBar(bool isNightMode) {
    return AppBar(
      title:
          Text(S.sudoku, style: isNightMode ? MagicTheme.titleStyle : null),
      backgroundColor: isNightMode
          ? MagicTheme.magicBackground.withValues(alpha: 0.7)
          : null,
      leadingWidth: 148,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLeadingAction(
            icon: Icons.arrow_back,
            onPressed: _manager.leavePage,
            isNightMode: isNightMode,
          ),
          _buildLeadingAction(
            icon: Icons.file_upload,
            onPressed: _manager.openImport,
            isNightMode: isNightMode,
          ),
          _buildLeadingAction(
            icon: Icons.refresh,
            onPressed: _manager.resetGame,
            isNightMode: isNightMode,
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        _buildAppBarAction(
          icon: isNightMode ? Icons.sunny : Icons.nights_stay,
          onPressed: () => _manager.setNightTheme(!isNightMode),
          isNightMode: isNightMode,
        ),
        _buildAppBarAction(
          icon: Icons.tune,
          onPressed: _manager.showSelector,
          isNightMode: isNightMode,
        ),
      ],
    );
  }

  Widget _buildLeadingAction({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isNightMode,
  }) {
    return SizedBox(
      width: 48,
      child: IconButton(
        icon: Icon(icon, color: isNightMode ? MagicTheme.gold : null, size: 22),
        onPressed: onPressed,
        hoverColor:
            isNightMode ? MagicTheme.gold.withValues(alpha: 0.2) : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isNightMode,
  }) {
    return IconButton(
      icon: Icon(icon, color: isNightMode ? MagicTheme.gold : null),
      onPressed: onPressed,
      hoverColor: isNightMode ? MagicTheme.gold.withValues(alpha: 0.2) : null,
    );
  }

  Widget _buildBody(bool isNightMode) {
    final bodyChild = isNightMode
        ? _buildNightBodyWithDecorations()
        : _buildBaseBodyContent();

    return bodyChild;
  }

  Widget _buildNightBodyWithDecorations() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            // 夜间背景渐变
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: const [
                    Color(0xFF2D1B0F),
                    Color(0xFF1A1409),
                    Color(0xFF0F0A05),
                  ],
                ),
              ),
            ),
            // 魔法装饰元素
            _buildMagicDecorations(parentSize),
            // 核心内容
            _buildBaseBodyContent(),
          ],
        );
      },
    );
  }

  Widget _buildBaseBodyContent() {
    return Column(
      children: [
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        const Spacer(flex: 2),
        Expanded(flex: 12, child: _buildBoardArea()),
        const Spacer(flex: 1),
        Expanded(flex: 6, child: _buildInputArea()),
      ],
    );
  }

  Widget _buildMagicDecorations(Size parentSize) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.2,
        child: Stack(
          children: [
            // 大圆形装饰1
            Positioned(
              top: parentSize.height * 0.1,
              left: parentSize.width * 0.1,
              child: _buildMagicCircle(
                diameter: parentSize.width * 0.3,
                opacity: 1.0,
              ),
            ),
            // 大圆形装饰2
            Positioned(
              bottom: parentSize.height * 0.2,
              right: parentSize.width * 0.15,
              child: _buildMagicCircle(
                diameter: parentSize.width * 0.35,
                opacity: 0.6,
              ),
            ),
            // 小圆形装饰（随机分布）
            ...List.generate(5, (index) {
              final random = Random(index);
              return Positioned(
                top: random.nextDouble() * parentSize.height,
                left: random.nextDouble() * parentSize.width,
                child: Container(
                  width: 20 + random.nextDouble() * 50,
                  height: 20 + random.nextDouble() * 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MagicTheme.gold.withValues(
                      alpha: 0.1 + random.nextDouble() * 0.1,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMagicCircle({
    required double diameter,
    required double opacity,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: MagicTheme.gold.withValues(alpha: opacity),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: MagicTheme.gold.withValues(alpha: 0.3 * opacity),
            blurRadius: 15,
          ),
        ],
      ),
    );
  }

  Widget _buildBoardArea() {
    return ValueListenableBuilder<bool>(
      valueListenable: _manager.nightTheme,
      builder: (context, isNightMode, _) {
        return Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: Container(
                decoration: isNightMode
                    ? null
                    : BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                child: isNightMode
                    ? CustomPaint(
                        painter: ParchmentTexture(),
                        child: _buildBoardGrid(),
                      )
                    : _buildBoardGrid(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardGrid() {
    return ValueListenableBuilder<List<CellNotifier>>(
      valueListenable: _manager.cells,
      builder: (context, cells, __) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = _calculateBoardSize(constraints, _manager.boardSize);
            return SizedBox(
              width: size,
              height: size,
              child: GridView.count(
                crossAxisCount: _manager.boardSize,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: List.generate(
                  _manager.boardSize * _manager.boardSize,
                  (index) => CellWidget(
                    cell: cells[index],
                    boardLevel: _manager.boardLevel,
                    onTap: () => _manager.selectCell(index),
                    isNightMode: _manager.nightTheme.value,
                    isGameOver: _manager.isGameOver,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _calculateBoardSize(BoxConstraints constraints, int boardSize) {
    final double maxSize = constraints.maxWidth;
    return (maxSize ~/ boardSize) * boardSize.toDouble();
  }

  Widget _buildInputArea() {
    return ValueListenableBuilder<int>(
      valueListenable: _manager.selectedCellIndex,
      builder: (context, index, _) {
        if (index == -1 || _manager.selectedCell.type == CellType.fixed) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _manager.nightTheme,
          builder: (context, isNightMode, _) {
            return Container(
              padding: const EdgeInsets.all(12),
              // 主题差异：背景色+阴影
              decoration: BoxDecoration(
                color: isNightMode
                    ? Colors.black.withValues(alpha: 0.5)
                    : Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isNightMode
                        ? MagicTheme.parchment.withValues(alpha: 0.8)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: 3,
                    child: NumberCards(
                      cell: _manager.selectedCell,
                      manager: _manager,
                      isNightMode: isNightMode,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: NumberKeyboard(
                      cell: _manager.selectedCell,
                      manager: _manager,
                      isNightMode: isNightMode,
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CellWidget extends StatelessWidget {
  final CellNotifier cell;
  final int boardLevel;
  final VoidCallback onTap;
  final bool isNightMode;
  final ValueNotifier<bool> isGameOver;

  const CellWidget({
    super.key,
    required this.cell,
    required this.boardLevel,
    required this.onTap,
    required this.isNightMode,
    required this.isGameOver,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SudokuCell>(
      valueListenable: cell,
      builder: (_, value, __) => Container(
        decoration: BoxDecoration(
          border: _buildCellBorder(cell.row, cell.col),
          color: _getCellBgColor(cell.row, cell.col),
        ),
        child: InkWell(onTap: onTap, child: _buildCellContent()),
      ),
    );
  }

  /// 构建单元格边框（主题差异：颜色）
  Border _buildCellBorder(int row, int col) {
    final isBlockRight = (col + 1) % boardLevel == 0;
    final isBlockBottom = (row + 1) % boardLevel == 0;

    return Border(
      top: _buildBorderSide(row == 0, false),
      left: _buildBorderSide(col == 0, false),
      right: _buildBorderSide(isBlockRight, true),
      bottom: _buildBorderSide(isBlockBottom, true),
    );
  }

  /// 构建边框样式（主题差异：颜色）
  BorderSide _buildBorderSide(bool isBlockEdge, bool isInner) {
    final borderColor = isNightMode
        ? (isBlockEdge ? MagicTheme.gold : Colors.grey[300]!)
        : (isBlockEdge ? Colors.black : Colors.grey[300]!);

    return BorderSide(color: borderColor, width: isBlockEdge ? 2 : 1);
  }

  /// 获取单元格背景色（主题差异：颜色）
  Color _getCellBgColor(int row, int col) {
    // 提示色优先
    if (cell.hint) {
      return isNightMode ? MagicTheme.hintColor : Colors.blue[50]!;
    }

    // 区块交替色
    final blockRow = row ~/ boardLevel;
    final blockCol = col ~/ boardLevel;
    if (isNightMode) {
      return (blockRow + blockCol) % 2 == 0
          ? MagicTheme.parchment.withValues(alpha: 0.8)
          : MagicTheme.darkParchment.withValues(alpha: 0.8);
    } else {
      return (blockRow + blockCol) % 2 == 0 ? Colors.grey[100]! : Colors.white;
    }
  }

  /// 构建单元格内容（主题差异：文字样式）
  Widget _buildCellContent() {
    return ValueListenableBuilder<bool>(
      valueListenable: isGameOver,
      builder: (_, gameOver, __) {
        // 游戏结束时显示动画
        if (gameOver) {
          return _buildAnimatedCell();
        }

        // 正常状态下的内容
        switch (cell.type) {
          case CellType.fixed:
            return _buildFixedCell();
          case CellType.locked:
            return _buildLockedCell();
          case CellType.editable:
            return _buildEditableCell();
        }
      },
    );
  }

  /// 构建固定单元格（主题差异：文字颜色）
  Widget _buildFixedCell() {
    return Center(
      child: Text(
        cell.fixedDigit.toString(),
        style: isNightMode
            ? MagicTheme.numberStyle.copyWith(color: MagicTheme.fixedNumber)
            : const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
      ),
    );
  }

  /// 构建锁定单元格（主题差异：文字颜色）
  Widget _buildLockedCell() {
    return Center(
      child: Text(
        cell.fixedDigit.toString(),
        style: isNightMode
            ? MagicTheme.numberStyle.copyWith(color: MagicTheme.playerNumber)
            : const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
      ),
    );
  }

  /// 构建可编辑单元格（候选数，无主题差异）
  Widget _buildEditableCell() {
    if (cell.spareDigits.isEmpty) return const SizedBox.shrink();
    final crossAxisCount = cell.spareDigits.length <= 4 ? 2 : 3;
    final fontSize = cell.spareDigits.length <= 4 ? 14.0 : 9.0;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(crossAxisCount * crossAxisCount, (index) {
          if (index < cell.spareDigits.length) {
            return Center(
              child: Text(
                cell.spareDigits[index].toString(),
                style: TextStyle(fontSize: fontSize, color: Colors.blue),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ),
    );
  }

  /// 夜间模式游戏结束动画（仅夜间生效，保留原功能）
  Widget _buildAnimatedCell() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final colors = [
          Colors.purple,
          Colors.blue,
          Colors.cyan,
          Colors.green,
          Colors.yellow,
          Colors.orange,
          Colors.red,
          Colors.pink,
        ];
        final colorProgress = value * colors.length;
        final currentIndex = colorProgress.floor() % colors.length;
        final nextIndex = (currentIndex + 1) % colors.length;
        final transitionRatio = colorProgress - currentIndex;

        final animatedColor = Color.lerp(
          colors[currentIndex],
          colors[nextIndex],
          transitionRatio,
        )!;
        final alphaValue = 0.7 + (sin(value * pi) + 1) * 0.15;
        final shadowBlur = 3 + sin(value * 3) * 4;
        final shadowOffset = Offset(sin(value * 2) * 2, cos(value * 2) * 2);

        return Transform.scale(
          scale: 1 + sin(value * pi * 2) * 0.15,
          child: Center(
            child: Text(
              cell.fixedDigit.toString(),
              style: MagicTheme.numberStyle.copyWith(
                color: animatedColor.withValues(alpha: alphaValue),
                fontSize: 20 + sin(value * pi) * 5 + 5,
                shadows: [
                  Shadow(
                    color: animatedColor.withValues(alpha: 0.5),
                    blurRadius: shadowBlur,
                    offset: shadowOffset,
                  ),
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: shadowBlur / 2,
                    offset: shadowOffset / 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NumberCards extends StatelessWidget {
  final CellNotifier cell;
  final Manager manager;
  final bool isNightMode;

  const NumberCards({
    super.key,
    required this.cell,
    required this.manager,
    required this.isNightMode,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SudokuCell>(
      valueListenable: cell,
      builder: (_, value, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cell.canLock)
                  IconButton(
                    icon: const Icon(Icons.lock_open),
                    onPressed: manager.lockCell,
                  ),
                if (cell.type == CellType.locked)
                  IconButton(
                    icon: const Icon(Icons.lock),
                    onPressed: manager.unlockCell,
                  ),
                ...cell.spareDigits.map(
                  (int num) => _buildNumberChip(context, num),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建数字标签（主题差异：背景色）
  Widget _buildNumberChip(BuildContext context, int number) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => manager.removeDigit(number),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isNightMode
                ? const Color(0xFFD4AF37).withValues(alpha: 0.5) // 夜间金色半透明
                : Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.1), // 白天主题色半透明
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).primaryColor, width: 1),
          ),
          child: Text(
            number.toString(),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

class NumberKeyboard extends StatelessWidget {
  final CellNotifier cell;
  final Manager manager;
  final bool isNightMode;

  const NumberKeyboard({
    super.key,
    required this.cell,
    required this.manager,
    required this.isNightMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildKeyboardButton("CE", manager.clearDigits),
          ...List.generate(
            9,
            (i) => _buildKeyboardButton(
              (i + 1).toString(),
              () => manager.addDigit(i + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isNightMode
            ? const Color(0xFFE8E0C7) // 夜间米黄色
            : BaseTheme.backgroundColor, // 白天白色
        foregroundColor: Colors.black87,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 2,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
