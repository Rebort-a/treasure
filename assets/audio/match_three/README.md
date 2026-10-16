# 消消乐音效

本目录的 16 个 WAV 音效均由项目内的 Dart 脚本原创合成，不包含第三方录音、采样或语音，沿用项目许可证。

在项目根目录重新生成：

```sh
dart run scripts/generate_match_audio.dart
```

格式为 22,050 Hz、单声道、16 位 PCM WAV。四档消除音随连锁升高；行列、炸弹、彩虹、碎冰与结算分别使用独立音色。英文赞美语音位于相邻的 `match_praise` 目录，使用独立播放器，不包含第三方游戏录音。

音效与赞美语音共用静音开关，设置保存于 `18.match_three/audio`。原生端复用项目 JSON 存储，Web 音频设置使用浏览器 localStorage；存储不可用时游戏仍可正常运行。
