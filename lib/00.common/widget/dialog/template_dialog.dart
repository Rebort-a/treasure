import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../int_slider.dart';

class SliderData {
  double start;
  double end;
  double value;
  double step;

  SliderData({
    required this.start,
    required this.end,
    required this.value,
    required this.step,
  }) {
    value = value.clamp(start, end);
  }

  int get divisions => ((end - start) / step).toInt();
}

class IntSliderData {
  int start;
  int end;
  int value;
  int step;

  IntSliderData({
    required this.start,
    required this.end,
    required this.value,
    required this.step,
  }) {
    value = value.clamp(start, end);
  }

  int get divisions => ((end - start) / step).toInt();
}

class DialogTemplate {
  DialogTemplate._();

  static void promptDialog({
    required BuildContext context,
    required String title,
    required String content,
    required bool Function() before,
    required VoidCallback after,
  }) {
    if (before()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              TextButton(
                child: Text(S.close),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ).then((value) {
        after();
      });
    }
  }

  static void confirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required bool Function() before,
    required VoidCallback onTap,
    required VoidCallback after,
  }) {
    if (before()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onTap();
                },
                child: Text(S.confirm),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(S.cancel),
              ),
            ],
          );
        },
      ).then((value) {
        after();
      });
    }
  }

  static void inputDialog({
    required BuildContext context,
    required String title,
    required String hintText,
    required String confirmButtonText,
    required Function(String input) onConfirm,
  }) {
    String input = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text(title)),
          content: TextField(
            onChanged: (value) {
              input = value;
            },
            decoration: InputDecoration(hintText: hintText),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(confirmButtonText),
              onPressed: () {
                if (input.isNotEmpty) {
                  Navigator.pop(context);
                  onConfirm(input);
                }
              },
            ),
            TextButton(
              child: Text(S.cancel),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  static void optionDialog<T>({
    required BuildContext context,
    required String title,
    required String hintText,
    required String confirmButtonText,
    required List<T> options,
    required Function(String input, T type) onConfirm,
  }) {
    String input = '';
    T selectedOption = options.first; // 默认选择第一个选项

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text(title)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 通用下拉框
              DropdownButtonFormField<T>(
                initialValue: selectedOption,
                onChanged: (T? newValue) {
                  if (newValue != null) {
                    selectedOption = newValue;
                  }
                },
                items: options.map((T option) {
                  return DropdownMenuItem<T>(
                    value: option,
                    child: Text(option.toString().split('.').last),
                  );
                }).toList(),
                decoration: InputDecoration(labelText: S.selectOption),
              ),
              const SizedBox(height: 16),
              // 输入框
              TextField(
                onChanged: (value) {
                  input = value;
                },
                decoration: InputDecoration(hintText: hintText),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(confirmButtonText),
              onPressed: () {
                if (input.isNotEmpty) {
                  Navigator.pop(context);
                  onConfirm(input, selectedOption);
                }
              },
            ),
            TextButton(
              child: Text(S.cancel),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  static void sliderDialog({
    required BuildContext context,
    required String title,
    required SliderData sliderData,
    required Function(double value) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Center(child: Text(title)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.currentValue(sliderData.value.toStringAsFixed(2)),
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // 减号按钮
                  IconButton(
                    onPressed: () {
                      setState(() {
                        sliderData.value = (sliderData.value - sliderData.step)
                            .clamp(sliderData.start, sliderData.end);
                      });
                    },
                    icon: const Icon(Icons.remove_circle),
                  ),

                  // 滑块
                  Expanded(
                    child: Slider(
                      value: sliderData.value,
                      min: sliderData.start,
                      max: sliderData.end,
                      divisions: sliderData.divisions,
                      label: sliderData.value.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          sliderData.value = value;
                        });
                      },
                    ),
                  ),

                  // 加号按钮
                  IconButton(
                    onPressed: () {
                      setState(() {
                        sliderData.value = (sliderData.value + sliderData.step)
                            .clamp(sliderData.start, sliderData.end);
                      });
                    },
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(S.ok),
              onPressed: () {
                onConfirm(sliderData.value);
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text(S.cancel),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  static void intSliderDialog({
    required BuildContext context,
    required String title,
    required IntSliderData sliderData,
    required Function(int value) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Center(child: Text(title)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.currentValue('${sliderData.value}'),
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // 减号按钮
                  IconButton(
                    onPressed: () {
                      setState(() {
                        sliderData.value = (sliderData.value - sliderData.step)
                            .clamp(sliderData.start, sliderData.end);
                      });
                    },
                    icon: const Icon(Icons.remove),
                  ),

                  // 整数滑块
                  Expanded(
                    child: IntSlider(
                      value: sliderData.value,
                      min: sliderData.start,
                      max: sliderData.end,
                      divisions: sliderData.divisions,
                      label: "${sliderData.value}",
                      onChanged: (value) {
                        setState(() {
                          sliderData.value = value;
                        });
                      },
                    ),
                  ),

                  // 加号按钮
                  IconButton(
                    onPressed: () {
                      setState(() {
                        sliderData.value = (sliderData.value + sliderData.step)
                            .clamp(sliderData.start, sliderData.end);
                      });
                    },
                    // icon: const Icon(Icons.add_circle),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(S.ok),
              onPressed: () {
                onConfirm(sliderData.value);
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text(S.cancel),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
