import '../network/protocol/network_room.dart';

/// 首页可展示的应用类型。
enum AppItemType {
  animalChess,
  elementalBattle,
  gobang,
  greedySnake,
  weiqi,
  sudoku,
  guess,
  threeTiles,
  spaceship,
  soft,
  minecraft,
  towerDefense,
  memoryCard,
  schulte,
  tank,
}

/// 可创建局域网房间的类型；枚举顺序对应 roomType 整数编码。
enum OnlineItemType {
  onlyChat,
  animalChess,
  elementalBattle,
  gobang,
  greedySnake,
  weiqi,
  tank;

  static OnlineItemType? tryFromRoomType(int roomType) {
    if (roomType < 0 || roomType >= values.length) return null;
    return values[roomType];
  }
}

extension AppItemTypeOnlineType on AppItemType {
  OnlineItemType? get onlineType => switch (this) {
    AppItemType.animalChess => OnlineItemType.animalChess,
    AppItemType.elementalBattle => OnlineItemType.elementalBattle,
    AppItemType.gobang => OnlineItemType.gobang,
    AppItemType.greedySnake => OnlineItemType.greedySnake,
    AppItemType.weiqi => OnlineItemType.weiqi,
    AppItemType.tank => OnlineItemType.tank,
    AppItemType.sudoku ||
    AppItemType.guess ||
    AppItemType.threeTiles ||
    AppItemType.spaceship ||
    AppItemType.soft ||
    AppItemType.minecraft ||
    AppItemType.towerDefense ||
    AppItemType.memoryCard ||
    AppItemType.schulte => null,
  };
}

extension OnlineItemTypeMetadata on OnlineItemType {
  RoomGameMode get gameMode => switch (this) {
    OnlineItemType.onlyChat => RoomGameMode.none,
    OnlineItemType.greedySnake || OnlineItemType.tank => RoomGameMode.real,
    _ => RoomGameMode.turn,
  };

  int? get maxGamePlayers => this == OnlineItemType.tank ? 4 : null;
}
