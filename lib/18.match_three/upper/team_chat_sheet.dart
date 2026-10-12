import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../00.common/l10n/strings.dart';
import '../../00.common/network/client/net_multi_turn_engine.dart';
import '../../00.common/widget/component/chat_component.dart';

/// 队内聊天按弹窗的可用空间布局，不依赖整个窗口的高度。
class MatchTeamChatSheet extends StatelessWidget {
  final NetMultiTurnEngine engine;

  const MatchTeamChatSheet({super.key, required this.engine});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final minimumContentHeight = 240.0 * math.max(1.0, textScale);
        final height = math.min(
          availableHeight,
          math.max(availableHeight * 0.6, minimumContentHeight),
        );
        return SizedBox(
          height: height,
          // 极低高度下允许整体滚动，避免标题或输入框挤出布局。
          // 始终保留相同组件结构，键盘弹出或窗口缩放不会丢失输入草稿。
          child: SingleChildScrollView(
            child: SizedBox(
              height: math.max(height, minimumContentHeight),
              child: Column(
                children: [
                  ListTile(
                    title: Text(S.matchTeamChat),
                    trailing: IconButton(
                      tooltip: S.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: MessageList(
                      identity: engine.identity,
                      userName: engine.userName,
                      messageList: engine.gameMessageList,
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: MessageInput(onSendText: engine.sendGameText),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
