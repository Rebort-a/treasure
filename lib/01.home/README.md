# 首页模块

## 职责划分

- `base/created_room_info.dart`：已创建房间的数据模型，不承载界面协调逻辑。
- `middle/home_state.dart`：首页响应式状态、最近使用记录的读取与保存，不依赖界面上下文。
- `middle/room_manager.dart`：房间发现、房间列表维护、本地房间创建与停止、服务端成员监听及资源释放。
- `middle/background_settings.dart`：背景校验、持久化和响应式状态。
- `middle/player_settings.dart`：玩家资料的读取、保存和响应式状态。
- `upper/home_page.dart`：首页入口，组合标签页、同步滑动与导航选择，管理首页资源的生命周期。
- `upper/home_manager.dart`：联机界面协调器，只负责入房弹窗、路由和连接交接；通过组合 `HomeRoomManager` 使用房间业务能力。
- `upper/pages/`：应用、联机、设置三个无状态标签页。
- `upper/widgets/`：导航栏、背景、保活包装、标题及房间弹窗等组件。
- `upper/route.dart`：本地应用与联机聊天室的路由装配。

依赖方向为 `upper → middle → base`，上层也可以直接读取数据模型；下层不得依赖上层。`middle` 不导入界面组件，不持有 `BuildContext`，也不承担弹窗或路由职责。不要按文件数量平均分层，按实际职责划分。

## 状态与生命周期

首页的标签选择、搜索条件、最近应用和背景操作状态使用 `ValueNotifier` / `ListNotifier`，展示组件通过 `ValueListenableBuilder` 局部更新，不使用整页 `setState`。

`StatelessWidget` 不等于没有状态：状态可以来自外部可观察对象。也不应仅为减少 `StatefulWidget` 数量，将资源生命周期改为全局状态：

- `HomePage` 的 `State` 创建并释放 `HomeState`、`PageController` 和 `HomeManager`，注入的管理器也由首页接管，保持原有约定。
- `HomeManager` 释放待加入连接与导航通知器，并委托 `HomeRoomManager` 停止房间发现、移除成员监听、关闭服务端和释放房间列表通知器。
- `HomeTabPage` 使用 `AutomaticKeepAliveClientMixin` 保留已访问标签页的组件状态，包括输入控件和滚动位置；保活不意味着禁止重新执行 `build`。
- `JoinRoomDialog` 管理入房请求、取消及连接交接，继续使用自身生命周期状态。

新的标签页优先使用无状态组件和外部可观察状态；确实需要控制器、保活或异步资源释放时，保留必要的有状态组件。
