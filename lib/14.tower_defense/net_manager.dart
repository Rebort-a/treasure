import 'dart:convert';

import '../00.common/engine/net_real_engine.dart';
import '../00.common/network/network_message.dart';
import '../00.common/network/network_room.dart';
import 'base.dart';
import 'foundation_manager.dart';

class NetManager extends FoundationManager {
  late final NetRealGameEngine engine;
  final int _seed;

  NetManager({required String userName, required RoomInfo roomInfo})
    : _seed = roomInfo.hashCode {
    engine = NetRealGameEngine(
      userName: userName,
      roomInfo: roomInfo,
      navigatorHandler: pageNavigator,
      searchHandler: _handleSearch,
      resourceHandler: _handleResource,
      syncHandler: _handleSync,
      actionHandler: _handleAction,
      exitHandler: _handleExit,
    );
  }

  void _handleSearch(int id) {
    initGame(seed: _seed);
    engine.sendNetworkMessage(MessageType.resource, _encodeState());
  }

  void _handleResource(NetworkMessage message) {
    _decodeState(message.content);
    engine.sendNetworkMessage(MessageType.sync, 'ok');
  }

  void _handleSync(int id) {
    // 同步完成，开始游戏
  }

  void _handleAction(NetworkMessage message) {
    final data = jsonDecode(message.content) as Map<String, dynamic>;
    final action = data['action'] as String;

    switch (action) {
      case 'placeTower':
        final type = TowerType.values[data['type'] as int];
        final pos = GridPos.fromJson(data['pos'] as Map<String, dynamic>);
        placeTower(pos, type);
        break;
      case 'startWave':
        startNextWave();
        break;
    }
  }

  void _handleExit(int id) {
    // 对手退出
  }

  @override
  bool placeTower(GridPos pos, TowerType type) {
    final result = super.placeTower(pos, type);
    if (result) {
      engine.sendNetworkMessage(
        MessageType.action,
        jsonEncode({
          'action': 'placeTower',
          'type': type.index,
          'pos': pos.toJson(),
        }),
      );
    }
    return result;
  }

  @override
  void startNextWave() {
    super.startNextWave();
    engine.sendNetworkMessage(
      MessageType.action,
      jsonEncode({'action': 'startWave'}),
    );
  }

  String _encodeState() => jsonEncode({
    'seed': _seed,
    'gold': gold.value,
    'lives': lives.value,
    'wave': waveNumber.value,
  });

  void _decodeState(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    initGame(seed: data['seed'] as int);
    gold.value = data['gold'] as int;
    lives.value = data['lives'] as int;
    waveNumber.value = data['wave'] as int;
  }

  void leavePage() => engine.leavePage();
}
