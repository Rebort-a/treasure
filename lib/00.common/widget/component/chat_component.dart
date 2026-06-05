import 'package:flutter/material.dart';

import '../../../l10n/strings.dart';
import '../../engine/network_engine.dart';
import '../../network/network_message.dart';

class MessageList extends StatelessWidget {
  final NetworkEngine networkEngine;

  const MessageList({super.key, required this.networkEngine});

  @override
  Widget build(BuildContext context) {
    return _buildMessageList();
  }

  Widget _buildMessageList() {
    return ValueListenableBuilder<List<NetworkMessage>>(
      valueListenable: networkEngine.messageList,
      builder: (context, value, child) {
        return ListView.builder(
          controller: networkEngine.scrollController,
          itemCount: value.length,
          itemBuilder: (context, index) {
            return _buildMessageCard(value[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageCard(NetworkMessage message) {
    bool isCurrentUser =
        (message.id == networkEngine.identity) &&
        (message.source == networkEngine.userName);
    bool isNotify = message.type == MessageType.notify;

    AlignmentGeometry alignment = isNotify
        ? Alignment.center
        : isCurrentUser
        ? Alignment.centerRight
        : Alignment.centerLeft;

    Color backgroundColor = isNotify
        ? Colors.transparent
        : isCurrentUser
        ? Colors.blue
        : Colors.blueGrey;

    Color foregroundColor = isNotify
        ? Colors.brown
        : isCurrentUser
        ? Colors.white
        : Colors.white;

    String displayText = isNotify
        ? '${message.source} ${message.content}'
        : isCurrentUser
        ? message.content
        : '${message.source} : ${message.content}';

    IconData? iconData;
    double elevation = isNotify ? 0.0 : 4.0;

    switch (message.type) {
      case MessageType.notify:
        iconData = Icons.notifications;
        break;
      case MessageType.text:
        iconData = null;
        break;
      case MessageType.image:
        iconData = Icons.image;
        break;
      case MessageType.file:
        iconData = Icons.insert_drive_file;
        break;
      default:
        break;
    }

    return Align(
      alignment: alignment,
      child: Card(
        elevation: elevation,
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconData != null)
                Icon(iconData, color: foregroundColor, size: 20.0),
              const SizedBox(width: 8.0),
              Flexible(
                child: Text(
                  displayText,
                  style: TextStyle(color: foregroundColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageInput extends StatelessWidget {
  final NetworkEngine networkEngine;

  const MessageInput({super.key, required this.networkEngine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25.0),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.attachment),
            onPressed: () {}, // Placeholder for file attachment
          ),
          Expanded(
            child: TextField(
              controller: networkEngine.textController,
              decoration: InputDecoration.collapsed(
                hintText: S.typeMessage,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: networkEngine.sendInputText,
          ),
        ],
      ),
    );
  }
}
