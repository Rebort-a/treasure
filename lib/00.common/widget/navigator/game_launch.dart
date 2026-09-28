import 'package:flutter/widgets.dart';

import '../../engine/net_game_engine.dart';
import '../../engine/network_engine.dart';

/// 由应用装配层注入，聊天室无需知道具体游戏类型和页面实现。
typedef GameLaunchFactory = GameLaunch? Function(NetworkEngine room);

/// 在匹配阶段持有管理器，页面退出动画完成后统一释放。
class GameLaunch {
  final NetGameEngine engine;
  final Widget Function() buildPage;
  final VoidCallback _dispose;
  bool _disposed = false;

  GameLaunch(this.engine, this.buildPage, VoidCallback dispose)
    : _dispose = dispose;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dispose();
  }
}
