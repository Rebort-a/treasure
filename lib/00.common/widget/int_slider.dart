import 'package:flutter/material.dart';

class IntSlider extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final int? divisions;
  final String? label;
  final ValueChanged<int>? onChangeStart;
  final ValueChanged<int>? onChangeEnd;

  const IntSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
    this.onChangeStart,
    this.onChangeEnd,
  }) : assert(value >= min),
       assert(value <= max),
       assert(min <= max);

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: divisions,
      label: label ?? value.toString(),
      onChanged: (double newValue) {
        onChanged(newValue.round());
      },
      onChangeStart: (double startValue) {
        if (onChangeStart != null) {
          onChangeStart!(startValue.round());
        }
      },
      onChangeEnd: (double endValue) {
        if (onChangeEnd != null) {
          onChangeEnd!(endValue.round());
        }
      },
    );
  }
}
