import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../00.common/config/network_config.dart';
import '../../../00.common/l10n/strings.dart';
import '../../../00.common/model/app_item_type.dart';
import '../../../00.common/network/protocol/network_room.dart';
import '../home_manager.dart';
import '../widgets/home_heading.dart';

class HomeOnlinePage extends StatelessWidget {
  final HomeManager manager;

  const HomeOnlinePage({super.key, required this.manager});

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      16 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!kIsWeb)
            FilledButton.icon(
              onPressed: manager.showCreateRoomDialog,
              icon: const Icon(Icons.add_home_outlined),
              label: Text(S.createRoom),
            ),
          if (!kIsWeb || networkMode == NetworkMode.webSocket)
            OutlinedButton.icon(
              onPressed: manager.showJoinByIpDialog,
              icon: const Icon(Icons.add_link),
              label: Text(S.joinByIp),
            ),
        ],
      ),
      ValueListenableBuilder<List<CreatedRoomInfo>>(
        valueListenable: manager.createdRooms,
        builder: (_, rooms, __) => Column(
          children: [
            HomeHeading(
              S.createdRooms,
              trailing: rooms.length > 1
                  ? TextButton(
                      onPressed: manager.stopAllCreatedRooms,
                      child: Text(S.stopAll),
                    )
                  : null,
            ),
            if (rooms.isEmpty) ListTile(title: Text(S.noRooms)),
            for (var index = 0; index < rooms.length; index++)
              _roomCard(
                rooms[index],
                onStop: () => manager.stopCreatedRoom(index),
              ),
          ],
        ),
      ),
      ValueListenableBuilder<List<RoomInfo>>(
        valueListenable: manager.othersRooms,
        builder: (_, rooms, __) => Column(
          children: [
            HomeHeading(S.otherRooms),
            if (rooms.isEmpty) ListTile(title: Text(S.noRooms)),
            ...rooms.map((room) => _roomCard(room)),
          ],
        ),
      ),
    ],
  );

  Widget _roomCard(RoomInfo room, {VoidCallback? onStop}) {
    final type = room is CreatedRoomInfo ? room.server.roomType : room.type;
    final count = room is CreatedRoomInfo
        ? room.server.members.length
        : room.count;
    final onlineType = OnlineItemType.tryFromRoomType(type);
    final isGame = onlineType != null && onlineType != OnlineItemType.onlyChat;
    return Card(
      child: ListTile(
        leading: Icon(isGame ? Icons.gamepad : Icons.forum_outlined),
        title: Text(
          '[${S.roomTypeString((onlineType ?? OnlineItemType.onlyChat).name)}] ${room.name} ($count)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${room.address}:${room.port}'),
        onTap: () => manager.showJoinRoomDialog(room),
        trailing: onStop == null && !room.hasPassword
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (room.hasPassword)
                    const Icon(Icons.lock_outline, size: 20),
                  if (room.hasPassword && onStop != null)
                    const SizedBox(width: 4),
                  if (onStop != null)
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined),
                      tooltip: S.stop,
                      onPressed: onStop,
                    ),
                ],
              ),
      ),
    );
  }
}
