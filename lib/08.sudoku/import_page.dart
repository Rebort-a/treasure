import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import '../00.common/style/theme.dart';
import 'algorithm.dart';

class SudokuImportPage extends StatefulWidget {
  const SudokuImportPage({super.key});

  @override
  State<SudokuImportPage> createState() => _SudokuImportPageState();
}

class _SudokuImportPageState extends State<SudokuImportPage> {
  static const int _size = 9;
  static const int _level = 3;

  late List<List<int>> _grid;
  int? _selRow;
  int? _selCol;
  final Set<int> _conflictCells = {};

  @override
  void initState() {
    super.initState();
    _grid = List.generate(_size, (_) => List.filled(_size, 0));
  }

  void _selectCell(int row, int col) {
    setState(() {
      _grid[row][col] = 0;
      _selRow = row;
      _selCol = col;
      _conflictCells.clear();
    });
  }

  void _inputDigit(int digit) {
    if (_selRow == null || _selCol == null) return;
    setState(() {
      _grid[_selRow!][_selCol!] = digit;
      _conflictCells.clear();
    });
  }

  bool _validate() {
    _conflictCells.clear();
    bool anyFilled = false;

    for (int r = 0; r < _size; r++) {
      for (int c = 0; c < _size; c++) {
        final val = _grid[r][c];
        if (val == 0) continue;
        anyFilled = true;

        for (int k = 0; k < _size; k++) {
          if (k != c && _grid[r][k] == val) {
            _conflictCells.add(r * _size + c);
            _conflictCells.add(r * _size + k);
          }
          if (k != r && _grid[k][c] == val) {
            _conflictCells.add(r * _size + c);
            _conflictCells.add(k * _size + c);
          }
        }

        final br = (r ~/ _level) * _level;
        final bc = (c ~/ _level) * _level;
        for (int dr = 0; dr < _level; dr++) {
          for (int dc = 0; dc < _level; dc++) {
            final nr = br + dr;
            final nc = bc + dc;
            if (nr == r && nc == c) continue;
            if (_grid[nr][nc] == val) {
              _conflictCells.add(r * _size + c);
              _conflictCells.add(nr * _size + nc);
            }
          }
        }
      }
    }

    if (!anyFilled) return false;
    return _conflictCells.isEmpty;
  }

  void _confirm() {
    if (!_validate()) {
      setState(() {});
      final msg = _conflictCells.isNotEmpty
          ? S.importFailConflict
          : S.importFailEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final solver = BacktrackingSolver(level: _level);
    if (!solver.isUniqueSolution(_grid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.importFailNotUnique),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.pop(context, _grid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.importPuzzle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Spacer(flex: 1),
          Expanded(flex: 12, child: _buildBoard()),
          const Spacer(flex: 1),
          Expanded(flex: 7, child: _buildControls()),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: GridView.count(
            crossAxisCount: _size,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: List.generate(_size * _size, (index) {
              final r = index ~/ _size;
              final c = index % _size;
              return _ImportCell(
                value: _grid[r][c],
                isSelected: _selRow == r && _selCol == c,
                isConflict: _conflictCells.contains(index),
                row: r,
                col: c,
                level: _level,
                onTap: () => _selectCell(r, c),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final hasSelection = _selRow != null && _selCol != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(
                9,
                (i) => _NumberButton(
                  digit: i + 1,
                  enabled: hasSelection,
                  onPressed: () => _inputDigit(i + 1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  label: S.cancelImport,
                  icon: Icons.close,
                  onPressed: () => Navigator.pop(context),
                ),
                _ControlButton(
                  label: S.confirmImport,
                  icon: Icons.check,
                  isConfirm: true,
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportCell extends StatelessWidget {
  final int value;
  final bool isSelected;
  final bool isConflict;
  final int row;
  final int col;
  final int level;
  final VoidCallback onTap;

  const _ImportCell({
    required this.value,
    required this.isSelected,
    required this.isConflict,
    required this.row,
    required this.col,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBlockRight = (col + 1) % level == 0;
    final isBlockBottom = (row + 1) % level == 0;

    Color bg;
    if (isConflict) {
      bg = Colors.red.shade100;
    } else if (isSelected) {
      bg = Colors.blue.shade50;
    } else if (value != 0) {
      bg = Colors.grey.shade200;
    } else {
      final blockRow = row ~/ level;
      final blockCol = col ~/ level;
      bg = (blockRow + blockCol) % 2 == 0 ? Colors.grey.shade100 : Colors.white;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: row == 0 ? Colors.black : Colors.grey.shade300,
            width: row == 0 ? 2 : 1,
          ),
          left: BorderSide(
            color: col == 0 ? Colors.black : Colors.grey.shade300,
            width: col == 0 ? 2 : 1,
          ),
          right: BorderSide(
            color: isBlockRight ? Colors.black : Colors.grey.shade300,
            width: isBlockRight ? 2 : 1,
          ),
          bottom: BorderSide(
            color: isBlockBottom ? Colors.black : Colors.grey.shade300,
            width: isBlockBottom ? 2 : 1,
          ),
        ),
        color: bg,
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: value == 0
              ? const SizedBox.shrink()
              : Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isConflict ? Colors.red : Colors.black,
                  ),
                ),
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final int digit;
  final bool enabled;
  final VoidCallback onPressed;

  const _NumberButton({
    required this.digit,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: BaseTheme.backgroundColor,
        foregroundColor: Colors.black87,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 2,
      ),
      onPressed: enabled ? onPressed : null,
      child: Text(
        digit.toString(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isConfirm;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isConfirm = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isConfirm ? Colors.green : null,
        foregroundColor: isConfirm ? Colors.white : null,
        minimumSize: const Size(60, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isConfirm
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300),
        ),
        elevation: 2,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onPressed,
    );
  }
}
