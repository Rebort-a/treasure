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
  final List<VoidCallback> _callBacks = [];

  ListNotifier(super.value);

  @override
  List<T> get value => List.unmodifiable(super.value);

  void add(T value) {
    super.value.add(value);
    notifyAll();
  }

  void addAll(Iterable<T> iterable) {
    super.value.addAll(iterable);
    notifyAll();
  }

  void remove(T value) {
    super.value.remove(value);
    notifyAll();
  }

  T removeLast() {
    final removed = super.value.removeLast();
    notifyAll();
    return removed;
  }

  T removeAt(int index) {
    final removed = super.value.removeAt(index);
    notifyAll();
    return removed;
  }

  void removeWhere(bool Function(T) check) {
    super.value.removeWhere(check);
    notifyAll();
  }

  void clear() {
    if (isNotEmpty) {
      super.value.clear();
      notifyAll();
    }
  }

  T operator [](int index) {
    return super.value[index];
  }

  void operator []=(int index, T value) {
    super.value[index] = value;
    notifyAll();
  }

  @override
  Iterator<T> get iterator => super.value.iterator;

  void addCallBack(VoidCallback callBack) {
    _callBacks.add(callBack);
  }

  void removeCallBack(VoidCallback callBack) {
    _callBacks.remove(callBack);
  }

  void notifyAll() {
    super.notifyListeners();
    for (VoidCallback callBack in _callBacks) {
      callBack();
    }
  }
}
