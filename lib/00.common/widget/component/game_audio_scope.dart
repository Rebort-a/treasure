import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/game_sound.dart';
import '../../l10n/strings.dart';
import '../../service/json_store.dart';
import '../../service/music_service.dart';
import '../../service/sound_service.dart';

/// 音频生命周期跟随页面，不跟随 Manager 的计时器或网络连接。
class GameAudioScope extends StatefulWidget {
  final GameSoundEmitter source;
  final String project;
  final Widget child;
  final SoundPlayer<GameSound>? player;
  final String? musicAsset;
  final Listenable? musicState;
  final bool Function()? isMusicPlaying;
  final MusicPlayer? musicPlayer;
  final JsonStore? store;

  const GameAudioScope({
    super.key,
    required this.source,
    required this.project,
    required this.child,
    this.player,
    this.musicAsset,
    this.musicState,
    this.isMusicPlaying,
    this.musicPlayer,
    this.store,
  });

  @override
  State<GameAudioScope> createState() => _GameAudioScopeState();
}

class _GameAudioScopeState extends State<GameAudioScope>
    with WidgetsBindingObserver {
  late SoundController<GameSound> _audio;
  BackgroundMusicController? _music;
  bool _routeCurrent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  void _create() {
    final source = widget.source;
    _audio = SoundController<GameSound>(
      events: source.audioEvents,
      currentSound: () => source.audioEvents.value?.sound,
      resetSound: GameSound.reset,
      project: widget.project,
      store: widget.store,
      minimumInterval: (sound) => switch (sound) {
        GameSound.shoot => 110,
        GameSound.hit || GameSound.explosion => 140,
        GameSound.tap => 45,
        _ => 90,
      },
      player:
          widget.player ??
          AssetSoundPlayer<GameSound>(
            assets: {
              for (final sound in GameSound.values)
                if (sound != GameSound.reset) sound: sound.asset,
            },
          ),
    );
    final musicAsset = widget.musicAsset;
    if (musicAsset != null) {
      _music = BackgroundMusicController(
        project: widget.project,
        player: widget.musicPlayer ?? AssetMusicPlayer(musicAsset),
        store: widget.store,
      );
      widget.musicState?.addListener(_syncMusic);
      _syncMusic();
    }
    final state = WidgetsBinding.instance.lifecycleState;
    _setActive(
      _routeCurrent && (state == null || state == AppLifecycleState.resumed),
    );
  }

  void _syncMusic() =>
      _music?.setPlaying(widget.isMusicPlaying?.call() ?? true);

  void _setActive(bool active) {
    _audio.setActive(active);
    _music?.setActive(active);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 透明弹窗不打断结算音；被不透明页面覆盖时随 TickerMode 一同静音。
    _routeCurrent = TickerMode.valuesOf(context).enabled;
    final state = WidgetsBinding.instance.lifecycleState;
    _setActive(
      _routeCurrent && (state == null || state == AppLifecycleState.resumed),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setActive(_routeCurrent && state == AppLifecycleState.resumed);
  }

  @override
  void didUpdateWidget(GameAudioScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.project != widget.project ||
        oldWidget.player != widget.player ||
        oldWidget.musicAsset != widget.musicAsset ||
        oldWidget.musicPlayer != widget.musicPlayer ||
        oldWidget.store != widget.store) {
      oldWidget.musicState?.removeListener(_syncMusic);
      unawaited(_audio.dispose());
      unawaited(_music?.dispose());
      _music = null;
      _create();
    } else {
      if (oldWidget.musicState != widget.musicState && _music != null) {
        oldWidget.musicState?.removeListener(_syncMusic);
        widget.musicState?.addListener(_syncMusic);
      }
      _syncMusic();
    }
  }

  @override
  Widget build(BuildContext context) =>
      _AudioContext(audio: _audio, music: _music, child: widget.child);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.musicState?.removeListener(_syncMusic);
    unawaited(_audio.dispose());
    unawaited(_music?.dispose());
    super.dispose();
  }
}

class _AudioContext extends InheritedWidget {
  final SoundController<GameSound> audio;
  final BackgroundMusicController? music;

  const _AudioContext({
    required this.audio,
    required this.music,
    required super.child,
  });

  @override
  bool updateShouldNotify(_AudioContext oldWidget) =>
      audio != oldWidget.audio || music != oldWidget.music;
}

/// 音乐与音效独立控制，点击音乐按钮可调整开关和音量。
class GameMusicButton extends StatelessWidget {
  final Color? color;

  const GameMusicButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final music = context
        .dependOnInheritedWidgetOfExactType<_AudioContext>()
        ?.music;
    if (music == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: music.enabled,
      builder: (_, enabled, _) => IconButton(
        tooltip: S.backgroundMusic,
        icon: Icon(
          enabled ? Icons.music_note_rounded : Icons.music_off_rounded,
          color: color,
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => _MusicSettings(music: music),
        ),
      ),
    );
  }
}

class _MusicSettings extends StatelessWidget {
  final BackgroundMusicController music;

  const _MusicSettings({required this.music});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: music.enabled,
            builder: (_, enabled, _) => SwitchListTile(
              title: Text(S.backgroundMusic),
              value: enabled,
              onChanged: music.setEnabled,
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: music.volume,
            builder: (_, volume, _) => Row(
              children: [
                Text(S.musicVolume),
                Expanded(
                  child: Slider(
                    value: volume,
                    label: '${(volume * 100).round()}%',
                    onChanged: music.setVolume,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 放入现有工具栏，不新增遮挡棋盘或摇杆的悬浮控件。
class GameSoundButton extends StatelessWidget {
  final Color? color;

  const GameSoundButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final audio = context
        .dependOnInheritedWidgetOfExactType<_AudioContext>()
        ?.audio;
    if (audio == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: audio.enabled,
      builder: (_, enabled, _) => IconButton(
        tooltip: enabled ? S.muteGameSound : S.enableGameSound,
        icon: Icon(
          enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: color,
        ),
        onPressed: () => audio.setEnabled(!enabled),
      ),
    );
  }
}
