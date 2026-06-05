import 'package:flutter/material.dart';

import '../00.common/network/network_room.dart';
import '../02.lan_chat/net_page.dart';
import '../03.animal_chess/local_page.dart';
import '../03.animal_chess/net_page.dart';
import '../04.elemental_battle/upper/maze_page.dart';
import '../04.elemental_battle/upper/net_combat_page.dart';
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

enum LocalItemType {
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
}

enum NetItemType {
  onlyChat,
  animalChess,
  elementalBattle,
  gobang,
  greedySnake,
  weiqi,
}

extension LocalItemTypeExtension on LocalItemType {
  Widget get page {
    switch (this) {
      case LocalItemType.animalChess:
        return LocalAnimalChessPage();
      case LocalItemType.elementalBattle:
        return MazePage();
      case LocalItemType.gobang:
        return LocalGomokuPage();
      case LocalItemType.greedySnake:
        return LocalGreedySnakePage();
      case LocalItemType.weiqi:
        return GoLocalPage();
      case LocalItemType.sudoku:
        return SudokuPage();
      case LocalItemType.guess:
        return GuessPage();
      case LocalItemType.threeTiles:
        return ThreeTilesPage();
      case LocalItemType.spaceship:
        return SpaceShipPage();
      case LocalItemType.soft:
        return SoftPage();
      case LocalItemType.minecraft:
        return MinecraftPage();
    }
  }
}

extension NetItemTypeExtension on NetItemType {
  Widget page(String userName, RoomInfo roomInfo) {
    switch (this) {
      case NetItemType.onlyChat:
        return NetChatPage(userName: userName, roomInfo: roomInfo);
      case NetItemType.animalChess:
        return NetAnimalChessPage(userName: userName, roomInfo: roomInfo);
      case NetItemType.elementalBattle:
        return NetCombatPage(userName: userName, roomInfo: roomInfo);
      case NetItemType.gobang:
        return NetGomokuPage(userName: userName, roomInfo: roomInfo);
      case NetItemType.greedySnake:
        return NetGreedySnakePage(userName: userName, roomInfo: roomInfo);
      case NetItemType.weiqi:
        return GoNetPage(userName: userName, roomInfo: roomInfo);
    }
  }
}

class RouteManager {
  /// 导航到本地页面
  static void navigateToLocalPage(
    BuildContext context,
    LocalItemType routeType,
  ) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => routeType.page));
  }

  /// 导航到网络页面
  static void navigateToNetPage(
    BuildContext context,
    String userName,
    RoomInfo roomInfo,
  ) {
    if (roomInfo.type < 0 || roomInfo.type >= NetItemType.values.length) {
      debugPrint('Invalid page type index: ${roomInfo.type}');
      return;
    }

    final netType = NetItemType.values[roomInfo.type];
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => netType.page(userName, roomInfo)));
  }
}
