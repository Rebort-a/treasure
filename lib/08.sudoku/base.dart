import 'package:flutter/material.dart';

// 定义数独格子状态枚举
enum CellType {
  fixed, // 固定数字，不可更改
  locked, // 已锁定，解锁后可以更改
  editable, // 可更改，可以填入多个数字
}

// 数独格子数据模型（属性全部私有）
class SudokuCell {
  final int _row;
  final int _col;
  CellType _type;
  int _fixedDigit;
  final List<int> _spareDigits = [];
  bool _hint = false;

  SudokuCell({
    required int row,
    required int col,
    required CellType type,
    int fixedDigit = 0,
  }) : _row = row,
       _col = col,
       _type = type,
       _fixedDigit = fixedDigit;
}

// 单元格状态管理类（提供所有操作接口）
class CellNotifier extends ValueNotifier<SudokuCell> {
  CellNotifier(super.value);

  // 提供属性访问接口
  int get row => value._row;
  int get col => value._col;
  CellType get type => value._type;
  int get fixedDigit => value._fixedDigit;
  List<int> get spareDigits => List.unmodifiable(value._spareDigits);
  bool get hint => value._hint;

  bool get canLock =>
      value._type == CellType.editable && value._spareDigits.length == 1;

  set hint(bool arg) {
    if (value._hint != arg) {
      value._hint = arg;
      notifyListeners();
    }
  }

  void addDigit(int digit) {
    if (value._type == CellType.editable && digit >= 1 && digit <= 9) {
      if (!value._spareDigits.contains(digit)) {
        value._spareDigits.add(digit);
        value._spareDigits.sort();
        notifyListeners();
      }
    }
  }

  void removeDigit(int digit) {
    if (value._type == CellType.editable) {
      if (value._spareDigits.contains(digit)) {
        value._spareDigits.remove(digit);
        notifyListeners();
      }
    }
  }

  void clearDigits() {
    if (value._type == CellType.editable) {
      value._spareDigits.clear();
      notifyListeners();
    }
  }

  void lock() {
    if (canLock) {
      value._fixedDigit = value._spareDigits.first;
      value._type = CellType.locked;
      notifyListeners();
    }
  }

  void unlock() {
    if (value._type == CellType.locked) {
      value._fixedDigit = 0;
      value._type = CellType.editable;
      notifyListeners();
    }
  }

  // 新增：设置固定数字（用于初始化）
  void setFixedDigit(int digit) {
    if (value._type == CellType.fixed && digit >= 0 && digit <= 9) {
      value._fixedDigit = digit;
      notifyListeners();
    }
  }
}
