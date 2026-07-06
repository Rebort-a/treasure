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

> 序号越小越强：象(0) < 虎(1) < 狮(2) < 豹(3) < 狼(4) < 狗(5) < 猫(6) < 鼠(7)

### 吃子规则

- **常规**：序号小的可以吃掉序号大的（如虎1可吃狮2），并占据其位置
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
base.dart（数据层：Animal、Cell、GameAction、Rules）
    ↑
extension.dart（数据层扩展：CellNotifier）
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
| 编解码 | `CellCodec` | 格子位编码/解码（占据状态、动物类型、地形） |
| 常量 | `EvalParams` | 所有魔法数字集中管理（搜索参数、评估权重、翻牌权重、分值表） |
| 数据结构 | `BoardInfo` | Zobrist 哈希用数据（size, situation, selfHidden, enemyHidden, hash） |
| 数据结构 | `BoardState` | 棋盘状态基类（applyFlip/applyMove/forEachNeighbor，维护双方视角） |
| 数据结构 | `BoardSnapshot` | 棋盘快照 extends BoardState（从 CellView 构建，额外维护 BoardInfo） |
| 数据结构 | `EvalResult` | 评估结果（总分、材料、局势、机动性、双方动态分） |
| 哈希缓存 | `ZobristHash` | Zobrist 哈希表（四重对称变换、行动历史、重复检测） |
| 搜索棋盘 | `SearchBoard` | 可变棋盘 extends BoardState（do/undo 模式、走法生成、威胁判断） |
| 评估引擎 | `Evaluator` | 局面评估（动态分值、材料+局势+机动性） |
| 搜索引擎 | `SearchEngine` | Minimax + Alpha-Beta 剪枝 / 翻牌评估 |
| 日志工具 | `_AiLog` | 日志输出（棋盘打印、走法格式化） |
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
    ├── BoardSnapshot extends BoardState（棋盘快照，AI/玩家各一份）
    │     ├── BoardInfo（Zobrist 哈希用数据）
    │     ├── BoardState（基类：applyFlip/applyMove/forEachNeighbor）
    │     └── CellCodec（位编解码）
    │
    ├── ZobristHash（Zobrist 哈希单例，含四重对称变换）
    │
    ├── SearchBoard extends BoardState（可变搜索棋盘，do/undo 模式）
    │     ├── Evaluator（局面评估引擎）
    │     └── SearchEngine（Minimax + Alpha-Beta 剪枝）
    │
    ├── EvalParams（常量参数）
    │
    └── _AiLog（日志工具）
```

### 1. 位编码系统 (`CellCodec`)

每个格子用一个 `int` 编码，位布局如下：

```
位:  [8..5]      [4..3]       [2..0]
含义: 动物类型    占据状态      地形类型
掩码: 0x07<<5    0x03<<3      0x07
```

占据状态编码：`0`=空, `1`=暗棋, `2`=己方, `3`=敌方

编解码方法：
- `encode(terrain, occupy, animal)` — 组装编码
- `animal(cell)` / `terrain(cell)` — 提取字段
- `isEmpty()` / `isHidden()` / `isSelf()` / `isEnemy()` — 状态判断（内部复用 `occupy()` 提取占据字段）

### 2. 吃子判断 (`Rules.canEat`)

使用 `switch` expression 模式匹配：
```
(attacker, defender) 同级  → true（同归于尽）
(mouse, elephant)         → true（鼠吃象）
(elephant, mouse)         → false（象不能吃鼠）
其他: attacker.index < defender.index → true（常规：小吃大）
```

### 3. 地形通行 (`Rules.canEnter`)

使用 `switch` expression：
```
河流(river) → 仅象、狗、鼠可入
桥(bridge)  → 从河里上桥：仅鼠可；其他情况：除象外均可
树(tree)    → 仅豹、猫、鼠可攀
其他地形    → 全部可入
```

### 4. 棋盘状态基类 (`BoardState`)

公共父类，`BoardSnapshot` 和 `SearchBoard` 均继承此类：

- `applyFlip(index, type, isSelf)` — 翻牌：更新局势、从 hidden 移到 visible/pos
- `applyMove(from, to)` — 移动：空移改位置，有敌方棋子按吃子规则判定
- `forEachNeighbor(pos, fn)` — 遍历 pos 的所有有效邻居索引

### 5. 棋盘快照 (`BoardSnapshot extends BoardState`)

从真实棋盘构建，额外维护 `BoardInfo` 用于 Zobrist 哈希：

| 字段 | 含义 |
|------|------|
| `situation` | N×N 一维数组，每个元素是位编码后的格子状态 |
| `selfPos` | 己方明棋 `{AnimalType → 位置索引}` |
| `enemyPos` | 敌方明棋 `{AnimalType → 位置索引}` |
| `selfHidden` | 己方暗棋类型列表（尚未翻开的己方动物） |
| `enemyHidden` | 敌方暗棋类型列表（尚未翻开的敌方动物） |
| `hiddenPositions` | 所有暗棋的位置索引列表 |

**构建过程** (`_initFromBoard`)：
1. 遍历棋盘每个格子
2. 暗棋 → 记录到 `selfTypes` / `enemyTypes` 集合，加入 `hiddenPositions`
3. 明棋 → 记录到 `selfPos` / `enemyPos`（`{AnimalType → 位置}`）
4. 所有 8 种动物中，不在明棋 pos 且不在暗棋集合的类型 → 归入 `selfHidden` / `enemyHidden`

增量更新（继承自 `BoardState`）：
- `applyFlip(index, type, isSelf)` — 翻牌：从 hidden 移到 pos，更新 situation
- `applyMove(from, to)` — 移动：自动判断空移/吃子/互吃，更新 situation 和 pos

### 6. Zobrist 哈希 (`ZobristHash`)

单例模式，用于缓存搜索结果、加速重复局面决策。

**哈希计算**（位置相关，确保对称变体产生不同哈希）：
```
hash = 0
for 每个格子 i:
    hash ^= _cellKeys[i][cellCode(situation[i])] ^ i
for 每个 selfHidden 类型:
    hash ^= _selfKeys[type.index]
for 每个 enemyHidden 类型:
    hash ^= _enemyKeys[type.index]
```

`cellCode` 映射：空→0, 暗棋→17, 己方明棋→animal+1, 敌方明棋→animal+9

**四重对称存储**：存入一条记录时，同时存储水平镜像、垂直镜像、180° 旋转三个变体，共 4 条记录。

**行动历史**：滑动窗口记录最近 6 步 AI 行动，用于重复检测（同一 (hash, action) 出现 ≥2 次则视为重复）。

### 7. 搜索棋盘 (`SearchBoard extends BoardState`)

从 `BoardSnapshot` 构建的可变副本，支持 do/undo 操作用于搜索。

**邻居遍历** (`forEachNeighbor`)：统一的边界安全遍历，消除各处重复的越界检查。

**走法生成** (`generateMoves`，`includeFlips` 参数控制是否含翻牌)：

```
1. 翻牌（includeFlips=true 时）：遍历所有暗棋位置，每个生成一个 FlipAction
2. 移动：遍历己方所有明棋
   for 每个明棋 (type, from):
       forEachNeighbor(from, (to) {
           - 跳过暗棋目标
           - 跳过己方棋子目标
           - 地形通行检查
           - 敌方棋子 && 能吃 → 加入 captures 列表
           - 空地 → 加入 moves 列表
       })
3. captures 按被吃棋子基础分降序排序（吃子走法优先）
4. 返回 captures + moves
```

**威胁判断** (`isThreatened`)：

```
forEachNeighbor(pos, (ni) {
    if 已找到威胁 → 跳过
    if 空/暗棋 → 跳过
    if 己方棋子（按视角）→ 跳过
    if 能吃 && 能进入地形 → 标记威胁
})
```

**do/undo 机制**（使用 Dart record，无专用类）：
- `withMove(action, fn)` → do → 回调 → undo
- `withFlip(action, fn)` → do → 回调 → undo
- 内部 `_doMove`/`_doFlip` 返回 record，`_undoMove`/`_undoFlip` 恢复状态

### 8. 局面评估 (`Evaluator`)

**动态分值计算** (`calcDynamicScores`)：

对每个己方明棋，计算其"动态分值" = 总分(16) - 威胁扣分。使用 `fold` 函数式累加。

```
for 每个己方明棋 type:
    penalty = 所有敌方类型(eType) 的 fold 累加:
        if eType 能吃 type:
            if type 也能吃 eType → penalty += baseScores[eType] × 0.5（互吃，半扣）
            else → penalty += baseScores[eType] × 1.0（单向，全扣）
    dynamicScore[type] = 16 - penalty
```

核心思想：己方棋子被越多敌方棋子威胁，动态分值越低。如果能互吃（如象对象），威胁减半。

**局面总分** (`_calc`)：

```
总分 = 材料分 + 局势分 + 机动性分
```

- **材料分**：`_sum(selfPos, selfD) - _sum(enemyPos, enemyD) + _sumBase(selfH) - _sumBase(enemyH)`
- **局势分**：遍历所有明棋，受威胁者按 `动态分值 × positionWeight(0.3)` 扣分（己方扣、敌方加分）
- **机动性分**：`(己方合法走法数 - 敌方合法走法数) × mobilityWeight(0.1)`

终局判定：
- 己方无明棋 → 返回 -100000（必败）
- 敌方无明棋 → 返回 +100000（必胜）

### 9. 搜索引擎 (`SearchEngine`)

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

- 搜索深度：6 层（`EvalParams.searchDepth`）
- 顶层 (`searchMoves`)：对每个候选移动执行 minimax，返回 `(action, score)` 列表按分数降序
- 使用 `_execAndEval` + `switch` expression 统一处理 MoveAction/FlipAction

**翻牌评估** (`evaluateFlipBenefit`)：

综合三个因素评估每个暗棋位置的翻牌收益，**三因素均双面化**：

1. **邻域明棋评估**（权重最高）：
   - 遍历暗棋位置的四个邻居
   - 己方暗棋：如果翻出后会被敌方邻居吃 → 负价值；否则正价值
   - 敌方暗棋：如果翻出后能被己方邻居吃 → 正价值；否则负价值
   - 概率加权：每种暗棋出现概率 = 1 / 总暗棋数
   - **同类型抵消**：己方和敌方都有的暗棋类型跳过（一正一负抵消）

2. **地形匹配**（`EvalParams.flipTerrainWeight=0.8`）：
   - **双面化**：己方暗棋需要地形 → 正价值；敌方暗棋需要地形 → 负价值
   - 邻居有河 → 己方能入河的暗棋（象、狗、鼠）加分，敌方能入河的扣分
   - 邻居有树 → 己方能攀树的暗棋（豹、猫、鼠）加分，敌方能攀树的扣分
   - 邻居有桥 → +`flipBridgeBonus`(0.3) 分（战略要道）
   - 边角位置 → +`flipCornerPenalty`(-0.5) 分（移动方向少）
   - **同类型抵消**：双方都有的地形适配类型跳过

3. **距离因素**：
   - **双面化**：离己方明棋近 → 正价值；离敌方明棋近 → 负价值
   - Manhattan 距离 1=+1.0, 距离 2=+0.5, 距离 3=+0.33, 距离 4=+0.25
   - 乘以 `flipDistanceWeight`(0.5) 权重

**最终收益** = 邻域评估 + 地形加成 + 距离加成 × `flipDistanceWeight`

**设计意图**：
- 翻牌是双向的：可能翻出己方棋子，也可能翻出敌方棋子
- 评估应反映"翻出后对双方的影响"，而非只看单方
- 同类型抵消优化：减少无意义计算

### 10. AI 控制器 (`AiController`) — 决策主流程

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
  │     ├─ 构建 SearchBoard
  │     ├─ Evaluator.logEvaluate 评估当前局面
  │     ├─ SearchEngine.searchMoves → 得到 (action, score) 列表
  │     └─ 跳过重复行动（Zobrist 历史检测）
  │
  ├─ 4. 有暗棋 → 评估翻牌收益
  │     ├─ SearchEngine.evaluateFlipBenefit → (bestFlip, flipBenefit)
  │     └─ 比较：moveScore <= 0 && flipBenefit > moveScore ?
  │           ├─ 是 → 返回翻牌
  │           └─ 否 → 返回最佳移动
  │
  └─ 5. 无可用行动 → 返回 null
```

**行动后更新**（`_updateSnapshot`，统一处理 AI 和玩家）：

- **翻牌**：从 `board[index].animal!` 读取翻出结果，分别更新两个快照
  - `aiSnapshot.applyFlip(index, type, isSelf)` — AI 视角
  - `playerSnapshot.applyFlip(index, type, !isSelf)` — 玩家视角（相反）
- **移动**：`aiSnapshot.applyMove(from, to)` + `playerSnapshot.applyMove(from, to)`
  - `BoardState.applyMove` 自动从 situation 判断目标状态（空移/吃子/互吃）

**玩家行动同步** (`applyPlayerAction`)：
- 将玩家走法存入 Zobrist 表
- 调用 `_updateSnapshot` 更新两个快照

---

### 🔵 设计说明

- **Zobrist 哈希表 AI/玩家共享**：有意设计，目的是让 AI 学习玩家的行为模式。
- **Zobrist 全局单例跨局共享**：有意设计，AI 可以跨局学习。
- **BoardInfo没有暗棋的具体信息**：有意设计，刻意模糊暗棋具体的位置信息，等同玩家眼中的棋局。
