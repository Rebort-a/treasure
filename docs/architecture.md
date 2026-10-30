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

`01.home/route.dart` 是应用登记与路由装配点，仍属于界面入口层；首页的 `base`、`middle` 不得反向引用它。首页标签页位于 `upper/pages`，房间弹窗位于 `upper/dialogs`，首页专属展示组件位于 `upper/widgets`。

共享目录按职责分类：`sound` 集中声音事件、音效与音乐播放、音频偏好及其平台存储适配；`service` 保留通用存储和玩家资料设置；`image` 集中图片处理工具；网络方案配置位于 `network/network_config.dart`。通用悬浮导航栏位于 `widget/navigator`，音频页面生命周期容器仍位于 `widget/component`。

- 游戏只能依赖自身和 `00.common`，不能反向引用首页、聊天页面或另一个游戏。
- `04.elemental_battle`、`13.minecraft`、`18.match_three` 的目录分层只允许同层或向下依赖。
- 简单游戏采用 `base / manager / page` 文件组织。
- 新增类型优先使用职责明确的名称，避免继续增加不带领域名称的 `Manager`。
- 仅被一个游戏使用的领域类型留在该模块；五行实体与移动规则位于 `04.elemental_battle/base/entity.dart`，实体展示位于 `upper/maze_entity_view.dart`。公共层仅保留可复用的方向、邻接数据和图片切分工具。
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
三消奖励结算完毕才显示重开层；塔防与坦克单机也复用该结束层，阻止结束后继续操作旧棋盘。五行之战的单机迷宫战斗保留冒险结果回传流程。

结束展示不等于联机重开协议。坦克实时联机保留结果与返回房间操作，没有本地重开按钮；不能通过重置本机状态冒充双方新一局。

## 存储接口与注入

`JsonStore` 定义 JSON 对象读写，`StorageService` 提供默认文件实现。读取保留安全回退；原生写入、删除失败通过 Future 传播，不能把失败当作保存成功。偏好和自动保存入口捕获并记录失败，背景设置仅在保存成功后更新展示状态。

`StorageService.update` 将同一 `(project, name)` 文档的读取、同步修改、写入串行执行，语言、主题和玩家名称更新同一设置文件时不会互相覆盖。普通读取、整文档写入与删除使用同一队列，避免 Windows 上读取尚未关闭时替换文件失败；一次失败不阻断后续操作。更新遇到损坏文件会失败，不以空对象静默覆盖原文件。

三消只保留本局分数，不读写历史最高分；`MatchManager` 和 `NetMatchManager` 不依赖存储接口。
文件读写行为由 `test/00.common/tool/storage_service_test.dart` 验证。

`StorageService` 在 Web 上不读写数据；音频偏好通过 `AudioSettingsStore` 使用浏览器 localStorage。

## 五行之战的职责

- `MapProp` 保留库存、道具效果和应用规则，不持有 `BuildContext`、Material 图标或导航闭包。
- 弹窗、战斗控件和含导航职责的战斗协调器放入 `upper`。
- `prop_icon.dart` 在 UI 层将规则映射到图标。
- 回城卷轴通过背包页面的 `onReturnHome` 回调执行，共享道具模型不持有导航闭包。
- 页面捕获被使用的道具，选择完成后检查 `mounted`，避免已卸载页面更新状态。
- `base` 和 `middle` 不直接依赖 Material、Widgets 或公共界面组件，该边界由测试约束。

`upper` 中的战斗协调器同时组织交互与战斗时序。

## 第三方依赖隔离

第三方插件集中在文件选择、存储、版本和网络等适配入口，游戏规则与算法不依赖插件。

ValueNotifier / ValueListenableBuilder 继续作为状态管理方案，不引入 Provider、Riverpod 或新的依赖注入容器。

离散业务状态保持单一来源，例如棋类的 AI 模式与难度由 Manager 持有，页面不再维护副本。页面创建并释放自身 Manager、导航通知器和控制器；Manager 释放自建通知器与任务，不释放借用对象。重开或退出使旧异步任务失效，旧任务不得修改新局状态。

具体弹窗、庆祝布局和导入路由属于页面；规则 Manager 暴露状态与动作，不持有 `BuildContext`。实时绘制可保留轻量帧级 Listenable：体素将场景、破坏进度、快捷栏分别通知，只重建相应区域，不为每帧重建整页。动画和输入控制器的局部状态不必机械改写为业务通知器。

通用媒体插件适配位于 `service/media_file_picker.dart`，首页与聊天均从此入口使用，不从聊天 UI 导入文件选择能力。聊天日期在展示时使用当前语言，原始网络消息不存储翻译后的日期或通知文本。

质量检查、性能度量和实机验收见 [quality.md](quality.md)。
