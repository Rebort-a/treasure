# 质量检查与平台验收

测试数量、可构建平台数量和产品可靠性不是同一个指标。这里记录可执行的门槛，并区分自动化验证与尚待实机确认的能力。

## 本地与 CI 的检查顺序

在仓库根目录执行，SDK 使用 `.fvmrc` 中的 Flutter 3.47.2：

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test scripts
flutter analyze lib
flutter test --coverage
dart run scripts/coverage_report.dart --check --json=coverage/summary.json
dart run scripts/benchmark.dart --json=build/quality/benchmark.json
flutter build web --release --base-href "/treasure/"
```

需要修正格式时使用 `dart format lib test scripts`。格式检查本身不改写文件。

CI 依次验证格式、静态分析、测试和关键模块覆盖率，上传覆盖率与微基准结果，然后构建 Web。发布流程额外构建原生平台；构建成功不是实机功能验收。

## 覆盖率口径

`scripts/coverage_report.dart`：

- 按文件和行合并 LCOV，避免重复记录导致分母重复。
- 兼容 Windows 和 Unix 路径。
- 排除生成的国际化代码、`.g.dart` 和 `.freezed.dart`。
- 输出模块统计与 JSON 文件。
- **只对 LCOV 提供的可执行行计算覆盖率**；未纳入 LCOV 的 Dart 文件单独列出，不能把它们算成已覆盖。
- 关键模块的源码文件若完全缺失 LCOV 记录，检查失败，防止通过漏报文件提高百分比。
- 门槛由 `scripts/coverage_thresholds.json` 管理，按原始实测基线留出小幅余量，不凭空要求整个历史代码库达到 90%。

首轮门槛与 2026-10-08 重构前的实测基线：

| 范围 | 原始行覆盖率 | CI 下限 |
|---|---:|---:|
| `00.common/network/` | 约 89.4% | 85% |
| `18.match_three/base/` | 约 96.8% | 95% |
| `18.match_three/middle/` | 约 88.9% | 85% |

这不是对其他模块测试充分性的背书。原始报告中，战机、塔防、软体模拟的行覆盖率明显偏低；优先补核心行为测试后，再逐步加入门槛。不要仅为通过 CI 下调门槛，任何调整都应说明测试或统计口径变化。

测试报告与覆盖率产物保留在 CI artifacts 中，当前统计值不硬编码为 README 徽章。

## CPU 微基准

```bash
dart run scripts/benchmark.dart --json=build/quality/benchmark.json
```

使用固定输入和校验和，预热后采集 7 个样本，记录 Dart 运行时、操作系统、每批耗时中位数和 P90：

| 基准 | 一批包含什么 |
|---|---|
| `match_three.generate_32` | 用种子 1～32 生成 32 个棋盘 |
| `match_three.snapshot_and_swap_32` | 还原 32 份固定快照，寻找并结算各自第一步合法动作 |
| `network.decode_fragmented_64k` | 将 64 KiB payload 的长度前缀消息按 113 字节切片解码 |
| `voxel.project_4096_vertices` | 对 4096 个固定顶点执行透视矩阵变换与除法 |

单位是 **微秒/批**，不能当作单个交换、顶点或字节的耗时。TCP 基准是本地解帧，不是设备间延迟；顶点变换不包含 Canvas 绘制、完整裁剪或 UI 帧率。

CI 只记录性能趋势，不用共享运行器的绝对耗时门槛阻断提交。比较时保持硬件、运行时、JIT/AOT 模式和电源状态一致。需要正式帧率结论时，应使用原生端 profile 构建，在同一场景记录帧时间、对象规模和设备信息。

## 实机检查清单

以下清单是待执行的验收步骤，不是已经通过的声明。每次记录应包含提交版本、设备、系统、网络环境、实际结果与日志。

### 通用

- [ ] 冷启动、主题和语言切换。
- [ ] 进入游戏、应用内返回、系统返回、重复进入，检查连接和资源是否正确释放。
- [ ] 前后台切换与窗口调整，无重复计时器或监听器。
- [ ] 横竖屏、窄窗口、键盘/鼠标和触摸输入。
- [ ] 原生端重启后验证设置与游戏记录；Web 明确不持久化。

### 局域网

- [ ] 至少两台真实设备；记录房主地址、权限、防火墙与广播是否可用。
- [ ] 原生端发现和手动输入地址加入。
- [ ] Web 手动连接原生房间，确认浏览器安全策略是否允许。
- [ ] 密码错误、密码正确、成员退出、房主退出。
- [ ] 断网和重连，旧对局消息不能进入新局。
- [ ] 双人回合、多人合作回合、实时游戏各完成一局。
- [ ] 退出单局后仍留在聊天室，连接没有被关闭。
- [ ] 多人合作中途加入及发布者退出后接管，设备显示同一局面。

### 发布与展示

- [ ] 发布包在目标设备安装并实际启动，而不是只验证构建退出码。
- [ ] 新截图来自真实运行结果，隐藏调试标记和开发工具背景。
- [ ] 静态截图、应用清单、SDK 版本和平台说明与当前版本一致。
- [ ] 不将历史截图、合成图或尚未执行的步骤标为当前验收结果。

当前 README 的静态预览由原有截图裁剪，标明历史版本；没有生成或伪造“新版 UI”。
