# 消消乐音效

本目录的 17 个 WAV 音效均由项目内的 Dart 脚本原创合成，不包含第三方录音、采样或语音，沿用项目许可证。

在项目根目录重新生成：

```sh
dart run scripts/generate_match_audio.dart
```

格式为 22,050 Hz、单声道、16 位 PCM WAV。四档消除音随连锁升高；行列、炸弹、彩虹、碎冰与结算分别使用独立音色。`appear.wav` 用于开局、重开及全盘补齐动物，普通补块仍使用 `fall.wav`。英文赞美与 Bonus Time 语音位于相邻的 `match_praise` 目录，使用独立播放器，不适用本目录的原创素材声明。

消除与入场音效跟随首页设置页的“音效”开关，英文赞美和 Bonus Time 由独立的“播报”开关控制；所有游戏共享 `00.common/audio`、`00.common/voice` 设置，不再在游戏页面放置独立按钮。原生端复用项目 JSON 存储，Web 设置使用浏览器 localStorage；存储不可用时游戏仍可正常运行。
