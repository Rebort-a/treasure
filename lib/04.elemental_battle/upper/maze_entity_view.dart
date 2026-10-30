import 'package:flutter/material.dart';

import '../../00.common/image/image_manager.dart';
import '../base/entity.dart';

class MazeEntityView {
  static final _instance = MazeEntityView._internal();

  factory MazeEntityView() {
    return _instance;
  }

  MazeEntityView._internal();

  final Map<EntityType, ImageSplitter> _imageSplitters = {};

  Widget getImage(EntityType id, int foreIndex, int backIndex, bool fogFlag) {
    if (fogFlag) {
      return Container(color: Colors.black);
    } else {
      return Container(
        color: _getBackground(id, backIndex),
        child: Center(child: _getForeground(id, foreIndex)),
      );
    }
  }

  Widget _getForeground(EntityType id, int foreIndex) {
    switch (id) {
      case EntityType.player:
        return _getAssetsImage(id, foreIndex);
      default:
        return _getPresetsEmoji(id);
    }
  }

  Widget _getAssetsImage(EntityType id, int foreIndex) {
    _imageSplitters.putIfAbsent(id, () {
      switch (id) {
        case EntityType.player:
          return ImageSplitter(
            imagePath: 'assets/images/player.png',
            rows: 4,
            columns: 4,
          );
        default:
          return ImageSplitter(
            imagePath: 'assets/images/road.png',
            rows: 1,
            columns: 1,
          );
      }
    });

    return _imageSplitters[id]!.getImagePiece(foreIndex);
  }

  static Color _getBackground(EntityType id, int index) {
    switch (id) {
      case EntityType.wall:
        return Colors.brown; // 墙壁
      case EntityType.exit:
      case EntityType.enter:
        switch (index) {
          case 1:
            return const Color(0xFFC0C0C0);
          default:
            return Colors.blueGrey;
        }
      case EntityType.train:
      case EntityType.gym:
      case EntityType.store:
      case EntityType.home:
        return Colors.teal;
      default:
        return Colors.blueGrey; // 道路的背景
    }
  }

  static Widget _getPresetsEmoji(EntityType id) {
    switch (id) {
      case EntityType.road:
        return const SizedBox.shrink(); // 道路
      case EntityType.wall:
        return const Text('🧱'); // 墙壁
      case EntityType.player: // 玩家
        return const Text('😎');
      case EntityType.enter:
        return const Icon(Icons.exit_to_app); // 入口
      case EntityType.exit:
        return const Icon(Icons.door_sliding); // 出口
      case EntityType.train:
        return const Text('🏟️'); // 训练场
      case EntityType.gym:
        return const Text('💪'); // 健身房
      case EntityType.store:
        return const Text('🏦'); // 商店
      case EntityType.home:
        return const Text('🏠'); // 家
      case EntityType.hospital:
        return const Text('💊'); // 药
      case EntityType.sword:
        return const Text('🗡️'); // 剑
      case EntityType.shield:
        return const Text('🛡️'); // 盾
      case EntityType.purse:
        return const Text('💰'); // 钱袋
      case EntityType.weak:
        return const Text('👻'); // 弱鸡
      case EntityType.opponent:
        return const Text('🤡'); // 对手
      case EntityType.strong:
        return const Text('👿'); // 强敌
      case EntityType.boss:
        return const Text('💀'); // 魔王
      default:
        return const Text('❓'); // 未知
    }
  }
}
