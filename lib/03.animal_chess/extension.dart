import 'package:flutter/material.dart';

import 'base.dart';

class GridNotifier extends ValueNotifier<Grid> {
  GridNotifier(super.value);

  void clearAnimal() {
    value.animal = null;
    notifyListeners();
  }

  void revealAnimal() {
    value.animal?.isHidden = false;
    notifyListeners();
  }

  void toggleState(GridState state) {
    switch (state) {
      case GridState.normal:
        value.setNormal();
      case GridState.highlight:
        value.setHighlight();
      case GridState.selected:
        value.setSelected();
    }
    notifyListeners();
  }

  void placeAnimal(Animal animal) {
    value.animal = animal;
    notifyListeners();
  }
}
