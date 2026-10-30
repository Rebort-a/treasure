import 'dart:collection';

import 'package:flutter/foundation.dart';

class AlwaysNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  AlwaysNotifier(this._value) {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  @override
  T get value => _value;
  T _value;
  set value(T newValue) {
    _value = newValue;
    notifyListeners();
  }
}

class ListNotifier<T> extends ValueNotifier<List<T>> with IterableMixin<T> {
  ListNotifier(super.value);

  @override
  List<T> get value => UnmodifiableListView(super.value);

  void add(T value) {
    super.value.add(value);
    notifyListeners();
  }

  void addAll(Iterable<T> iterable) {
    super.value.addAll(iterable);
    notifyListeners();
  }

  void remove(T value) {
    super.value.remove(value);
    notifyListeners();
  }

  T removeLast() {
    final removed = super.value.removeLast();
    notifyListeners();
    return removed;
  }

  T removeAt(int index) {
    final removed = super.value.removeAt(index);
    notifyListeners();
    return removed;
  }

  void removeWhere(bool Function(T) check) {
    super.value.removeWhere(check);
    notifyListeners();
  }

  void clear() {
    if (isNotEmpty) {
      super.value.clear();
      notifyListeners();
    }
  }

  T operator [](int index) {
    return super.value[index];
  }

  void operator []=(int index, T value) {
    super.value[index] = value;
    notifyListeners();
  }

  @override
  Iterator<T> get iterator => super.value.iterator;
}
