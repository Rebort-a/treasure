import 'package:flutter/material.dart';

import '../game/step.dart';

/// 联机游戏等待/准备阶段的通用 UI
///
/// 显示一个居中的加载动画和当前阶段说明文字。
/// 用于所有联机游戏页面中 [GameStep.action] 之前的阶段。
class NetPrepareWidget extends StatelessWidget {
  final GameStep step;

  const NetPrepareWidget({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          step.getExplanation(),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
