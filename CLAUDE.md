# CLAUDE.md — Treasure

## 项目概述

Flutter 多人局域网游戏合集，支持 11 款单机游戏 + 6 款联机游戏。

## 技术栈

- **框架**: Flutter 3.x (Dart ^3.8.1)
- **状态管理**: ValueNotifier / ListNotifier（无第三方状态管理库）
- **网络**: 自定义 TCP Socket + UDP 广播/组播（无第三方网络库）
- **渲染**: 纯 Dart Canvas 软渲染（Minecraft 3D 引擎）

## 项目结构

```
lib/
├── main.dart                    # 入口
├── 00.common/                   # 通用基础模块
│   ├── engine/                  # 网络引擎（NetworkEngine → NetTurnGameEngine / NetRealGameEngine）
│   ├── game/                    # 游戏通用模型（gamer, map, step, net_turn_game_base）
│   ├── network/                 # 网络通信（Socket, UDP 广播, 消息协议）
│   ├── style/                   # 全局主题
│   ├── tool/                    # 工具类（notifiers, convert_utils, timer_counter）
│   └── widget/                  # 通用 UI 组件
├── 01.home/                     # 首页（房间列表、路由）
├── 02.lan_chat/                 # 局域网聊天
├── 03~13.*                      # 各游戏模块（编号越大越复杂）
```

## 编码约定

- **目录编号前缀**: `00.`~`13.`，数字越小越基础，上层可依赖下层，不可反向
- **游戏模块三层**: `base.dart`（数据）→ `foundation_manager/widget`（通用逻辑/UI）→ `local/net`（单机/联机）
- **联机游戏**: 使用 `NetTurnGameService`（回合制）或 `NetRealGameEngine`（实时）组合
- **状态管理**: 统一使用 `ValueNotifier` + `ValueListenableBuilder`，无 Provider/Riverpod

## 常用命令

```bash
flutter pub get          # 获取依赖
flutter run              # 运行
flutter analyze          # 静态分析
flutter build apk        # 构建 Android
flutter build windows    # 构建 Windows
```
