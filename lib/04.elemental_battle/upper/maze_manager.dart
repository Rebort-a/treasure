import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../00.common/widget/banner/banner_template.dart';
import '../../00.common/game/gamer.dart';
import '../../00.common/widget/dialog/template_dialog.dart';
import '../../00.common/tool/notifiers.dart';
import '../../00.common/image/entity.dart';
import '../../00.common/game/map.dart';
import '../../l10n/strings.dart';

import '../base/energy.dart';
import '../base/map.dart';
import '../middle/common.dart';
import '../middle/elemental.dart';
import '../middle/enemy.dart';
import '../middle/player.dart';
import '../middle/dialog.dart';
import 'cast_page.dart';
import 'local_combat_page.dart';
import '../upper/package_page.dart';
import '../upper/skill_page.dart';
import '../upper/status_page.dart';
import '../upper/store_page.dart';

class CellNotifier extends ValueNotifier<CellData> {
  CellNotifier(super.value);

  void setEntity(EntityType newId) {
    value.id = newId;
    notifyListeners();
  }

  void setFog(bool newFog) {
    value.fogFlag = newFog;
    notifyListeners();
  }

  void setForeIndex(int newIndex) {
    value.foreIndex = newIndex;
    notifyListeners();
  }

  void setBackIndex(int newIndex) {
    value.backIndex = newIndex;
    notifyListeners();
  }
}

class MazeManager {
  final int mapSize = 2 * mapLevel + 1; // 确定地图的宽和高
  final Random _random = Random(); // 初始化随机生成器

  MapDataStack _mapData = MapDataStack(y: 0, x: 0, parent: null); // 初始化主城的地图数据栈

  final player = NormalPlayer(
    id: EntityType.player,
    y: mapLevel,
    x: mapLevel,
  ); // 创建并初始化玩家

  late Timer _activeTimer; // 活动定时器

  final AlwaysNotifier<void Function(BuildContext)> pageNavigator =
      AlwaysNotifier((_) {}); // 供弹出界面区域监听
  bool _canNavigator = true; // 是可跳转到其他页面或进行弹窗

  final ValueNotifier<int> floorNum = ValueNotifier(0); // 供标题监听

  final ListNotifier<CellNotifier> displayMap = ListNotifier([]); // 供地图区域监听

  MazeManager() {
    _generateMap(); // 生成地图
    _startActive(); // 添加键盘响应，启动定时器
    _fillPropHandler(); // 填充玩家的道具作用
  }

  void _generateMap() {
    displayMap.value = List.generate(
      mapSize * mapSize,
      (index) => CellNotifier(
        _mapData.parent == null
            ? CellData(id: EntityType.road, fogFlag: false)
            : CellData(id: EntityType.wall, fogFlag: true),
      ),
    );

    _mapData.parent == null ? _generateMainMap() : _generateRelicMap();
  }

  void _generateMainMap() {
    List<(int, int, EntityType)> entities = [
      (0, 0, EntityType.enter),
      (0, mapLevel, EntityType.train),
      (0, mapSize - 1, EntityType.enter),
      (mapLevel, 0, EntityType.store),
      (mapLevel, mapSize - 1, EntityType.gym),
      (mapSize - 1, 0, EntityType.enter),
      (mapSize - 1, mapLevel, EntityType.home),
      (mapSize - 1, mapSize - 1, EntityType.enter),
    ];

    for (final (y, x, type) in entities) {
      _setCellToEntity(y, x, type);
    }

    _setCellToPlayer(mapLevel, mapLevel, player.id);
  }

  void _generateRelicMap() {
    // 使用深度优先搜索生成迷宫
    _generateMaze(mapLevel, mapLevel);
    _setCellToPlayer(mapLevel, mapLevel, EntityType.exit);
  }

  void _generateMaze(int startY, int startX) {
    // 当前位置设置为道路
    _setCellToEntity(startY, startX, EntityType.road);

    List<(int, int)> directions = [
      (-1, 0), // up
      (1, 0), // down
      (0, -1), // left
      (0, 1), // right
    ]; // 四个方向

    // 随机打乱方向
    directions.shuffle();

    int branchCount = 0;

    for (final (dy, dx) in directions) {
      int newY = startY + dy * 2;
      int newX = startX + dx * 2;

      if (_checkInMap(newY, newX)) {
        if (_getCellData(newY, newX).id == EntityType.wall) {
          _setCellToEntity(startY + dy, startX + dx, EntityType.road); // 打通中间的墙
          _generateMaze(newY, newX);
          branchCount++; // 增加分支
        }
      }
    }

    if (branchCount == 0) {
      // 如果所在地，没有任何可探索的分支，代表其是道路尽头
      // 生成随机物品或入口
      _setCellToEntity(startY, startX, _getRadomItem());
    } else if (branchCount == 1) {
      // 不生成
    } else if (branchCount == 2) {
      // 生成随机敌人
      _setCellToEntity(startY, startX, _getRandomEnemy(startY, startX));
    }
  }

  EntityType _getRadomItem() {
    int randVal = _random.nextInt(100);
    if (randVal < 15) {
      return EntityType.purse;
    } else if (randVal < 30) {
      return EntityType.hospital;
    } else if (randVal < 45) {
      return EntityType.sword;
    } else if (randVal < 60) {
      return EntityType.shield;
    } else {
      return EntityType.enter;
    }
  }

  EntityType _getRandomEnemy(int y, int x) {
    // 随机敌人类型
    EntityType entityID;
    int randVal = _random.nextInt(100);
    if (randVal < 72) {
      entityID = EntityType.weak;
    } else if (randVal < 88) {
      entityID = EntityType.opponent;
    } else if (randVal < 96) {
      entityID = EntityType.strong;
    } else {
      entityID = EntityType.boss;
    }

    // 根据层数和敌人类型确定等级
    // 添加到地图数据的实体列表中
    _mapData.entities.add(
      RandomEnemy.generate(id: entityID, y: y, x: x, grade: floorNum.value),
    );

    return entityID;
  }

  void _startKeyboard() {
    // 添加键盘事件处理器
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyboardEvent);
  }

  void _stopKeyboard() {
    // 移除键盘事件处理器
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyboardEvent);
  }

  bool _handleHardwareKeyboardEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          movePlayerUp();
          break;
        case LogicalKeyboardKey.arrowDown:
          movePlayerDown();
          break;
        case LogicalKeyboardKey.arrowLeft:
          movePlayerLeft();
          break;
        case LogicalKeyboardKey.arrowRight:
          movePlayerRight();
          break;
        default:
          return false;
      }
      return true;
    }
    return false;
  }

  void _startTimer() {
    // 启动定时器
    _activeTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _moveEntities();
    });
  }

  void _stopTimer() {
    if (_activeTimer.isActive) {
      _activeTimer.cancel();
    }
  }

  void _startActive() {
    _canNavigator = true;
    _startKeyboard();
    _startTimer();
  }

  bool _stopActive() {
    if (!_canNavigator) {
      return false;
    } else {
      _canNavigator = false;
      _stopKeyboard();
      _stopTimer();
      return true;
    }
  }

  void _fillPropHandler() {
    player.props[EntityType.scroll]?.handler = (context, elemental, after) {
      after();
      _backToMain();
      Navigator.pop(context);
    };
  }

  // 玩家操作
  void switchPlayerNext() => player.switchNextAlive();
  void movePlayerUp() => _movePlayer(Direction.up);
  void movePlayerDown() => _movePlayer(Direction.down);
  void movePlayerLeft() => _movePlayer(Direction.left);
  void movePlayerRight() => _movePlayer(Direction.right);

  void navigateToPackagePage(BuildContext context) {
    _navigateAndSetActive(context, PackagePage(player: player));
  }

  void navigateToStorePage(BuildContext context) {
    _navigateAndSetActive(context, StorePage(player: player));
  }

  void navigateToSkillsPage(BuildContext context) {
    _navigateAndSetActive(context, SkillsPage(player: player));
  }

  void navigateToStatusPage(BuildContext context) {
    _navigateAndSetActive(context, StatusPage(elemental: player));
  }

  void _navigateAndSetActive(BuildContext context, Widget page) {
    if (_stopActive()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      ).then((_) {
        // 当页面弹出（即返回）时，这个回调会被执行
        _startActive(); // 重新启动定时器
      });
    }
  }

  void navigateToCastPage(BuildContext context) {
    if (_stopActive()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CastPage(totalPoints: 30)),
      ).then((result) {
        // 当页面弹出（即返回）时，这个回调会被执行
        if (result != null) {
          final configs = result as EnergyConfigs;
          pageNavigator.value = (BuildContext context) {
            navigateToPracticePage(
              context,
              Elemental(baseName: S.dummy, configs: configs, current: 0),
            );
          };
        }
        _startActive(); // 重新启动定时器
      });
    }
  }

  void navigateToPracticePage(BuildContext context, Elemental enemy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocalCombatPage(
          player: player,
          enemy: enemy,
          playerType: TurnGamerType.front,
        ),
      ),
    ).then((_) {
      player.restoreAllAttributesAndEffects();
    });
  }

  void navigateToCombatPage(
    BuildContext context,
    RandomEnemy enemy,
    TurnGamerType playerType,
  ) {
    if (_stopActive()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocalCombatPage(
            player: player,
            enemy: enemy,
            playerType: playerType,
          ),
        ),
      ).then((value) {
        // 当页面弹出（即返回）时，这个回调会被执行
        _startActive(); // 重新启动定时器
        if (value != null && value is ResultType) {
          if (value == ResultType.victory) {
            player.experience += 10 + 2 * enemy.grade;
            _mapData.entities.remove(enemy);
            _setCellToEntity(enemy.y, enemy.x, EntityType.road); // 从地图上清除敌人
            _restorePlayer(); // 恢复玩家状态
          } else if (value == ResultType.defeat) {
            player.experience -= 5;
            _backToMain();
          } else if (value == ResultType.escape) {
            player.experience -= 2;
          }
        }
      });
    }
  }

  void _backToMain() {
    while (_mapData.parent != null) {
      _backToPrevious();
    }
    _updatePlayerCell(Direction.down); // 更新方向
    _setCellToPlayer(mapLevel, mapLevel, player.id);
    pageNavigator.value = (BuildContext context) {
      BannerTemplate.snackBarDialog(context, S.returnedToCity);
    };
  }

  void _moveEntities() {
    for (MovableEntity entity in _mapData.entities) {
      if (entity is RandomEnemy) {
        List<List<int>> directions = [
          [0, -1], // 向左
          [-1, 0], // 向上
          [1, 0], // 向下
          [0, 1], // 向右
        ];

        // 随机打乱方向
        directions.shuffle();

        int newY = entity.y + directions[0][0];
        int newX = entity.x + directions[0][1];

        if (_checkInMap(newY, newX)) {
          CellData cell = displayMap.value[newY * mapSize + newX].value;

          switch (cell.id) {
            case EntityType.road:
              _setCellToEntity(newY, newX, entity.id); // 设置新位置
              _setCellToEntity(entity.y, entity.x, EntityType.road); // 清除旧位置
              entity.updatePosition(newY, newX); // 更新位置
              break;
            case EntityType.player:
              pageNavigator.value = (BuildContext context) {
                navigateToCombatPage(context, entity, TurnGamerType.rear);
              };
              break;
            default:
              break;
          }
        }
      }
    }
  }

  void _movePlayer(Direction direction) {
    _updatePlayerCell(direction);

    int newY = player.y;
    int newX = player.x;

    switch (direction) {
      case Direction.up:
        newY -= 1;
        break;
      case Direction.down:
        newY += 1;
        break;
      case Direction.left:
        newX -= 1;
        break;
      case Direction.right:
        newX += 1;
        break;
    }

    if (_checkInMap(newY, newX)) {
      CellData cell = displayMap.value[newY * mapSize + newX].value;
      switch (cell.id) {
        case EntityType.road:
          _setCellToPlayer(newY, newX, player.id);
          break;
        case EntityType.wall:
          break;
        case EntityType.enter:
          _enterTheNext(newY, newX);
          break;
        case EntityType.exit:
          _backToPrevious();
          break;
        case EntityType.train:
          pageNavigator.value = navigateToCastPage;
          break;
        case EntityType.gym:
          pageNavigator.value = (BuildContext context) {
            ElementalDialog.showUpgradeDialog(
              context: context,
              before: _stopActive,
              after: _startActive,
              upgrade: _upgradePlayer,
            );
          };
          break;
        case EntityType.store:
          pageNavigator.value = navigateToStorePage;
          break;
        case EntityType.home:
          _restorePlayer();
          pageNavigator.value = (BuildContext context) {
            DialogTemplate.promptDialog(
              context: context,
              title: S.notice,
              content: S.slept,
              before: _stopActive,
              after: _startActive,
            );
          };
          break;
        case EntityType.hospital:
          player.props[EntityType.hospital]?.count += 1;
          pageNavigator.value = (BuildContext context) {
            BannerTemplate.snackBarDialog(context, S.gotMedicine);
          };
          _setCellToEntity(newY, newX, EntityType.road);
          break;
        case EntityType.sword:
          player.props[EntityType.sword]?.count += 1;
          pageNavigator.value = (BuildContext context) {
            BannerTemplate.snackBarDialog(context, S.gotWeapon);
          };
          _setCellToEntity(newY, newX, EntityType.road);
          break;
        case EntityType.shield:
          player.props[EntityType.shield]?.count += 1;
          pageNavigator.value = (BuildContext context) {
            BannerTemplate.snackBarDialog(context, S.gotArmor);
          };
          _setCellToEntity(newY, newX, EntityType.road);
          break;
        case EntityType.purse:
          int money = 5 + _random.nextInt(25);
          player.money += money;
          pageNavigator.value = (BuildContext context) {
            BannerTemplate.snackBarDialog(context, S.gotMoneyBag(money));
          };
          _setCellToEntity(newY, newX, EntityType.road);
          break;
        case EntityType.weak:
        case EntityType.opponent:
        case EntityType.strong:
        case EntityType.boss:
          for (MovableEntity entity in _mapData.entities) {
            if ((entity.y == newY) && (entity.x == newX)) {
              if (entity is RandomEnemy) {
                pageNavigator.value = (BuildContext context) {
                  navigateToCombatPage(context, entity, TurnGamerType.front);
                };
              }
            }
          }
          break;
        default:
          break;
      }
    }
  }

  void _backToPrevious() {
    final parent = _mapData.parent;
    if (parent != null) {
      floorNum.value--;

      _clearPlayerCurrentCell();

      _mapData.leaveMap = displayMap.value
          .map((cellState) => cellState.value)
          .toList();
      // 获取当前地图数据

      int playerY = _mapData.y;
      int playerX = _mapData.x;

      _mapData = parent; // 回退到上一层

      displayMap.value = _mapData.leaveMap
          .map((data) => CellNotifier(data))
          .toList(); // 从当前地图数据中恢复

      _setCellToPlayer(playerY, playerX, EntityType.enter); // 更新位置
    }
  }

  void _enterTheNext(int newY, int newX) {
    if (player.preview.health.value <= 0) {
      pageNavigator.value = (BuildContext context) {
        BannerTemplate.snackBarDialog(context, S.cannotContinue);
      };
      return;
    }

    floorNum.value++;

    _clearPlayerCurrentCell();

    _mapData.leaveMap = displayMap.value
        .map((cellState) => cellState.value)
        .toList();
    // 获取当前地图数据
    for (MapDataStack child in _mapData.children) {
      if (child.y == newY && child.x == newX) {
        _mapData = child;
        displayMap.value = _mapData.leaveMap
            .map((data) => CellNotifier(data))
            .toList(); // 从当前地图数据中恢复
        _setCellToPlayer(mapLevel, mapLevel, EntityType.exit);
        return;
      }
    }
    MapDataStack newMap = MapDataStack(y: newY, x: newX, parent: _mapData);
    _mapData.children.add(newMap);
    _mapData = newMap;
    _generateMap();
  }

  void _updatePlayerCell(Direction direction) {
    player.updateDirection(direction); // 更新方向

    displayMap.value[player.y * mapSize + player.x].setForeIndex(
      player.col + player.row,
    );
  }

  void _restorePlayer() {
    player.restoreAllAttributesAndEffects();
  }

  void _upgradePlayer(int index, AttributeType attribute) {
    if (player.experience >= 30) {
      player.experience -= 30;
      player.upgradeAppointAttribute(EnergyType.values[index], attribute);
      pageNavigator.value = (BuildContext context) {
        BannerTemplate.snackBarDialog(context, S.levelUpSuccess);
      };
    } else {
      pageNavigator.value = (BuildContext context) {
        BannerTemplate.snackBarDialog(context, S.notEnoughExp);
      };
    }
  }

  void _setCellToEntity(int y, int x, EntityType id) {
    displayMap.value[y * mapSize + x].setEntity(id);
  }

  void _setCellToPlayer(int newY, int newX, EntityType id) {
    // debugPrint('set player to $newY, $newX, $id');
    _clearPlayerCurrentCell();
    player.updatePosition(newY, newX); // 更新位置
    displayMap.value[newY * mapSize + newX].value = CellData(
      id: id,
      foreIndex: player.col + player.row,
      backIndex: 1,
    ); // 设置新位置
    _clearAroundFog(player.y, player.x);
  }

  void _clearPlayerCurrentCell() {
    CellData cell = _getCellData(player.y, player.x);
    if (cell.id == player.id) {
      _setCellToEntity(player.y, player.x, EntityType.road); // 设置为道路
    } else {
      displayMap.value[player.y * mapSize + player.x].setBackIndex(0);
    }
  }

  CellData _getCellData(int y, int x) {
    return displayMap.value[y * mapSize + x].value;
  }

  void _clearAroundFog(int y, int x) {
    displayMap.value[y * mapSize + x].setFog(false);

    for (final (dy, dx) in planeAround) {
      int newY = y + dy;
      int newX = x + dx;
      if (_checkInMap(newY, newX)) {
        displayMap.value[newY * mapSize + newX].setFog(false);
      }
    }
  }

  bool _checkInMap(int y, int x) {
    return (y >= 0) && (y < mapSize) && (x >= 0) && (x < mapSize);
  }
}
