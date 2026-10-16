# 三消英文赞美语音

五档赞美保持 `Good!`、`Great!`、`Excellent!`、`Amazing!`、`Unbelievable!`，另有进入奖励阶段时播放的 `Bonus Time!`。不随界面语言切换。

## 来源与使用范围

当前六段录音由用户下载后提供。

`sources.json` 记录原始 MP3 文件名、SHA-256、目标资源和处理参数。
| 原始文件 | 应用资源 | 触发 |
| --- | --- | --- |
| `good.mp3` | `good.wav` | Good 赞美 |
| `great.mp3` | `great.wav` | Great 赞美 |
| `excellent.mp3` | `excellent.wav` | Excellent 赞美 |
| `amazing.mp3` | `amazing.wav` | Amazing 赞美 |
| `unbelievable.mp3` | `unbelievable.wav` | Unbelievable 赞美 |
| `bonus.mp3` | `bonus.wav` | 进入奖励阶段一次 |

## 导入

在安装了 FFmpeg 的 PowerShell 中运行：

```powershell
powershell -NoProfile -File scripts/import_match_voice.ps1
# 也可显式指定源目录与 FFmpeg 可执行文件：
powershell -NoProfile -File scripts/import_match_voice.ps1 -SourceDirectory temp -Ffmpeg C:\tools\ffmpeg.exe
```

脚本验证六个 MP3 均存在，并先完成所有转换，再替换应用资源。仅裁减首尾静音、加入极短淡入淡出以避免边界爆音，以及按 -18 LUFS / -1 dBTP 目标对齐响度（优先限制峰值）；不改变原录音的音高、语速或词间停顿。输出为 44,100 Hz、单声道、16 位 PCM WAV。游戏运行不依赖 FFmpeg、TTS 或网络服务。

旧的 `scripts/generate_match_praise.ps1` 仍可生成 Windows Zira 合成语音作为开发对照，但默认输出到 `temp/match_praise_tts/`，不覆盖这里的配音。

## 播放

赞美和 Bonus Time 分别使用独立单声道播放器，不会被棋子消除音效抢占。普通赞美保留冷却时间；进入奖励阶段时停止并屏蔽赞美，Bonus Time 只随阶段入口播放，不因后续步数转换帧而重播。

语音跟随全局“音效与语音”开关；静音、重开、同步重置、切后台和退出时取消旧语音。刷新视图、重复快照、重新开启音效或恢复前台不补播，语音不写入棋盘或网络协议。
