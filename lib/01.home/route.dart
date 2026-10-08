import 'package:flutter/material.dart';

import '../00.common/model/app_item_type.dart';
import '../00.common/network/client/socket_client.dart';
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

export '../00.common/model/app_item_type.dart';

extension AppItemTypeRoute on AppItemType {
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

extension _OnlineGamePages on OnlineItemType {
  Widget createGamePage(SocketClient room) => switch (this) {
    OnlineItemType.animalChess => NetAnimalChessPage(room: room),
    OnlineItemType.elementalBattle => NetCombatPage(room: room),
    OnlineItemType.gobang => NetGomokuPage(room: room),
    OnlineItemType.greedySnake => NetGreedySnakePage(room: room),
    OnlineItemType.weiqi => GoNetPage(room: room),
    OnlineItemType.tank => NetTankPage(room: room),
    OnlineItemType.onlyChat => throw StateError('Chat rooms have no game page'),
  };
}

class RouteManager {
  /// 所有房间统一进入聊天室。首页只注入具体游戏入口，不提前创建游戏 Manager。
  static NetChatPage createRoomPage(SocketClient room) {
    final type = OnlineItemType.tryFromRoomType(room.roomType);
    if (type == null || type == OnlineItemType.onlyChat) {
      return NetChatPage(room: room);
    }
    return NetChatPage(
      room: room,
      gameName: type.name,
      gamePageBuilder: (_) => type.createGamePage(room),
    );
  }

  /// 导航到本地页面
  static void navigateToLocalPage(BuildContext context, AppItemType routeType) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => routeType.page));
  }

  /// 导航到网络页面
  static Future<void> navigateToNetPage(
    BuildContext context,
    SocketClient room,
  ) async {
    if (!room.isJoined) {
      throw StateError('Room authentication has not completed');
    }
    final page = createRoomPage(room);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
