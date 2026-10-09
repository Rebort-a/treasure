# 架构与依赖边界

Treasure 是面向开发者的 Flutter 游戏实验室。优先保持规则可读、资源所有权明确、模块可以独立修改，不为小游戏强制引入复杂框架。

## 目录与依赖方向

```text
01.home                     应用入口、游戏登记和路由
  ├── 02.lan_chat            房间入口
  └── 03~18.*               独立游戏模块
        ├── upper / page     界面、输入、弹窗和展示协调
        │     ↓
        ├── middle / manager 规则组织、展示状态和动作处理
        │     ↓
        └── base             数据、算法和规则内核

以上模块 → 00.common         共享协议、网络、存储契约与组件
```

- 游戏只能依赖自身和 `00.common`，不能反向引用首页、聊天页面或另一个游戏。
- `04.elemental_battle`、`13.minecraft`、`18.match_three` 的目录分层只允许同层或向下依赖。
- 简单游戏继续采用 `base / manager / page` 文件组织；不进行全仓目录重命名。
- 新增类型优先使用职责明确的名称，避免继续增加不带领域名称的 `Manager`。
- 三消 `base` 是纯 Dart 内核，不引用 Flutter、网络或存储。
- 体素引擎的数据中仍包含 `dart:ui` 颜色类型，渲染依赖 Flutter Canvas；“Dart 自研”不等于整个引擎可脱离 Flutter 运行。数学部分可以单独使用。

规则由 `test/architecture/dependency_boundary_test.dart` 验证，包括相对引用、`package:treasure` 引用、条件导入、导出与 `part`。

## 网络边界与资源所有权

`00.common/network` 的客户端和服务端依赖 `protocol`，不依赖公共界面和导航组件。应用只使用客户端公开入口，不引用 `client/base` 内部实现。

| 对象 | 创建与所有者 | 何时释放 |
|---|---|---|
| `SocketClient` 与房间引擎 | 房间入口 | 离开房间 |
| 单局 Manager | 游戏模块内部的 `OnlineGameHost` | 单局页面卸载 |
| 单局订阅、回调与状态 | 共享引擎的单局生命周期 | 对局结束或释放配置 |
| 规则内核 | 对应游戏 Manager | 随 Manager 释放，不持有连接 |

退出游戏不能顺便关闭房间连接。双人回合使用 `NetTurnEngine`，多人回合使用 `NetMultiTurnEngine`，实时游戏使用 `NetRealEngine`。局内数据以 `gameId` 隔离，传输 ACK 不替代应用层状态同步确认。

详细流程与安全边界见 [network-flow.md](network-flow.md)。

棋盘结束蒙版与悬浮重开按钮由 `widget/component/game_replay_board.dart`
统一显示，不依赖网络。单机传入结束状态与本地重开回调；
`network/widget/round_replay_board.dart` 只适配联机结束、等待匹配和准备状态。
三消奖励结算完毕才显示重开层；五行之战的单机迷宫战斗保留冒险结果回传流程。

## 存储接口与注入

`JsonStore` 仅定义 JSON 对象读写；`StorageService` 提供默认文件实现。插件仍只由原有适配文件导入。

三消只保留本局分数，不读写历史最高分；`MatchManager` 和 `NetMatchManager` 不依赖存储接口。
文件读写行为由 `test/00.common/tool/storage_service_test.dart` 验证。

当前 Web 存储实现是空操作；这是明确的功能限制，不以接口抽象冒充已经支持浏览器持久化。

## 五行之战的职责整理

- `MapProp` 保留库存、道具效果和应用规则，不持有 `BuildContext`、Material 图标或导航闭包。
- 弹窗、战斗控件和含导航职责的战斗协调器放入 `upper`。
- `prop_icon.dart` 在 UI 层将规则映射到图标。
- 回城卷轴通过背包页面的 `onReturnHome` 回调执行；不再把 MazeManager 的闭包写入共享道具模型。
- 页面捕获被使用的道具，选择完成后检查 `mounted`，避免已卸载页面更新状态。
- `base` 和 `middle` 不直接依赖 Material、Widgets 或公共界面组件，该边界由测试约束。

这一步消除了下层对弹窗的依赖，但没有声称完成所有战斗算法的独立化：`upper` 中的战斗协调器仍同时组织交互与战斗时序。后续可逐步提取纯动作结算，而不一次性改写所有模块。

## 第三方依赖隔离

第三方插件应留在现有适配文件。自动化测试维护允许列表，避免新增游戏为了便利直接导入文件选择、路径或版本插件。

ValueNotifier / ValueListenableBuilder 继续作为状态管理方案，不引入 Provider、Riverpod 或新的依赖注入容器。

## 后续重构顺序

1. 为战机、塔防和软体模拟补充可重复的核心行为测试。
2. 用明确的动作或结果数据分离旧 Manager 的核心规则与弹窗、输入和导航。
3. 再根据实测热点拆分大文件，不仅为了行数把紧密相关算法打散。
4. 为公共能力补充最小接入示例；达到接口稳定性要求后，再考虑独立包。

质量检查、性能度量和实机验收见 [quality.md](quality.md)。
