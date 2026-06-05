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

  void toggleSelection(bool selected) {
    value.animal?.isSelected = selected;
    notifyListeners();
  }

  void toggleHighlight(bool highlighted) {
    value.isHighlighted = highlighted;
    notifyListeners();
  }

  void placeAnimal(Animal animal) {
    value.animal = animal;
    notifyListeners();
  }
}
