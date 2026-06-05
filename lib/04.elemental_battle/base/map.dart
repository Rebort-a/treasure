import '../../00.common/game/map.dart';
import '../../00.common/image/entity.dart';

const int mapLevel = 6; // 地图级数

// 地图单元信息
class CellData {
  EntityType id;
  int foreIndex;
  int backIndex;
  bool fogFlag;

  CellData({
    required this.id,
    this.foreIndex = 0,
    this.backIndex = 0,
    this.fogFlag = true,
  });
}

// 地图栈
class MapDataStack {
  final int y, x; // 地图在父地图的位置
  final MapDataStack? parent; // 父节点
  final List<MapDataStack> children = []; // 子节点列表
  List<CellData> leaveMap = []; // 玩家离开时的地图数据
  List<MovableEntity> entities = []; // 地图上的实体数据

  MapDataStack({required this.y, required this.x, required this.parent});
}
