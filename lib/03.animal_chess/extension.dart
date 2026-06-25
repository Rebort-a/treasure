import 'package:flutter/material.dart';

import 'base.dart';

class CellNotifier extends ValueNotifier<Cell> {
  CellNotifier(super.value);

  void clearAnimal() {
    value.animal = null;
    notifyListeners();
  }

  void revealAnimal() {
    value.animal?.isHidden = false;
    notifyListeners();
  }

  void toggleState(CellState state) {
    switch (state) {
      case CellState.normal:
        value.setNormal();
      case CellState.highlight:
        value.setHighlight();
      case CellState.selected:
        value.setSelected();
    }
    notifyListeners();
  }

  void placeAnimal(Animal animal) {
    value.animal = animal;
    notifyListeners();
  }
}
