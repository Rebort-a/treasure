# 三消英文赞美语音

固定五档英文：`Good!`、`Great!`、`Excellent!`、`Amazing!`、`Unbelievable!`。不随中文或英文界面切换，不使用《开心消消乐》的录音或采样。

当前素材使用 Windows 内置的 Microsoft Zira Desktop 英文音色离线合成，非真人配音。生成脚本仅用于开发，游戏运行不依赖 Windows 语音接口、系统 TTS 或网络服务。系统音色及其生成输出的使用须遵循相应供应商条款；项目不宣称拥有系统音色本身的权利。

在安装了该英文音色的 Windows PowerShell 中重新生成：

```powershell
powershell -NoProfile -File scripts/generate_match_praise.ps1
```

也可通过 `-VoiceName` 指定其他已安装的英文 Windows 音色。输出格式为 22,050 Hz、单声道、16 位 PCM WAV，已裁去多余首尾静音。正式配音可以直接替换同名 WAV 文件。

语音使用独立单声道播放器，新的赞美替换旧的赞美，消除音效不会打断语音。低档播报具有冷却时间；静音、重新开局、同步重置、切后台和退出时取消旧语音。仅由展示事件触发，不写入棋盘或网络协议。
