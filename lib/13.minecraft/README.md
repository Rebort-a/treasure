# 13.minecraft 模块说明文档

## 项目概述

这是一个用纯 Flutter/Dart 实现的 Minecraft 风格体素(Voxel)3D 渲染引擎。不依赖任何 3D 图形库(如 OpenGL/WebGPU)，完全通过 `CustomPainter` + 数学计算实现软渲染。

## 架构分层

```
┌─────────────────────────────────────────────┐
│  upper (UI + 渲染层)                         │
│  page.dart / widget.dart / scene_render.dart │
│  frustum.dart / face_merger.dart / occlusion │
├─────────────────────────────────────────────┤
│  middle (管理层)                              │
│  manager.dart / control_manager.dart         │
│  chunk_manager.dart / world_generator.dart   │
├─────────────────────────────────────────────┤
│  base (基础数据层)                            │
│  vector / matrix / aabb / block / chunk      │
│  player / collider / octree / face           │
└─────────────────────────────────────────────┘
```

## 文件详细说明

### base 层 — 基础数学与数据结构

| 文件 | 职责 |
|------|------|
| vector.dart | 向量系统：`Vector2`/`Vector3`/`Vector4` 及其 Int 变体，`UnitVector2`/`Vector3Unit` 单位向量。支持旋转(`rotateAroundX/Y/Z`)、点积、叉积、归一化 |
| matrix.dart | 4x4 矩阵(`ColMat4`/`ColMat4Int`)，列主序存储。提供 `lookAtLH`(视图矩阵)、`perspectiveLH`(透视投影)、`inverse`(逆矩阵)、`determinant`(行列式) |
| aabb.dart | 轴对齐包围盒(`AABB`/`AABBInt`)：相交检测、包含检测、重叠向量计算(用于碰撞响应)、`expand` 扩展 |
| block.dart | 方块系统：22 种 `BlockType`(基岩/石头/草/矿石/水/玻璃等)，每种有颜色、透明度、可穿透性属性。`Block` 类包含碰撞体、8 顶点、6 面数据，支持背面剔除缓存 |
| chunk.dart | 区块(`Chunk`)：16x16x16 方块空间，内部使用八叉树(`BlockOctree`)管理方块 |
| octree.dart | 八叉树空间索引：支持插入/删除/按位置查询/范围查询。节点超阈值(4个方块)自动分裂，方块少于阈值(3个)自动合并 |
| face.dart | 六面体面定义模板：6 个面的顶点索引和法向量 |
| collider.dart | 碰撞体：`FixedBoxCollider`(方块，整型AABB) 和 `MovedBoxCollider`(玩家，浮点AABB，眼睛偏上偏前)。提供 AABB 相交检测和重叠解析 |
| player.dart | 玩家角色：位置、朝向(单位向量)、速度、重力、跳跃、碰撞响应。移动基于朝向分解(前进/右向分量)，视角旋转使用单位向量绕 Y 轴旋转 |
| constant.dart | 全局常量：方块尺寸(2)、物理参数(重力20/摩擦0.8)、渲染参数(FOV 60°/焦距300/远裁剪面300)、区块参数(8方块/组3x3)、八叉树参数 |

### middle 层 — 游戏逻辑管理

| 文件 | 职责 |
|------|------|
| common.dart | `SceneInfo` 数据类：封装相机位置、朝向、可见方块列表，作为渲染层的输入 |
| manager.dart | 游戏主循环(`Manager`)：`ChangeNotifier` + `Ticker` 驱动。每帧：处理输入→获取碰撞方块→更新玩家物理→加载区块→判断是否需要重绘→`notifyListeners` |
| control_manager.dart | 输入控制：键盘 WASD/方向键移动、Space 跳跃、鼠标悬停/触摸拖拽控制视角。移动端通过 `setMobileMove`/`setMobileJump` 接口 |
| chunk_manager.dart | 区块管理：以玩家为中心加载/卸载区块(距离1格)。已生成区块缓存在 `_archivedBlocks`，支持队列式延迟加载。提供 `getRenderBlocks`(渲染距离16)和 `getCollisionBlocks`(玩家AABB扩展) |
| world_generator.dart | 世界生成器：基于种子的程序化地形。使用温度/湿度噪声映射 7 种生物群系(平原/森林/沙漠/山脉/雪地/海滩/沼泽)。地表 1-6 层(1% 概率0层)，顶层为群系对应方块，下层为泥土。树木预计算+跨区块生成，树冠为球形 |

### upper 层 — 渲染与 UI

| 文件 | 职责 |
|------|------|
| page.dart | 入口页面 `MinecraftPage`：组合场景渲染、十字准星、键盘/鼠标输入、移动端控制。通过 `AnimatedBuilder` 监听 `Manager` 变化自动重绘 |
| widget.dart | UI 组件：`MobileControls`(虚拟摇杆+跳跃按钮)、`Crosshair`(十字准星 CustomPaint) |
| scene_render.dart | 核心渲染器 `ScenePainter`：完整 3D 渲染管线。天空背景→视锥体裁剪→遮挡剔除→近裁剪面剔除→背面剔除→深度排序→面合并→透视投影→屏幕裁剪→光照着色→绘制。支持调试配置开关 |
| frustum.dart | 视锥体：从 VP 矩阵提取 6 个裁剪平面，支持 AABB 相交测试和点包含测试 |
| face_merger.dart | 面合并优化：将同类型、同法线、共面且相邻的方块面合并为大面(类似 greedy meshing)，减少绘制调用。检测合并后是否被遮挡 |
| occlusion_culler.dart | 遮挡剔除：基于射线-AABB 相交检测，检查目标方块的 8 个角点是否被附近遮挡物挡住。近距离物体始终可见 |

## 核心渲染管线

```
每帧渲染流程:
1. 天空背景渐变绘制
2. 获取可见方块列表
   ├── 视锥体裁剪 (FrustumManager)
   ├── 遮挡剔除 (OcclusionCuller)
   └── 近裁剪面剔除
3. 面合并 (FaceMerger.mergeVisibleFaces)
   ├── 按类型+法线+区块分组
   ├── BFS 查找相邻面
   └── 合并为 MergedFace
4. 深度排序 (从远到近)
5. 透视投影 3D→2D (VP矩阵 × 世界坐标 → NDC → 屏幕坐标)
6. 屏幕裁剪 (Sutherland-Hodgman 多边形裁剪)
7. 光照着色 (根据法线方向: 顶面最亮/底面最暗/侧面中等)
8. Canvas 绘制多边形 + 边框
```

## 游戏循环

```
Ticker 驱动 (~60fps):
1. 计算 deltaTime (clamp 4ms~20ms)
2. 处理玩家输入 → 更新移动/跳跃
3. 获取碰撞方块 → 更新玩家物理(重力+碰撞响应)
4. 处理区块加载队列
5. 判断位置/朝向是否变化 → 更新可见方块 → notifyListeners
```

## 世界生成

```
世界生成流程:
1. 根据区块坐标计算所属区块组(group)坐标
2. 生成组种子(基于世界种子+组坐标异或)
3. 计算组内温度/湿度噪声 → 映射生物群系
4. 计算地表高度(1~6层，1%概率0层)
5. 生成地表方块(顶层=群系方块，下层=泥土) + 基岩
6. 预计算树木位置(基于群系概率+远离组边缘)
7. 生成树木(树干+球形树冠)，支持跨区块重叠
```

## 关键设计决策

- **整型坐标系统**：方块位置使用 `Vector3Int`，避免浮点精度问题
- **单位向量表示朝向**：`Vector3Unit` 保证模长恒为1，旋转操作通过 `UnitVector2` 旋转向量实现
- **八叉树空间索引**：替代线性查找，方块查询和范围查询均为 O(log n)
- **面合并(Greedy Meshing)**：减少渲染面数，显著降低绘制调用
- **双层区块缓存**：`_archivedBlocks`(永久) + `_loadedChunks`(当前)，玩家返回已访问区域时无需重新生成

## 与 Minecraft 的对比

### 相同点

| 方面 | 说明 |
|------|------|
| 体素世界 | 都基于方块(Block)构成的 3D 世界，方块坐标为整数 |
| 区块(Chunk)系统 | 都将世界划分为区块进行管理，按需加载/卸载 |
| 程序化地形生成 | 都使用种子 + 噪声函数生成地形，支持多种生物群系 |
| 贪婪面合并(Greedy Meshing) | 都使用面合并优化减少渲染面数 |
| 背面剔除 | 都根据相机位置剔除不可见面 |
| 视锥体裁剪 | 都使用视锥体剔除屏幕外的方块 |
| 第一人称视角 | 都支持 WASD 移动 + 鼠标/触摸控制视角 |
| 碰撞检测 | 都使用 AABB 碰撞检测 + 重叠解析 |
| 重力与跳跃 | 都有重力系统和跳跃机制 |
| 区块组(Biome Group) | 都将多个区块归组以保证生物群系连续性 |

### 不同点

| 方面 | Minecraft | 本项目 |
|------|-----------|--------|
| **渲染方式** | OpenGL/WebGPU 硬件加速渲染 | Flutter `CustomPainter` 纯 CPU 软渲染 |
| **方块数量** | 数百种方块 + 数据值 | 22 种基础方块 |
| **光照系统** | 光照传播(天空光+方块光)，16级亮度 | 简单面法线光照(顶面亮/底面暗) |
| **世界大小** | 6000万 x 6000万方块 | 无边界但仅加载附近区块 |
| **区块大小** | 16x256x16 | 16x16x16 (8方块 x 尺寸2) |
| **高度** | 256层 (y: -64~320) | -64~128 |
| **树木** | 多种树种(橡木/桦木/丛林木等) | 单一球冠树 |
| **生物群系** | 50+ 种 | 7 种(平原/森林/沙漠/山脉/雪地/海滩/沼泽) |
| **生物(Mob)** | 动物/怪物/NPC | 无 |
| **合成/背包** | 完整合成系统 + 物品栏 | 无 |
| **红石电路** | 逻辑电路系统 | 无 |
| **多人游戏** | 客户端-服务器架构 | 单人离线 |
| **存档系统** | 区域文件(.mca)持久化 | 内存运行，退出即丢失 |
| **水/岩浆** | 流体传播、物理交互 | 仅渲染为半透明方块，可穿透 |
| **天气/昼夜** | 动态天气 + 昼夜循环 | 固定天空背景 |
| **音效** | 位置音效系统 | 无 |
| **地形复杂度** | 洞穴/矿脉/结构(村庄/要塞) | 平坦地表 + 树木 |
| **玩家交互** | 挖掘/放置/攻击/使用 | 仅移动和视角控制 |
| **性能优化** | VBO/实例化渲染/多线程区块加载 | 面合并 + 视锥裁剪 + 遮挡剔除 |
| **坐标精度** | 整型方块坐标 | 整型方块坐标(相同) |

### 简化实现的核心价值

本项目虽然功能远不及 Minecraft，但在以下方面具有教学和工程价值：

1. **零依赖 3D 渲染**：证明了不借助 GPU 也能实现体素世界的透视渲染
2. **完整数学库**：从零实现了向量、矩阵、AABB、八叉树等 3D 图形基础
3. **渲染管线全链路**：覆盖了从世界坐标到屏幕像素的完整变换流程
4. **优化策略实践**：视锥裁剪、遮挡剔除、面合并三大优化手段的完整实现
5. **物理系统原型**：重力、碰撞检测与响应的最小可用实现

## 常量参数速查

| 参数 | 值 | 说明 |
|------|-----|------|
| blockSize | 2 | 方块边长 |
| chunkBlockCount | 8 | 区块边长(方块数) |
| chunkGroupSize | 3 | 区块组边长(区块数) |
| loadChunkCount | 1 | 加载距离(区块数) |
| renderDistance | 16 | 渲染距离 |
| gravity | 20 | 重力加速度 |
| moveSpeed | 3.0 | 移动速度 |
| jumpVelocity | 10 | 跳跃初速度 |
| fieldOfView | 60° | 垂直视野 |
| nearClip | 0.1 | 近裁剪面 |
| farClip | 300 | 远裁剪面 |
| focalLength | 300 | 焦距 |
| maxBlocksPerNode | 4 | 八叉树节点最大方块数 |
| mergeThreshold | 3 | 八叉树合并阈值 |

---

## 3D 图形学知识体系

本项目涵盖了 3D 图形编程的核心基础知识，以下按主题梳理，可作为入门学习路线。

### 一、3D 数学基础

#### 1.1 向量 (Vector)

向量是 3D 图形的基本构建块，表示方向和大小。

**核心运算**（对应 `vector.dart`）：

| 运算 | 公式 | 用途 |
|------|------|------|
| 加减 | `A ± B` | 位移、求差向量 |
| 标量乘 | `A * k` | 缩放 |
| 点积 | `A·B = Ax*Bx + Ay*By + Az*Bz` | 求夹角、投影、背面剔除 |
| 叉积 | `A×B = (Ay*Bz-Az*By, Az*Bx-Ax*Bz, Ax*By-Ay*Bx)` | 求法线、构建坐标系 |
| 归一化 | `A / |A|` | 获得单位方向向量 |
| 模长 | `\|A\| = sqrt(x²+y²+z²)` | 距离计算 |

**代码示例**（背面剔除判断）：
```dart
// 面法线 · (相机位置 - 面中心) > 0 → 面朝相机 → 可见
final toCamera = (cameraPosition - face.center).normalized;
return face.normal.dot(toCamera) > 0;
```

#### 1.2 旋转与单位向量

本项目用 `UnitVector2` 表示旋转角度（cos θ, sin θ），避免三角函数：

```dart
// 绕 Y 轴旋转向量
Vector3 rotateAroundY(UnitVector2 vec) {
  return Vector3(x * vec.x + z * vec.y, y, -x * vec.y + z * vec.x);
}
```

这等价于旋转矩阵：
```
| cos θ   0   sin θ |   | x |
|   0     1     0   | × | y |
|-sin θ   0   cos θ |   | z |
```

#### 1.3 4x4 矩阵

4x4 矩阵是 3D 变换的统一表示（对应 `matrix.dart`）：

| 变换类型 | 矩阵结构 | 作用 |
|----------|----------|------|
| 平移 | 第4列为 (tx, ty, tz, 1) | 移动物体 |
| 缩放 | 对角线为 (sx, sy, sz, 1) | 放大缩小 |
| 旋转 | 3x3 子矩阵为正交矩阵 | 旋转物体 |
| 视图 | Look-At 构建 | 世界坐标 → 相机坐标 |
| 投影 | FOV + 宽高比 + 近远面 | 相机坐标 → 裁剪坐标 |

**列主序存储**：`index = 列号 * 4 + 行号`

#### 1.4 坐标系与坐标变换

本项目使用**左手坐标系**（X 右，Y 上，Z 前）：

```
世界坐标 ──[视图矩阵]──→ 相机坐标 ──[投影矩阵]──→ 裁剪坐标 ──[透视除法]──→ NDC ──[视口变换]──→ 屏幕坐标
```

### 二、3D 渲染管线

#### 2.1 视图矩阵 (View Matrix)

将世界坐标转换为相机坐标（对应 `ColMat4.lookAtLH`）：

```
1. forward = normalize(target - eye)    // 相机前方向(Z轴)
2. right   = normalize(up × forward)    // 相机右方向(X轴)
3. newUp   = forward × right            // 相机上方向(Y轴)

视图矩阵 = | right.x   right.y   right.z   -right·eye |
           | newUp.x   newUp.y   newUp.z   -newUp·eye |
           | fwd.x     fwd.y     fwd.z     -fwd·eye   |
           |   0         0         0          1        |
```

#### 2.2 透视投影矩阵

实现近大远小效果（对应 `ColMat4.perspectiveLH`）：

```
垂直缩放 = 1 / tan(FOV/2)
水平缩放 = 垂直缩放 / 宽高比
深度范围 = far / (far - near)

投影矩阵 = | hScale    0       0          0        |
           |   0     vScale    0          0        |
           |   0       0    depthRange    1        |
           |   0       0   -depth*near    0        |
```

#### 2.3 齐次坐标与透视除法

裁剪坐标 `(x, y, z, w)` 经透视除法得到 NDC：

```dart
ndcX = clipPoint.x / clipPoint.w;  // [-1, 1]
ndcY = clipPoint.y / clipPoint.w;  // [-1, 1]
screenX = (ndcX * 0.5 + 0.5) * width;
screenY = (1 - (ndcY * 0.5 + 0.5)) * height;  // Y轴翻转
```

#### 2.4 裁剪与剔除

| 技术 | 原理 | 对应文件 |
|------|------|----------|
| **背面剔除** | 法线·视线方向 ≤ 0 → 不可见 | `block.dart` |
| **视锥体裁剪** | 从 VP 矩阵提取 6 个平面，测试 AABB | `frustum.dart` |
| **近裁剪面** | 相机坐标 Z ≤ nearClip → 剔除 | `scene_render.dart` |
| **遮挡剔除** | 射线-AABB 相交检测，被挡住的物体不渲染 | `occlusion_culler.dart` |
| **屏幕裁剪** | Sutherland-Hodgman 多边形裁剪到屏幕边界 | `scene_render.dart` |

#### 2.5 深度排序 (画家算法)

从远到近绘制，近处物体覆盖远处物体：

```dart
blocks.sort((a, b) {
  final distA = (a.position - camera).magnitudeSquare;
  final distB = (b.position - camera).magnitudeSquare;
  return distB.compareTo(distA);  // 远的先画
});
```

#### 2.6 面光照

根据法线方向应用不同亮度系数：

```dart
final brightness = switch ((normal.z, normal.y)) {
  (< 0, _) => 0.8,  // 背面（暗）
  (> 0, _) => 1.2,  // 正面（亮）
  (0, > 0) => 1.1,  // 顶面（天空光）
  (0, < 0) => 0.9,  // 底面（地面反射）
  _ => 1.0,          // 侧面（默认）
};
final shadedColor = baseColor * brightness;
```

### 三、空间数据结构

#### 3.1 AABB (轴对齐包围盒)

快速的粗略碰撞检测（对应 `aabb.dart`）：

```
相交检测：三轴分别检查重叠
min1.x ≤ max2.x && max1.x ≥ min2.x  (X轴)
min1.y ≤ max2.y && max1.y ≥ min2.y  (Y轴)
min1.z ≤ max2.z && max1.z ≥ min2.z  (Z轴)
```

**最小重叠向量**：选择重叠量最小的轴作为碰撞响应方向。

#### 3.2 八叉树 (Octree)

3D 空间索引结构（对应 `octree.dart`）：

```
          [根节点]
        /    |    \  ...
     [子节点] [子节点] ...
     /  |  \
   ...  ...  ...
```

- **分裂条件**：节点内方块数 > 阈值(4) 且尺寸 > 最小尺寸
- **合并条件**：所有子节点为叶子且总方块数 ≤ 阈值(3)
- **查询复杂度**：O(log n) vs 线性查找 O(n)

#### 3.3 区块系统 (Chunk)

将无限世界划分为有限大小的区块（对应 `chunk.dart` + `chunk_manager.dart`）：

```
玩家周围加载 3x3x3 = 27 个区块
超出范围的区块卸载（保留数据缓存）
每个区块内部使用八叉树管理方块
```

### 四、游戏物理

#### 4.1 重力模拟

```dart
if (!isGrounded) {
  velocity.y -= gravity * deltaTime;  // 速度随时间累加
}
velocity.y = max(velocity.y, -maxFallSpeed);  // 限制终端速度
position += velocity * deltaTime;  // 欧拉积分更新位置
```

#### 4.2 AABB 碰撞检测与响应

```dart
// 1. 检测重叠
if (playerAABB.intersects(blockAABB)) {
  // 2. 计算最小重叠向量
  final overlap = playerAABB.calculateOverlap(blockAABB);
  // 3. 沿最小重叠方向推出
  position += overlap;
  // 4. 碰撞方向速度归零
  if (overlap.y > 0) { isGrounded = true; velocity.y = 0; }
}
```

### 五、程序化生成

#### 5.1 噪声函数

确定性伪随机：相同输入 → 相同输出（对应 `world_generator.dart`）：

```dart
static double _simpleNoise(double x, double z) {
  int hash = ((x * 73856093).toInt() ^ (z * 19349663).toInt()) & 0x7FFFFFFF;
  hash = ((hash >> 16) ^ hash) * 0x45d9f3b & 0x7FFFFFFF;
  return (hash & 0x7FFFFFFF) / 0x3FFFFFFF - 1.0;  // [-1, 1]
}
```

#### 5.2 生物群系映射

双噪声轴 → 2D 空间分类：

```
温度 > 0.7 且湿度 < 0.3 → 沙漠
温度 > 0.7 且湿度 ≥ 0.3 → 平原
温度 < 0.3             → 沼泽
湿度 > 0.6             → 森林
其他                   → 平原
```

#### 5.3 跨区块生成

树木等结构可能跨越区块边界，解决方案：
1. 以区块组(3x3x3)为单位预计算所有树木位置
2. 记录每棵树的 AABB 包围盒
3. 生成区块时检查哪些树木与当前区块相交
4. 只生成相交部分的方块

### 六、渲染优化技术

#### 6.1 Greedy Meshing (面合并)

将相邻的同类型面合并为大面，减少绘制调用：

```
优化前: 优化后:
┌─┬─┬─┐   ┌───────┐
│ │ │ │ → │       │
├─┼─┼─┤   ├───────┤
│ │ │ │   │       │
└─┴─┴─┘   └───────┘
12条边 → 4条边
```

算法流程：按类型+法线分组 → 空间索引 → BFS 查找相邻面 → 合并边界

#### 6.2 视锥体裁剪

从 VP 矩阵提取 6 个裁剪平面，测试物体 AABB 是否在视锥体内：

```dart
for (final plane in frustum.planes) {
  // 计算 AABB 在法线方向上的投影半径
  final r = extents.x * |plane.normal.x| + 
            extents.y * |plane.normal.y| + 
            extents.z * |plane.normal.z|;
  // 如果 AABB 中心到平面距离 > 半径 → 完全在外部 → 剔除
  if (plane.distanceTo(center) < -r) return false;
}
```

#### 6.3 遮挡剔除

检查目标方块是否被近处的不透明方块挡住：

```dart
for (final corner in targetAABB.corners) {
  final ray = Ray(origin: camera, direction: corner - camera);
  for (final occluder in occluders) {
    if (ray.intersects(occluder) < distanceToCorner) {
      // 该角点被遮挡
    }
  }
}
// 8个角点全被遮挡 → 完全不可见 → 剔除
```

#### 6.4 区块加载距离管理

```
加载距离: 1 区块 (16 方块)
渲染距离: 16 方块
碰撞检测: 玩家 AABB 扩展 1 方块

加载策略: 玩家进入新区块时，加载周围 3x3x3 区块，卸载远处区块
缓存策略: 已生成的区块保留在内存，返回时直接复用
```

### 七、学习路线建议

```
入门: 向量运算 → 矩阵变换 → 透视投影
进阶: 裁剪剔除 → 深度排序 → 面光照
优化: 八叉树 → 面合并 → 遮挡剔除
扩展: 纹理映射 → 光照传播 → 流体模拟
```
