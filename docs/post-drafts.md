# 可复制的项目分享草稿

下列内容是草稿，不是已发布的帖子。发布前确认线上功能、素材版本和平台规则；不要宣称所有平台已完成实机验收，不要求用户先 Star 才能使用。

## 中文短帖：开发者社区

**标题：用 Flutter 做游戏实验室：Dart 体素渲染、局域网联机和多人合作三消**

我在整理一个开源项目 Treasure，想把游戏背后的规则和联机实现做成可阅读、可验证的案例。

它包含 16 款游戏和局域网聊天，比较有意思的几个部分是：

- 用 Dart 实现投影、裁剪与面合并，通过 Flutter Canvas 绘制体素场景；
- 双人回合、多人合作回合与实时联机共用房间连接，退出游戏后仍保留聊天室；
- 合作三消使用局面快照、修订号和应用层 ready，不把“消息 ACK 收到”当作“各设备状态已经一致”。

中文标语是“六端为一，无界互联”。不过跨平台能力有差异：Web 需要手动连接原生房间，受浏览器策略限制，当前也不持久化设置和记录。整个应用并非零依赖，游戏规则和渲染算法自研，便利插件集中在适配文件。

可以先打开浏览器玩单机，再看感兴趣模块的源码。欢迎告诉我哪段实现不好理解、哪个平台遇到了问题；如果对你有帮助，也欢迎 Star。

- 在线体验：https://rebort-a.github.io/treasure/
- 源码：https://github.com/Rebort-a/treasure

发布时附一段真实录屏，不把品牌示意图当作游戏画面。

## English short post: developer communities

**Title: An open-source Flutter game lab with Dart voxel rendering and LAN multiplayer**

I'm sharing Treasure, an open-source Flutter game lab with 16 games and LAN chat.

The parts I would particularly like feedback on are:

- A Dart voxel-rendering pipeline using Flutter Canvas, including projection, clipping, and face merging.
- Reusable room/game lifecycles for turn-based, cooperative, and real-time LAN play.
- Cooperative match-three synchronization using snapshots, revisions, and application-level readiness rather than treating a transport ACK as state agreement.

The project targets six platforms, but capabilities differ. Native clients host rooms; browsers join manually over WebSocket subject to browser restrictions. Web persistence is not implemented. Game rules and rendering algorithms are self-built; a few convenience plugins are isolated in adapters.

You can try the local games in your browser. I'd appreciate specific feedback on the implementation, documentation, or a reproducible issue.

Demo: https://rebort-a.github.io/treasure/
Source: https://github.com/Rebort-a/treasure

Before posting on Reddit or another community, verify its current promotion and showcase rules. This is a project introduction, not a disguised recommendation by an unrelated user.

## 技术文章提纲：ACK 不等于状态一致

**标题：Flutter 多人回合联机：为什么收到 ACK，棋盘仍可能不同步？**

1. 用两台设备的真实合作三消录屏说明问题。
2. 区分 TCP / WebSocket、应用层消息 ACK、游戏状态确认三个层次。
3. 解释 `gameId` 如何隔离旧对局、`revision` 如何拒绝迟到动作。
4. 展示发布者的快照与成员 ready 流程。
5. 解释退出与中途加入如何影响成员集合和下一步开放。
6. 用“ready 或动作首次丢失后重发仍只结算一次”的回归测试收尾。
7. 说明边界：本项目不是抗作弊服务，不提供安全加密传输，也没有把本地解帧微基准当作设备网络延迟。

源码入口：
- `lib/00.common/network/client/net_multi_turn_engine.dart`
- `lib/00.common/network/client/base/game_engine.dart`
- `test/18.match_three/network_test.dart`
- [现有联机流程说明](network-flow.md)

不要直接引用虚构的延迟、FPS 或用户数量。录屏和测量结果必须来自实际执行。

## 15～30 秒录屏脚本

任选一个主题，避免画面过多：

### 体素渲染

1. 0～5 秒：打开场景，显示标题“Dart + Flutter Canvas”。
2. 5～15 秒：移动视角与操作方块，让观众看到场景确实可交互。
3. 15～25 秒：展示裁剪/面合并开关或调试信息，仅解释实际存在的功能。
4. 末尾：在线体验和源码地址；不添加未经测量的帧率标语。

### 多人合作三消

1. 0～5 秒：同时展示两台设备，明确一台原生设备主持房间。
2. 5～20 秒：轮流完成动作，展示两个棋盘状态相同。
3. 20～30 秒：退出游戏返回聊天室，简述连接复用。

素材条件：真实设备或真实运行实例、录屏工具、隐藏私人信息。现有 GIF 可以作为历史演示补充，但新发帖优先录制当前版本。

## 联系技术周刊或社区编辑

**邮件主题：开源项目投稿：Treasure 的 Dart 体素渲染与局域网联机案例**

你好，我想为贵栏目的 Flutter / 游戏开发方向提供一个开源案例。

Treasure 是一个 Flutter 游戏实验室，主要特色是 Dart 自研游戏规则、Canvas 体素渲染和可复用的局域网联机生命周期，提供在线单机体验与实现说明。

源码：https://github.com/Rebort-a/treasure
体验：https://rebort-a.github.io/treasure/

如果与选题匹配，我可以补充一段当前版本录屏和针对联机状态同步的技术讲解。也欢迎直接指出不符合收录条件的地方。谢谢。

仅发送给接受此类投稿的公开栏目，不批量抓取地址，不重复催促，也不付费购买“保证收录”。

## Awesome Flutter 候选条目

截至 2026-10-08，该合集贡献指南要求至少 35 Star。未达到条件时先不提交；达到后检查最新指南和分类，编辑 `source.md` 而不是 README。

候选描述按其格式准备，不在说明里重复 “Flutter”：

```markdown
[Treasure](https://github.com/Rebort-a/treasure) - Game lab with local and LAN multiplayer, readable Dart game cores, and a voxel renderer by [Rebort-a](https://github.com/Rebort-a).
```

建议 PR 标题：`Add Treasure game lab`

只有被实际收录后才能使用 Awesome Flutter 收录徽章。门槛不是购买 Star 的理由。
