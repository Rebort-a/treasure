# 项目分享与曝光

目标是让合适的开发者和玩家发现 Treasure、愿意体验并给出反馈，而不是保证某个 Star 数。先用真实内容和免费渠道验证兴趣，不买 Star、不群发广告，也不把技术探索宣传成已经完成全部实机验收的商业产品。

## 一、已经准备好的素材

- README 中的在线体验、原生下载、反馈和贡献入口。
- `.github/social-preview.png`：1280 × 640 的品牌分享图，适合上传到 GitHub 仓库设置。
- `web/social-preview.png`：相同图片随 Web 构建发布，供体验页的 Open Graph / Twitter Card 使用。
- `web/index.html`：明确的标题、描述、canonical 和分享元信息。没有加入广告或访客追踪脚本。
- `.github/ISSUE_TEMPLATE/` 与 PR 模板：降低反馈和第一次贡献的成本。
- `.github/repository-metadata.json`：手动设置 About 时可复制的描述、体验网址和 Topics；不是 GitHub 自动读取的配置。
- [中英文发帖草稿](post-drafts.md)：短帖、技术文章提纲、社区投稿与联系编辑的模板。

这些文件目前只是仓库中的准备工作。提交、推送和部署后才会对外生效；GitHub 仓库的 About / Topics / 分享图不会因为提交一个 JSON 或 PNG 文件就自动改变。

## 二、最优先的 GitHub 设置

需要：有仓库管理权限的 GitHub 账号。建议预算：0。

1. 在仓库 About 中填写体验网址和具体描述，而不只写 “games, tools & experiments”。
2. 添加相关 Topics，优先 `flutter`、`dart`、`multiplayer`、`lan`、`voxel`、`flutter-games`。不要用不相关的热门标签。
3. 在仓库 Settings 的 Social preview 上传 `.github/social-preview.png`。
4. 将仓库固定到自己的 GitHub 个人主页。
5. 发帖前打开线上体验和 Releases，确认描述与实际可用版本一致。本地 `pubspec.yaml` 版本号不代表同名 Release 已对外发布。

Topics 会出现在主题页并可被用于仓库搜索，但不保证获得推荐。Social preview 的上传规则和入口见 [GitHub 官方说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview)。

### 手动设置 About 与 Topics

不需要安装命令行工具，也不需要提供 Token：

1. 登录 GitHub，打开 `Rebort-a/treasure` 仓库首页。
2. 点击右侧 **About** 旁的齿轮。
3. **Description** 填入：

   ```text
   Flutter game lab with 16 games, LAN multiplayer, and a Dart voxel renderer. Explore readable game rules and reusable networking.
   ```

4. **Website** 填入：

   ```text
   https://rebort-a.github.io/treasure/
   ```

5. 在 **Topics** 中逐个添加以下标签，保留已经存在且相关的标签：

   ```text
   flutter
   dart
   flutter-games
   game-development
   multiplayer
   lan
   cross-platform
   voxel
   open-source
   educational
   ```

6. 点击 **Save changes**。标签应使用小写字母、数字或连字符，每个不超过 50 个字符，总数不超过 20 个。

### 手动上传分享图与置顶仓库

1. 打开仓库 **Settings**，找到 **Social preview**。
2. 点击 **Edit → Upload an image…**，选择本地 `.github/social-preview.png`。
3. 检查预览；当前图片为 1280 × 640，文件小于 1 MB。
4. 打开自己的 GitHub 个人主页，点击 **Customize your pins**，选择 Treasure 并保存。

分享图是品牌示意图，不是伪造的游戏运行截图。以后需要修改时，使用图片编辑器导出 1280 × 640 的 PNG，并把同一份文件分别保存为 `.github/social-preview.png` 和 `web/social-preview.png`；测试会检查两份内容一致。更新本地 PNG 后，仓库 Settings 中的分享图仍需重新上传。

### 手动发布展示更新

经维护者确认提交和推送后，现有 CI 会构建 Web，并在 main 的普通提交上部署 GitHub Pages。不需要为了本次展示更新增加版本号或创建 Release。

部署完成后检查：

- 体验首页能正常打开；
- `https://rebort-a.github.io/treasure/social-preview.png` 能访问；
- 体验页源代码包含 `og:image` 等分享信息；
- Issue 入口出现问题反馈和贡献建议表单。

对外发帖需要用户自行登录目标平台。可以复制 [发帖草稿](post-drafts.md)，配上真实运行录屏后手动发布。仓库不会自动登录社交账号、投稿、发帖或执行推广脚本。

## 三、优先推广什么

不要只发“我做了十几个小游戏，求 Star”。每次选一个能看懂、能验证的主题：

| 主题 | 适合的素材 |
|---|---|
| Dart + Canvas 体素渲染 | 15～30 秒真实运行视频，附投影、裁剪、面合并的源码入口 |
| 多人合作三消 | 两台真实设备同步操作，附快照、修订号、ready 与 ACK 的区别 |
| 聊天室进入游戏再返回 | 展示连接复用与资源释放，附相关回归测试 |
| 一个可复现的联机 Bug 如何修复 | 问题、最小复现、修复思路和测试，避免曝光私人日志 |

宣传可以保留“六端为一，无界互联”，但正文仍说明 Web 不能主持房间、需要手动连接且当前不持久化。不要用 CPU 微基准宣称 UI 帧率，也不要把 XOR 称为安全通信。

## 四、渠道与所需条件

下表的预算是本项目建议投入，不是对平台收费规则的保证。账号发帖资格、审核和社区规则以发布时为准；若必须购买资格，初期可以直接跳过该渠道。

| 渠道 | 优先级 | 所需条件 | 建议预算与做法 |
|---|---|---|---|
| GitHub About / Topics / 个人主页置顶 | 最高 | GitHub 账号、相应仓库权限 | 0；一次配置 |
| 掘金、V2EX 分享创造等中文开发者社区 | 高 | 有发帖资格的账号、一篇真实技术分享 | 先不付费；选一个熟悉的平台，不同时复制刷屏 |
| r/FlutterDev、DEV Community 等英文开发者社区 | 高 | 平台账号、英文草稿、遵守当期规则 | 先不付费；讲实现和限制，并说明是自己的项目 |
| Bilibili 或自己的短视频账号 | 中 | 账号、录屏素材；必要时完成平台认证 | 先不付费；录一次真实演示，剪成短视频 |
| 熟悉的 Flutter 群、同事或开发者朋友 | 中 | 合适的群或联系人、允许分享 | 0；先邀请少量人实际体验，不要求互刷 Star |
| 技术周刊、社区编辑 | 中 | 对方接受投稿、公开联系方式、简洁邮件 | 先不付费；只投确实匹配的栏目，不群发 |
| Awesome Flutter 等资源合集 | 后续 | GitHub 账号，满足收录条件并提交合规 PR | 不付费、不保证收录；先检查指南 |
| GitHub Sponsors / 付费广告 / 付费评测 | 暂缓 | 额外平台资格或预算 | 初期不需要；收到真实反馈后再考虑 |

### Awesome Flutter 的明确门槛

截至 2026-10-08，[Solido/awesome-flutter 的贡献指南](https://github.com/Solido/awesome-flutter/blob/master/contributing.md)写明申请至少需要 **35 Star**，并要求编辑来源清单而不是生成的 README，提供清晰介绍和动图。实际文件名是 `source.md`；投稿前再检查最新规则和目录。

目前不应把它作为冷启动第一步，也不应为了跨过门槛购买 Star。草稿已经准备好，达到条件后再按指南提交；没有获收录前，不添加“已被 Awesome Flutter 收录”的徽章。

### 账号与费用底线

- 我不能在没有登录态的情况下改远程设置或对外投稿。
- 不需要为这轮本地改进购买域名、服务器、AI 服务或广告。
- 不向任何人购买 Star、Fork、Watch、虚假评价或“保证收录”服务。
- 账号认证、邀请码或广告费用如有要求，由用户自行确认和决定，不能默认代付。
- 不把访问令牌、验证码或账号密码写进配置文件；以上网页操作只需在 GitHub 自行登录。

## 五、一次低成本的发布节奏

1. **准备日**：更新 About、上传分享图、置顶仓库；确认线上体验和下载正常。
2. **内容日**：录一段最有特色的真实演示，选体素渲染或合作三消，而不是十几个页面快速切换。
3. **首发日**：只选一个社区发布技术分享，明确反馈问题，例如“哪一步最难理解或无法连接？”。
4. **反馈日**：回复评论、复现问题、补文档；不要只对评论重复贴 GitHub 链接。
5. **复用日**：结合反馈改写成另一种语言或另一种内容，不机械复制到所有平台。

这些是建议节奏，不是已经执行的活动。无需每日发帖，也不要保证一周能涨多少 Star。

## 六、如何判断有没有用

仓库维护者可以查看 GitHub Insights / Traffic，记录访客、来源和克隆；官方文档说明流量记录窗口为过去 14 天，建议定期保存观察结果。

| 日期 | 渠道与内容 | 实际帖子地址 | 访客变化 | Star 变化 | 有效反馈 |
|---|---|---|---|---|---|
| 待填写 | 待填写 | 待发布 | 待观察 | 待观察 | 待观察 |

优先看有没有人真正打开体验、提出问题或贡献，而不是只看 Star。来源归因只能作近似判断，不能把同一时间所有增长都认作某一篇文章带来的。

参考：
- [GitHub Topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics)
- [GitHub Traffic](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/viewing-traffic-to-a-repository)
- [Awesome Flutter 贡献指南](https://github.com/Solido/awesome-flutter/blob/master/contributing.md)
