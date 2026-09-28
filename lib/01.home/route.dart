import '../00.common/engine/network_engine.dart';
import '../00.common/widget/navigator/game_launch.dart';
import '../03.animal_chess/net_manager.dart' as animal;
import '../04.elemental_battle/upper/net_combat_manager.dart' as elemental;
import '../05.gobang/net_manager.dart' as gobang;
import '../06.greedy_snake/net_manager.dart' as snake;
import '../07.weiqi/net_manager.dart' as go;
import '../17.tank/net_manager.dart' as tank;

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
import '../14.tower_defense/page.dart';
import '../15.memory_card/page.dart';
import '../16.schulte/page.dart';
import '../17.tank/local_page.dart';
import '../17.tank/net_page.dart';

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
  towerDefense,
  memoryCard,
  schulte,
  tank,
}

enum NetItemType {
  onlyChat,
  animalChess,
  elementalBattle,
  gobang,
  greedySnake,
  weiqi,
  tank,
}

extension NetItemTypeExt on NetItemType {
  String get name => toString().split('.').last;
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
      case LocalItemType.towerDefense:
        return TowerDefensePage();
      case LocalItemType.memoryCard:
        return MemoryPage();
      case LocalItemType.schulte:
        return SchultePage();
      case LocalItemType.tank:
        return LocalTankPage();
    }
  }
}

extension NetItemTypeExtension on NetItemType {
  GameLaunch createGame(NetworkEngine room) {
    switch (this) {
      case NetItemType.onlyChat:
        throw StateError('Chat-only rooms do not create games');
      case NetItemType.animalChess:
        final manager = animal.NetManager(room: room);
        return GameLaunch(
          manager.netTurnEngine,
          () => NetAnimalChessPage(manager: manager),
          manager.netTurnEngine.dispose,
        );
      case NetItemType.elementalBattle:
        final manager = elemental.NetCombatManager(room: room);
        return GameLaunch(
          manager.netTurnEngine,
          () => NetCombatPage(manager: manager),
          manager.netTurnEngine.dispose,
        );
      case NetItemType.gobang:
        final manager = gobang.NetManager(room: room);
        return GameLaunch(
          manager.netTurnEngine,
          () => NetGomokuPage(manager: manager),
          manager.netTurnEngine.dispose,
        );
      case NetItemType.greedySnake:
        final manager = snake.NetManager(room: room);
        return GameLaunch(
          manager.engine,
          () => NetGreedySnakePage(manager: manager),
          manager.dispose,
        );
      case NetItemType.weiqi:
        final manager = go.GoNetManager(room: room);
        return GameLaunch(
          manager.netTurnEngine,
          () => GoNetPage(manager: manager),
          manager.netTurnEngine.dispose,
        );
      case NetItemType.tank:
        final manager = tank.NetTankManager(room: room);
        return GameLaunch(
          manager.engine,
          () => NetTankPage(manager: manager),
          manager.dispose,
        );
    }
  }
}

class RouteManager {
  /// 具体游戏的装配留在应用入口，聊天室只接收可调用的工厂。
  static GameLaunch? createRoomGame(NetworkEngine room) {
    final type = room.roomSession.value.game;
    if (type <= 0 || type >= NetItemType.values.length) return null;
    return NetItemType.values[type].createGame(room);
  }

  /// 导航到本地页面
  static void navigateToLocalPage(
    BuildContext context,
    LocalItemType routeType,
  ) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => routeType.page));
  }

  /// 导航到网络页面
  static void navigateToNetPage(
    BuildContext context,
    String userName,
    RoomInfo roomInfo,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NetChatPage(
          userName: userName,
          roomInfo: roomInfo,
          gameFactory: createRoomGame,
        ),
      ),
    );
  }
}
