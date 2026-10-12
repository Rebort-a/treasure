import '../../00.common/network/protocol/network_room.dart';
import '../../00.common/network/server/socket_server.dart';

class CreatedRoomInfo extends RoomInfo {
  final SocketServer server;

  CreatedRoomInfo({
    required super.name,
    required super.type,
    required super.port,
    required this.server,
    required super.encryptionKey,
    super.hasPassword,
    super.password,
  }) : super(address: 'localhost');
}
