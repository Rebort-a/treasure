<p align="center">
  <h1 align="center">🏴‍☠️ Treasure</h1>
  <p align="center">
    <b>A cross-platform multiplayer game collection built with Flutter</b><br/>
    <i>跨平台多人游戏合集 — 纯 Dart，零依赖</i>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20Linux-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/🎮_11_Local_Games-FF6B6B?style=for-the-badge" alt="11 Local Games">
  <img src="https://img.shields.io/badge/🌐_5_LAN_Games_%2B_1_Chat-4ECDC4?style=for-the-badge" alt="5 LAN Games + 1 Chat">
  <img src="https://img.shields.io/badge/🖥️_Pure_Dart_3D_Engine-9B59B6?style=for-the-badge" alt="Pure Dart 3D Engine">
  <img src="https://img.shields.io/badge/📡_Zero_Config_LAN_Play-2ECC71?style=for-the-badge" alt="Zero Config LAN">
  <img src="https://img.shields.io/badge/📦_Near_Zero_Dependencies-F39C12?style=for-the-badge" alt="Near Zero Dependencies">
</p>

---

## 🎮 Play Now | 立即体验

> **👉 [Click here to play in browser](https://rebort-a.github.io/OnePiece/)** 👈
>
> No install. No download. Just open and play.
>
> 无需安装，无需下载，打开即玩。

<!-- TODO: Add screenshots or GIF -->
<!-- ![Game Preview](docs/preview.gif) -->

---

## 💡 What Is This? | 这是什么？

**Treasure** is a cross-platform multiplayer game collection built entirely with Flutter. **11 local games + 5 LAN multiplayer games + 1 chat room** — all written in pure Dart with near-zero third-party dependencies.

**Treasure** 是一个完全用 Flutter 构建的跨平台多人游戏合集。**11 款单机游戏 + 5 款局域网联机游戏 + 1 个聊天室** — 纯 Dart 编写，几乎零第三方依赖。

### Highlights | 亮点

| Feature | 特性 | Description |
|---------|------|-------------|
| 🧩 **From Scratch** | **从零开始** | Socket networking, 3D renderer, physics engine — all hand-written |
| 🌐 **LAN Multiplayer** | **局域网联机** | UDP broadcast/multicast room discovery. Same WiFi = instant play |
| 🎮 **16 Games** | **16 款游戏** | Board games, action, RPG, 3D voxel world, physics simulation |
| 🖥️ **Cross-Platform** | **跨平台** | Android, iOS, Web, Windows, Linux |
| 📦 **Minimal Dependencies** | **极少依赖** | Only `cupertino_icons`, `web_socket_channel`, `http` |

---

## 📦 Game List | 游戏列表

### Board Games | 棋类

| # | Game | 游戏 | Mode | Description |
|---|------|------|------|-------------|
| 03 | **Animal Chess** | 斗兽棋 | Local + LAN | Classic animal chess with hidden piece reveal |
| 05 | **Gobang** | 五子棋 | Local + LAN | Five-in-a-row with undo support |
| 07 | **Go** | 围棋 | Local + LAN | Full rules: capture, ko, suicide prevention |

### Action Games | 动作游戏

| # | Game | 游戏 | Mode | Description |
|---|------|------|------|-------------|
| 06 | **Greedy Snake** | 贪吃蛇 | Local + LAN | Multiplayer snake with spatial grid collision |
| 11 | **Spaceship** | 太空飞船 | Local | Top-down shooter with bosses, props, achievements |

### Simulation | 模拟

| # | Game | 游戏 | Mode | Description |
|---|------|------|------|-------------|
| 04 | **Elemental Battle** | 元素之战 | Local + LAN | Five-element RPG with 25 unique skills |
| 12 | **Soft Body** | 软体模拟 | Local | Spring-mass physics (Euler/Verlet integration) |
| 13 | **Minecraft** | 我的世界 | Local | Pure Dart 3D voxel engine with procedural world |

### Puzzle | 益智

| # | Game | 游戏 | Mode | Description |
|---|------|------|------|-------------|
| 08 | **Sudoku** | 数独 | Local | Auto-generated puzzles |
| 09 | **Guess** | 猜词 | Local | Emoji word guessing |
| 10 | **Three Tiles** | 三消麻将 | Local | Tile-matching puzzle with props |

### Other | 其他

| # | Game | 游戏 | Mode | Description |
|---|------|------|------|-------------|
| 02 | **LAN Chat** | 局域网聊天 | LAN | Pure text chat room |

---

## 🏗️ Architecture | 架构设计

All modules follow a consistent **three-layer architecture**:

所有模块遵循统一的**三层架构**：

```
┌─────────────────────────────────────────────────┐
│  upper/     UI pages, rendering, user interaction │
│             UI 页面、渲染、用户交互                 │
├─────────────────────────────────────────────────┤
│  middle/    Business logic, algorithms, rules     │
│             业务逻辑、算法、游戏规则                 │
├─────────────────────────────────────────────────┤
│  base/      Data models, constants, definitions   │
│             数据模型、常量、核心定义                 │
└─────────────────────────────────────────────────┘
```

```
lib/
├── 00.common/       # Shared modules (engine, network, widgets)
│   ├── engine/      # Network engines (base, turn-based, real-time)
│   ├── network/     # UDP/TCP/WebSocket, encryption, room discovery
│   └── widget/      # Reusable UI components
├── 01.home/         # Home page
├── 02.lan_chat/     # LAN chat room
├── 03.animal_chess/ # 斗兽棋
├── ...
└── 13.minecraft/    # 3D voxel engine
```

Each game module follows a consistent pattern:

每个游戏模块遵循统一结构：

```
├── base.dart               # Data models | 数据模型
├── foundation_manager.dart # Shared logic | 通用逻辑
├── local_manager.dart      # Local mode logic | 单机逻辑
├── local_page.dart         # Local mode UI | 单机界面
├── net_manager.dart        # LAN mode logic | 联机逻辑
└── net_page.dart           # LAN mode UI | 联机界面
```

---

## 🌐 Network Architecture | 网络架构

Dual network mode, switchable via one line in `config/network_config.dart`:

双网络方案，通过 `config/network_config.dart` 一行切换：

```dart
const NetworkMode networkMode = NetworkMode.socket;     // TCP + UDP (native)
const NetworkMode networkMode = NetworkMode.webSocket;   // WebSocket (Web)
```

```
┌───────────────────────────────────────────────────────┐
│  Application Layer | 应用层                             │
│  NetworkEngine / NetTurnGameEngine / NetRealGameEngine │
├───────────────────────────────────────────────────────┤
│  Message Protocol | 消息协议层                           │
│  NetworkMessage (JSON + XOR encryption)                │
├───────────────────────────────────────────────────────┤
│  Transport Layer | 传输层                               │
│  socket: TCP ServerSocket + UDP broadcast/multicast    │
│  webSocket: HttpServer + WebSocket + HTTP discovery    │
└───────────────────────────────────────────────────────┘
```

- **Room Discovery** — UDP broadcast/multicast (socket) or HTTP scan (WebSocket) | 房间发现
- **Reliability** — ACK + retry for critical messages | 关键消息确认重试
- **Reconnection** — Exponential backoff (1s→2s→4s→8s→16s, max 5 attempts) | 指数退避重连
- **Encryption** — XOR stream encryption with room-shared key | 数据加密传输

---

## 🔧 Technical Highlights | 技术亮点

### Minecraft 3D Engine | 3D 引擎

- Pure Dart software renderer — no OpenGL, no Vulkan | 纯 Dart 软渲染，无依赖
- Procedural world: 7 biomes via temperature/humidity noise | 基于温湿度噪声的 7 种生物群系
- Optimization: octree, back-face culling, frustum culling, occlusion culling, face merging | 八叉树+裁剪+面合并优化
- AABB collision detection, gravity, friction, jumping | AABB 碰撞+物理

> Full docs: [lib/13.minecraft/README.md](lib/13.minecraft/README.md)

### Soft Body Physics | 软体物理

- Spring-mass model with Hooke's law + damping | 弹簧-质点模型+胡克定律+阻尼
- Dual integration: Euler method and Verlet integration | 欧拉法和 Verlet 积分双方案
- 3D cylindrical tube structure with triangular mesh | 3D 圆柱体三角网格结构

### Elemental Battle RPG | 元素之战

- Five elements (Metal/Wood/Water/Fire/Earth) × 5 skill tiers | 五行 × 5 类技能
- 25 unique skills: passive, active, advanced, auxiliary, ultimate | 25 个独特技能
- Rich effect system: parry, lifesteal, enchant, counter, burn | 格挡/吸血/附魔/反击/灼烧等

### LAN Auto-Discovery | 局域网自动发现

- socket mode: UDP broadcast + multicast, zero-config | UDP 广播+组播，零配置
- webSocket mode: HTTP scan + WebSocket, browser multiplayer | HTTP 扫描+WebSocket，浏览器联机
- Dual NIC auto-traversal | 双网卡自动遍历

---

## 🚀 Quick Start | 快速开始

### Prerequisites | 前置条件

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.x

### Run | 运行

```bash
git clone https://github.com/rebort-a/treasure.git
cd treasure
flutter pub get
flutter run
```

### Build | 构建

```bash
# Web
flutter build web --release

# Android APK
flutter build apk --release

# Windows
flutter build windows --release

# iOS (requires macOS)
flutter build ios --release
```

---

## 📊 Stats | 项目数据

<p align="center">
  <table>
    <tr>
      <td align="center"><b>11</b><br/>Local Games</td>
      <td align="center"><b>5</b><br/>LAN Games</td>
      <td align="center"><b>5</b><br/>Platforms</td>
      <td align="center"><b>3</b><br/>Dependencies</td>
    </tr>
  </table>
</p>

---

## 📖 Documentation | 文档

| Module | Link |
|--------|------|
| 🧊 Minecraft 3D Engine | [lib/13.minecraft/README.md](lib/13.minecraft/README.md) |

---

## 📄 License | 开源协议

This project is licensed under the [MIT License](LICENSE).

本项目采用 [MIT 协议](LICENSE) 开源。

---

<p align="center">
  <i>Built with Flutter & curiosity. | 用 Flutter 和好奇心构建。</i><br/><br/>
  <b>⭐ If you find this interesting, give it a star! | 如果觉得有趣，点个 Star 吧！</b>
</p>
