import 'package:flutter/material.dart';

/// 聊天主题
class ChatTheme {
  final Color backgroundColor;
  final Color surfaceColor;
  final Color selfBubbleColor;
  final Color otherBubbleColor;
  final Color selfTextColor;
  final Color otherTextColor;
  final Color systemTextColor;
  final Color timeTextColor;
  final Color inputBackgroundColor;
  final Color inputTextColor;
  final Color inputHintColor;
  final Color dividerColor;
  final Color iconColor;
  final Color sendButtonColor;

  final double messagePadding = 12.0;
  final double bubbleRadius = 18.0;
  final double avatarSize = 36.0;

  static const light = ChatTheme._();

  const ChatTheme._()
      : backgroundColor = const Color(0xFFF0F2F5),
        surfaceColor = const Color(0xFFFFFFFF),
        selfBubbleColor = const Color(0xFF95EC69),
        otherBubbleColor = const Color(0xFFFFFFFF),
        selfTextColor = const Color(0xFF1A1A1A),
        otherTextColor = const Color(0xFF1A1A1A),
        systemTextColor = const Color(0xFF999999),
        timeTextColor = const Color(0xFF999999),
        inputBackgroundColor = const Color(0xFFF7F7F7),
        inputTextColor = const Color(0xFF1A1A1A),
        inputHintColor = const Color(0xFFB0B0B0),
        dividerColor = const Color(0xFFE8E8E8),
        iconColor = const Color(0xFF7A7A7A),
        sendButtonColor = const Color(0xFF07C160);

  TextStyle get selfTextStyle =>
      TextStyle(color: selfTextColor, fontSize: 16, height: 1.4);
  TextStyle get otherTextStyle =>
      TextStyle(color: otherTextColor, fontSize: 16, height: 1.4);
  TextStyle get systemTextStyle =>
      TextStyle(color: systemTextColor, fontSize: 12, height: 1.2);
  TextStyle get timeTextStyle =>
      TextStyle(color: timeTextColor, fontSize: 11, height: 1.2);
  TextStyle get usernameStyle => TextStyle(
        color: otherTextColor.withAlpha(150),
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
      );
  TextStyle get inputTextStyle =>
      TextStyle(color: inputTextColor, fontSize: 16, height: 1.4);
  TextStyle get inputHintStyle =>
      TextStyle(color: inputHintColor, fontSize: 16, height: 1.4);
  TextStyle get dateSeparatorStyle => TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      );

  BoxDecoration get selfBubbleDecoration => BoxDecoration(
        color: selfBubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(bubbleRadius),
          topRight: const Radius.circular(4),
          bottomLeft: Radius.circular(bubbleRadius),
          bottomRight: Radius.circular(bubbleRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );

  BoxDecoration get otherBubbleDecoration => BoxDecoration(
        color: otherBubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(4),
          topRight: Radius.circular(bubbleRadius),
          bottomLeft: Radius.circular(bubbleRadius),
          bottomRight: Radius.circular(bubbleRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );

  BoxDecoration get inputDecoration => BoxDecoration(
        color: inputBackgroundColor,
        borderRadius: BorderRadius.circular(22),
      );

  static Color getAvatarColor(String name) {
    const colors = [
      Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFF9C27B0),
      Color(0xFFE91E63), Color(0xFF00BCD4), Color(0xFF795548), Color(0xFF607D8B),
    ];
    int hash = 0;
    for (var rune in name.runes) {
      hash = (hash * 31 + rune) & 0xFFFFFFFF;
    }
    return colors[hash.abs() % colors.length];
  }
}
