import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';

/// 创建房间前选择固定房间类型的底部弹出列表。
class RoomTypePicker {
  RoomTypePicker._();

  static Future<T?> show<T>({
    required BuildContext context,
    required List<T> options,
    required String Function(T) titleOf,
    required bool Function(T) isChat,
  }) => showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(S.game)),
          for (final type in options)
            ListTile(
              leading: Icon(
                isChat(type) ? Icons.forum_outlined : Icons.gamepad,
              ),
              title: Text(titleOf(type)),
              onTap: () => Navigator.pop(sheetContext, type),
            ),
        ],
      ),
    ),
  );
}
