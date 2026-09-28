import 'dart:convert';

/// 仅维护房间元数据；游戏不独占网络连接，也不在服务器端预留席位。
class RoomSession {
  final int game;
  final Map<int, String> members;

  const RoomSession({this.game = 0, this.members = const {}});

  int get count => members.length;
  String get gameName => switch (game) {
    1 => 'animalChess',
    2 => 'elementalBattle',
    3 => 'gobang',
    4 => 'greedySnake',
    5 => 'weiqi',
    6 => 'tank',
    _ => '',
  };

  factory RoomSession.fromJson(String content) {
    final data = jsonDecode(content) as Map<String, dynamic>;
    final raw = data['members'] as Map<String, dynamic>? ?? {};
    return RoomSession(
      game: (data['game'] as num?)?.toInt() ?? 0,
      members: raw.map(
        (key, value) => MapEntry(int.parse(key), value as String),
      ),
    );
  }

  String toJson() => jsonEncode({
    'game': game,
    'members': members.map((id, name) => MapEntry('$id', name)),
  });
}
