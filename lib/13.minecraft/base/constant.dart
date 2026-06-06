/// 游戏常量
class Constants {
  // ============================
  // 世界基本参数
  // ============================

  /// 方块尺寸
  static const int blockSize = 2;

  /// 方块半尺寸
  static const int blockSizeHalf = 1;

  /// 浮点数比较容差
  static const double epsilon = 1e-3;

  // ============================
  // 物理参数
  // ============================

  /// 重力加速度
  static const double gravity = 20;

  /// 最大下落速度
  static const double maxFallSpeed = 20.0;

  /// 地面摩擦系数
  static const double friction = 0.8;

  // ============================
  // 玩家参数
  // ============================

  /// 玩家宽度
  static const double playerWidth = 1;

  /// 玩家高度
  static const double playerHeight = 3;

  // ============================
  // 控制参数
  // ============================

  /// 基础移动速度
  static const double moveSpeed = 3.0;

  /// 跳跃初速度
  static const double jumpVelocity = 10;

  /// 触摸灵敏度
  static const double touchSensitivity = 0.005;

  /// 鼠标灵敏度
  static const double mouseSensitivity = 0.002;

  /// 俯仰角限制
  static const double pitchLimit = 0.8;

  // ============================
  // 性能参数
  // ============================

  /// 最小帧时间
  static const double minDeltaTime = 0.004;

  /// 最大帧时间
  static const double maxDeltaTime = 0.02;

  // ============================
  // 区块参数
  // ============================

  /// 区块尺寸
  static const int chunkBlockCount = 8;

  /// 区块组
  static const int chunkGroupSize = 3;

  /// 加载区块数量
  static const int loadChunkCount = 1;

  /// 渲染距离
  static const double renderDistance = 16;

  // ============================
  // 八叉树参数
  // ============================

  /// 每个节点最大方块数量
  static const int maxBlocksPerNode = 4;

  /// 合并阈值
  static const int mergeThreshold = 3;

  // ============================
  // 渲染参数
  // ============================

  /// 近裁剪平面距离
  static const double nearClip = 0.1;

  /// 远裁剪平面距离
  static const double farClip = 300.0;

  /// 垂直视野角度（单位：度）
  static const double fieldOfView = 60.0;

  /// 焦距
  static const double focalLength = 300.0;

  /// 背面光照系数（值越小越暗）
  static const double lightingBackFace = 0.8;

  /// 正面光照系数（值越大越亮）
  static const double lightingFrontFace = 1.2;

  /// 顶面光照系数（模拟天空光照）
  static const double lightingTopFace = 1.1;

  /// 底面光照系数（模拟地面反射）
  static const double lightingBottomFace = 0.9;

  /// 默认光照系数
  static const double lightingDefault = 1.0;

  /// NDC坐标缩放系数（标准化设备坐标）
  static const double ndcScale = 0.5;

  /// NDC坐标偏移量
  static const double ndcOffset = 0.5;

  /// 屏幕Y轴翻转（1.0为正常，-1.0为翻转）
  static const double screenYFlip = 1.0;

  // ============================
  // UI参数
  // ============================

  /// 摇杆底座半径
  static const double joystickBaseRadius = 60;

  /// 摇杆手柄半径
  static const double joystickStickRadius = 30;

  /// 跳跃按钮尺寸
  static const double jumpButtonSize = 60;

  /// 十字准星尺寸
  static const double crosshairSize = 20;

  /// 十字准星线条粗细
  static const double crosshairStroke = 2;

  /// 十字准星交叉部分尺寸
  static const double crosshairCrossSize = 8;

  // ============================
  // 方块交互参数
  // ============================

  /// 方块摧毁耗时（秒）
  static const double destroyTime = 1.0;

  /// 方块摧毁距离（方块数）
  static const double destroyReach = 3.0;

  /// 方块放置距离（方块数）
  static const double placeReach = 5.0;

  /// 区分点击和拖拽的像素阈值
  static const double tapMoveThreshold = 10.0;

  /// 长按触发时间（秒）
  static const double longPressTime = 0.5;

  /// 背包栏位数
  static const int hotbarSlotCount = 9;

  // ============================
  // 世界生成参数
  // ============================

  /// 世界最大高度
  static const int worldMaxHeight = 128;

  /// 世界最小高度
  static const int worldMinHeight = -64;

  /// 基岩层
  static const int worldBedrockLevel = worldMinHeight + blockSizeHalf;

  /// 海平面
  static const int worldSeaLevel = 0;

  /// 地表
  static const int worldSurfaceLevel = 16;
}
