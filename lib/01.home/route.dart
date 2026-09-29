import 'package:flutter/material.dart';

import '../00.common/network/engine/network_engine.dart';
import '../00.common/network/network_room.dart';
import '../02.lan_chat/net_page.dart';
import '../03.animal_chess/local_page.dart';
import '../03.animal_chess/net_page.dart';
import '../04.elemental_battle/upper/maze_page.dart';
import '../04.elemental_battle/upper/net_page.dart';
import '../05.gobang/local_page.dart';
import '../05.gobang/net_page.dart';
import '../06.greedy_snake/local_page.dart';
import '../06.greedy_snake/net_page.dart';
import '../07.weiqi/local_page.dart';
import '../07.weiqi/net_page.dart';
import '../08.sudoku/page.dart';
import '../09.guess/page.dart';
import '../10.three_tiles/page.dart';
import '../11.spaceship/page.dart';
import '../12.soft/page.dart';
import '../13.minecraft/upper/page.dart';
import '../14.tower_defense/page.dart';
import '../15.memory_card/page.dart';
import '../16.schulte/page.dart';
import '../17.tank/local_page.dart';
import '../17.tank/net_page.dart';

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

enum OnlineItemType {
  onlyChat,
  animalChess,
  elementalBattle,
  gobang,
  greedySnake,
  weiqi,
  tank,
}

extension OnlineItemTypeExt on OnlineItemType {
  String get name => toString().split('.').last;
}

extension AppItemTypeExtension on AppItemType {
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

  Widget get page {
    switch (this) {
      case AppItemType.animalChess:
        return LocalAnimalChessPage();
      case AppItemType.elementalBattle:
        return MazePage();
      case AppItemType.gobang:
        return LocalGomokuPage();
      case AppItemType.greedySnake:
        return LocalGreedySnakePage();
      case AppItemType.weiqi:
        return GoLocalPage();
      case AppItemType.sudoku:
        return SudokuPage();
      case AppItemType.guess:
        return GuessPage();
      case AppItemType.threeTiles:
        return ThreeTilesPage();
      case AppItemType.spaceship:
        return SpaceShipPage();
      case AppItemType.soft:
        return SoftPage();
      case AppItemType.minecraft:
        return MinecraftPage();
      case AppItemType.towerDefense:
        return TowerDefensePage();
      case AppItemType.memoryCard:
        return MemoryPage();
      case AppItemType.schulte:
        return SchultePage();
      case AppItemType.tank:
        return LocalTankPage();
    }
  }
}

extension OnlineItemTypeExtension on OnlineItemType {
  RoomGameMode get gameMode => switch (this) {
    OnlineItemType.onlyChat => RoomGameMode.none,
    OnlineItemType.greedySnake || OnlineItemType.tank => RoomGameMode.real,
    _ => RoomGameMode.turn,
  };

  Widget createGame(NetworkEngine room) => switch (this) {
    OnlineItemType.animalChess => NetAnimalChessPage(room: room),
    OnlineItemType.elementalBattle => NetCombatPage(room: room),
    OnlineItemType.gobang => NetGomokuPage(room: room),
    OnlineItemType.greedySnake => NetGreedySnakePage(room: room),
    OnlineItemType.weiqi => GoNetPage(room: room),
    OnlineItemType.tank => NetTankPage(room: room),
    OnlineItemType.onlyChat => NetChatPage(room: room),
  };
}

class RouteManager {
  /// 应用入口只选择模块的公开入口，具体管理器由模块内部装配。
  static Widget? createRoomGame(NetworkEngine room) {
    final type = room.roomType;
    if (type <= 0 || type >= OnlineItemType.values.length) return null;
    if (OnlineItemType.values[type].gameMode != room.gameMode) return null;
    return OnlineItemType.values[type].createGame(room);
  }

  /// 导航到本地页面
  static void navigateToLocalPage(BuildContext context, AppItemType routeType) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => routeType.page));
  }

  /// 导航到网络页面
  static Future<void> navigateToNetPage(
    BuildContext context,
    NetworkEngine room,
  ) async {
    if (!room.isJoined) {
      throw StateError('Room authentication has not completed');
    }
    final type = room.roomType;
    final page =
        type >= 0 &&
            type < OnlineItemType.values.length &&
            OnlineItemType.values[type].gameMode == room.gameMode
        ? OnlineItemType.values[type].createGame(room)
        : NetChatPage(room: room);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
