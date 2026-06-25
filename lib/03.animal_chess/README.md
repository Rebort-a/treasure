# 斗兽棋

## 概述

双人回合制棋类游戏，支持本地对战（玩家/人机）和局域网联机。双方各 8 种动物棋子，初始全部暗置，通过翻牌和移动进行博弈。

## 棋子介绍

| 序号 | 动物 | emoji | 基础分 | 特殊能力 |
|------|------|-------|--------|----------|
| 0 | 象 | 🐘 | 3 | 可入河流；不可过桥；被鼠吃 |
| 1 | 虎 | 🐅 | 1 | — |
| 2 | 狮 | 🦁 | 2 | — |
| 3 | 豹 | 🐆 | 2 | 可攀树 |
| 4 | 狼 | 🐺 | 1 | — |
| 5 | 狗 | 🐕 | 2 | 可入河流 |
| 6 | 猫 | 🐈️ | 1 | 可攀树 |
| 7 | 鼠 | 🐭 | 2 | 可入河流、攀树、过桥；可吃象 |

### 吃子规则

- **常规**：序号小的可以吃掉序号大的，并占据其位置
- **鼠吃象**：鼠(7)可吃象(0)，象(0)不能吃鼠(7)
- **同级互吃**：同类型相遇，双方同归于尽
- **自杀移位**：可以将弱棋移向敌方强棋来弃子

## 地形介绍

| 地形 | 标记 | 可进入的动物 |
|------|------|-------------|
| 陆地 | L | 全部 |
| 河流 | R | 象、狗、鼠 |
| 道路 | O | 全部 |
| 桥 | B | 除象外均可；从河里上桥仅鼠可 |
| 树 | T | 豹、猫、鼠 |

## 棋盘布局

棋盘为 N×N 方格（N = boardLevel×2 + 1，boardLevel 可选 2~6）

```
以 5×5（boardLevel=2）为例：
  L  L  T  L  L
  L  L  O  L  L
  R  R  B  R  R
  L  L  O  L  L
  L  L  T  L  L

中行：中心为桥，其余河流
中列：首尾是树，中心是桥，其余是路
其余格全陆地
```

## 游戏流程

### 初始化

1. 生成 N×N 棋盘，按规则铺设地形
2. 双方各 8 种动物随机放置在陆地格子上
3. 所有棋子初始暗置（背面朝上）

### 回合操作

玩家轮流行动，每回合可执行以下操作之一：

- **翻牌**：选择一个暗置棋子翻开，揭示其种类和归属
- **移动**：选择己方已翻开的棋子，向相邻格子（上下左右）移动
  - 目标为空地：直接移入
  - 目标为敌方棋子：按吃子规则判定胜负
  - 不可移动到己方棋子所在格子
  - 不可移动到暗置棋子所在格子

### 胜负判定

- 当所有暗置棋子翻开后，若一方的明棋全部被吃，则另一方获胜
- 玩家可选择投降

---

## 模块架构

```
03.animal_chess/
├── base.dart               # 数据模型：Animal、Cell、GameAction
├── extension.dart          # CellNotifier 扩展（clearAnimal/revealAnimal/toggleState/placeAnimal）
├── foundation_manager.dart # 基础游戏管理器（棋盘生成、规则判定、操作处理）
├── foundation_widget.dart  # 基础 UI 组件（棋盘渲染、棋子显示、地形着色）
├── intelligence.dart       # AI 控制器（搜索、评估、决策）
├── local_manager.dart      # 本地对战管理器（玩家/AI 切换、AI 延时执行）
├── local_page.dart         # 本地对战页面
├── net_manager.dart        # 联机对战管理器（网络同步、房间管理）
└── net_page.dart           # 联机对战页面
```

### 分层关系

```
base.dart（数据层）
    ↑
extension.dart（数据层扩展）
    ↑
foundation_manager.dart（逻辑层：规则引擎）
    ↑
local_manager.dart / net_manager.dart（逻辑层：模式管理）
    ↑
local_page.dart / net_page.dart（UI 层）

intelligence.dart（独立 AI 模块，依赖 base.dart + 00.common/game）
    ↑
local_manager.dart（AI 集成）
```

### intelligence.dart 内部结构

| 模块 | 类名 | 职责 |
|------|------|------|
| 常量 | `_Constants` | 所有魔法数字集中管理（编码位移、搜索参数、评估权重、分值表） |
| 编码工具 | `_CellUtils` | 单元格编解码 / 吃子判断 / 地形通行 |
| 数据结构 | `BoardInfo` | 棋盘信息（Zobrist 哈希用，故意忽略暗棋位置） |
| 数据结构 | `BoardSnapshot` | 棋盘快照（从 CellView 构建，维护双方视角，增量更新） |
| 哈希缓存 | `_Zobrist` | Zobrist 哈希表（四重对称变换、行动历史、重复检测） |
| 搜索棋盘 | `_SearchBoard` | 可变棋盘（do/undo 模式、走法生成、威胁判断） |
| 评估引擎 | `_Evaluator` | 局面评估（动态分值、材料+局势+机动性） |
| 搜索引擎 | `_SearchEngine` | Minimax + Alpha-Beta 剪枝 / 翻牌评估 |
| 日志工具 | `_AiLog` | 日志输出（棋盘打印、走法格式化、分数格式化） |
| AI 控制器 | `AiController` | 公开 API（决策入口、快照同步、行动应用） |

### 本地对战流程 (`LocalManager`)

```
初始化 → initGame() → _initAiController() → _performAiMove()

玩家回合:
  onCellClick(index)
    → autoProcess(index) → _selectCell → executeAction → endTurn
    → aiCtrl.applyPlayerAction(action)  // 同步 AI 快照

AI 回合:
  endTurn() → currentGamer 切换 → 检测轮到 AI
    → _performAiMove() → 延时 400ms → aiCtrl.getAction() → executeAction

AI 开关:
  toggleAiSwitch() → 开：_initAiController() / 关：_disposeAiController()
```

### 联机对战流程 (`NetManager`)

```
搜索对手 → _onSearch() → initGame() → 发送棋盘数据
连接成功 → _onResource() → 接收棋盘 → resetGameState()
对战中   → onCellClick() → 发送 action 消息
         → _onAction() → 接收对手 action → autoProcess()
投降/断线 → _onExit() → 显示对话框
```



---

## intelligence.dart 详细流程

### 整体架构

```
AiController（公开 API 入口）
    │
    ├── BoardSnapshot（棋盘快照，AI/玩家各一份）
    │     ├── BoardInfo（Zobrist 哈希用数据）
    │     └── _CellUtils（编解码 / 吃子判断 / 地形通行）
    │
    ├── _Zobrist（Zobrist 哈希单例，含四重对称变换）
    │
    ├── _SearchBoard（可变搜索棋盘，do/undo 模式）
    │     ├── _Evaluator（局面评估引擎）
    │     └── _SearchEngine（Minimax + Alpha-Beta 剪枝）
    │
    └── _AiLog（日志工具）
```

### 1. 位编码系统 (`_CellUtils`)

每个格子用一个 `int` 编码，位布局如下：

```
位:  [8..5]      [4..3]       [2..0]
含义: 动物类型    占据状态      地形类型
掩针: 0x07<<5    0x03<<3      0x07
```

占据状态编码：`0`=空, `1`=暗棋, `2`=己方, `3`=敌方

编解码方法：
- `encode(terrain, occupy, animal)` — 组装编码
- `animal(cell)` / `terrain(cell)` — 提取字段
- `isEmpty()` / `isHidden()` / `isSelf()` / `isEnemy()` — 状态判断

### 2. 吃子判断 (`_CellUtils.canEat`)

```
attacker == defender         → true（同级互吃，双方同归于尽）
attacker == mouse && defender == elephant → true（鼠吃象）
attacker == elephant && defender == mouse → false（象不能吃鼠）
attacker.index < defender.index → true（常规：小吃大）
其他 → false
```

### 3. 地形通行 (`_CellUtils.canEnterTerrain`)

```
河流(river) → 仅象、狗、鼠可入
桥(bridge)  → 从河里上桥：仅鼠可；其他情况：除象外均可
树(tree)    → 仅豹、猫、鼠可攀
其他地形    → 全部可入
```

### 4. 棋盘快照 (`BoardSnapshot`)

从真实棋盘构建，维护两份视角：

| 字段 | 含义 |
|------|------|
| `situation` | N×N 一维数组，每个元素是位编码后的格子状态 |
| `selfVisible` | 己方明棋 `{AnimalType → 位置索引}` |
| `enemyVisible` | 敌方明棋 `{AnimalType → 位置索引}` |
| `selfHidden` | 己方暗棋类型列表（尚未翻开的己方动物） |
| `enemyHidden` | 敌方暗棋类型列表（尚未翻开的敌方动物） |

构建过程 (`_buildFrom`)：
1. 遍历棋盘每个格子
2. 暗棋 → 记录到 `selfTypeSet` / `enemyTypeSet`
3. 明棋 → 记录到 `selfVisible` / `enemyVisible`
4. 不在暗棋集合且不在明棋集合的类型 → 归入 hidden 列表

增量更新：
- `applyFlip(index, terrain, type, owner)` — 翻牌：从 hidden 移到 visible
- `applyMove(from, to, fromType, fromOwner, toAnimal?)` — 移动：处理吃子/互吃/空移

### 5. Zobrist 哈希 (`_Zobrist`)

单例模式，用于缓存搜索结果、加速重复局面决策。

**哈希计算**（位置相关，确保对称变体产生不同哈希）：
```
hash = 0
for 每个格子 i:
    hash ^= _cellKeys[i][cellToCode(situation[i])] ^ i
for 每个 selfHidden 类型:
    hash ^= _selfHiddenKeys[type.index]
for 每个 enemyHidden 类型:
    hash ^= _enemyHiddenKeys[type.index]
```

`cellToCode` 映射：空→0, 暗棋→17, 己方明棋→animal+1, 敌方明棋→animal+9

**四重对称存储**：存入一条记录时，同时存储水平镜像、垂直镜像、180° 旋转三个变体，共 4 条记录。

**行动历史**：滑动窗口记录最近 10 步 AI 行动，用于重复检测（同一 (hash, action) 出现 ≥2 次则视为重复）。

### 6. 搜索棋盘 (`_SearchBoard`)

从 `BoardSnapshot` 构建的可变副本，支持 do/undo 操作用于搜索。

**走法生成** (`generateMoves`，`includeFlips` 参数控制是否含翻牌)：

```
1. 翻牌（includeFlips=true 时）：遍历所有暗棋位置，每个生成一个 FlipAction
2. 移动：遍历己方所有明棋
   for 每个明棋 (type, pos):
       for 四个方向 (上/下/左/右):
           - 越界检查
           - 跳过暗棋目标
           - 跳过己方棋子目标
           - 地形通行检查
           - 敌方棋子 → 加入 captures 列表
           - 空地 → 加入 moves 列表
3. captures 按被吃棋子基础分降序排序（吃子走法优先）
4. 返回 captures + moves
```

**威胁判断** (`isThreatened`)：

```
for 每个相邻格子:
    if 是敌方棋子 && 能吃我 && 能进入我的地形:
        return true
return false
```

特殊处理：在树上的非攀树动物不被视为受威胁（敌方无法上树吃它）。

**do/undo 机制**：
- `doMove(from, to)` → 返回 `_MoveUndo`（保存 from/to 的 cell 值）
- `undoMove(undo)` → 恢复 cell + `_rebuildPositions()` 重建位置映射
- `doFlip(index)` → 返回 `_FlipUndo`（保存 cell 值 + hidden 列表快照）
- `undoFlip(index, undo)` → 恢复 cell + hidden 列表 + `_rebuildPositions()`

### 7. 局面评估 (`_Evaluator`)

**动态分值计算** (`calcDynamicScores`)：

对每个己方明棋，计算其"动态分值" = 总分(16) - 威胁扣分。

```
for 每个己方明棋 type:
    penalty = 0
    for 每个敌方类型 eType（明棋 + 暗棋）:
        if eType 能吃 type:
            if type 也能吃 eType:
                penalty += baseScores[eType] × 0.5  （互吃威胁，半扣）
            else:
                penalty += baseScores[eType] × 1.0  （单向威胁，全扣）
    dynamicScore[type] = 16 - penalty
```

核心思想：己方棋子被越多敌方棋子威胁，动态分值越低。如果能互吃（如鼠对象），威胁减半。

**局面总分** (`_calc`)：

```
总分 = 材料分 + 局势分 + 机动性分
```

- **材料分**：己方明棋动态分 + 己方暗棋基础分 - 敌方明棋动态分 - 敌方暗棋基础分
- **局势分**：遍历所有明棋，受威胁者按 `动态分值 × 0.9` 扣分（己方扣、敌方加分）
- **机动性分**：`(己方合法走法数 - 敌方合法走法数) × 0.1`

终局判定：
- 己方无明棋 → 返回 -100000（必败）
- 敌方无明棋 → 返回 +100000（必胜）

### 8. 搜索引擎 (`_SearchEngine`)

**Minimax + Alpha-Beta 剪枝** (`_minimax`)：

```
function minimax(board, depth, alpha, beta, isMax):
    if depth == 0: return evaluate(board)
    moves = generateMoves(当前方, includeFlips: false)
    if moves 为空: return evaluate(board)

    for 每个 move:
        执行 move → minimax(depth-1, alpha, beta, !isMax) → 撤销 move
        更新 alpha/beta
        if beta <= alpha: 剪枝

    return 最优值
```

- 搜索深度：4 层（`_Constants.searchDepth`）
- 顶层 (`searchMoves`)：对每个候选移动执行 minimax，返回 `(action, score)` 列表按分数降序

**翻牌评估** (`evaluateFlipBenefit`)：

综合三个因素评估每个暗棋位置的翻牌收益：

1. **邻域明棋评估**（权重最高）：
   - 遍历暗棋位置的四个邻居
   - 己方暗棋：如果翻出后会被敌方邻居吃 → 负价值；否则正价值
   - 敌方暗棋：如果翻出后能被己方邻居吃 → 正价值；否则负价值
   - 概率加权：每种暗棋出现概率 = 1 / 总暗棋数

2. **地形匹配**：
   - 邻居有河 → 能入河的暗棋（象、狗、鼠）+0.8 分/个
   - 邻居有树 → 能上树的暗棋（豹、猫、鼠）+0.8 分/个
   - 邻居有桥 → +0.3 分（战略要道）
   - 边角位置 → -0.5 分（移动方向少）

3. **距离因素**：
   - 到最近明棋的 Manhattan 距离
   - 距离 1=+1.0, 距离 2=+0.5, 距离 3=+0.33, 距离 4=+0.25
   - 乘以 0.5 权重

**最终收益** = 邻域评估 + 地形加成 + 距离加成 × 0.5

### 9. AI 控制器 (`AiController`) — 决策主流程

```
getAction():
  │
  ├─ 1. 无明棋（双方都无可见棋子）
  │     └─ 随机选一个暗棋位置翻牌
  │
  ├─ 2. Zobrist 查表命中
  │     └─ 直接返回缓存走法
  │
  ├─ 3. Minimax 搜索（只搜索明棋移动）
  │     ├─ 构建 _SearchBoard
  │     ├─ 评估当前局面（日志输出）
  │     ├─ searchMoves → 得到 (action, score) 列表
  │     └─ 跳过重复行动（Zobrist 历史检测）
  │
  ├─ 4. 有暗棋 → 评估翻牌收益
  │     ├─ evaluateFlipBenefit → (bestFlip, flipBenefit)
  │     └─ 比较：flipBenefit > moveScore - currentScore ?
  │           ├─ 是 → 返回翻牌
  │           └─ 否 → 返回最佳移动
  │
  └─ 5. 无可用行动 → 返回 null
```

**行动后更新** (`_updateSnapshot`)：
- 翻牌：两个快照都执行 `applyFlip`
- 移动：两个快照都执行 `applyMove`（自动处理视角差异）

**玩家行动同步** (`applyPlayerAction`)：
- 将玩家走法存入 Zobrist 表
- 更新两个快照

---

## 已知问题

### ✅ 已修复：四重对称存储

Zobrist 哈希改为位置相关（`hash ^= _cellKeys[i][code] ^ i`），确保同一棋子在不同位置产生不同哈希值，使四重对称变体各自拥有独立哈希。`store` 存入 4 条记录，`lookup` 尝试 4 个变体查找。

### ✅ 已修复：走法生成代码重复

`generateMoves` 和 `generateMovesOnly` 合并为一个方法，通过 `includeFlips` 参数控制是否包含翻牌走法。

### ✅ 已修复：`doMove` 暗棋目标处理

添加暗棋目标守卫，遇到暗棋目标直接返回 undo，不再覆盖暗棋。

### ✅ 已修复：`_rand64` 随机数质量

改为三段拼接（22+21+21 位），生成完整 64 位随机数。

### 🟡 中等：`_buildFrom` 的 hidden 列表对中途创建快照不准确

游戏中途 toggle AI 时，已阵亡的动物既不在暗棋集合也不在明棋集合，会被错误地加入 hidden 列表。影响 Zobrist 哈希和翻牌评估的准确性。

### 🔵 设计说明

- **Zobrist 哈希表 AI/玩家共享**：有意设计，目的是让 AI 学习玩家的行为模式。
- **`_Zobrist` 全局单例跨局共享**：有意设计，AI 可以跨局学习。
