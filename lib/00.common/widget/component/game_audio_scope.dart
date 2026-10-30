import 'dart:async';

import 'package:flutter/material.dart';

import '../../sound/sound_manager.dart';
import '../../sound/audio_preferences.dart';
import '../../sound/music_service.dart';
import '../../sound/sound_service.dart';

/// 音频生命周期跟随页面，不跟随 Manager 的计时器或网络连接。
class GameAudioScope extends StatefulWidget {
  final SoundEmitter source;
  final String project;
  final Widget child;
  final SoundPlayer<Sound>? player;
  final String? musicAsset;
  final Listenable? musicState;
  final bool Function()? isMusicPlaying;
  final MusicPlayer? musicPlayer;
  final AudioPreferences? preferences;

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
    this.preferences,
  });

  @override
  State<GameAudioScope> createState() => _GameAudioScopeState();
}

class _GameAudioScopeState extends State<GameAudioScope>
    with WidgetsBindingObserver {
  late SoundController<Sound> _audio;
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
    _audio = SoundController<Sound>(
      events: source.audioEvents,
      currentSound: () => source.audioEvents.value?.sound,
      resetSound: Sound.reset,
      project: widget.project,
      preferences: widget.preferences,
      minimumInterval: (sound) => switch (sound) {
        Sound.shoot => 110,
        Sound.hit || Sound.explosion => 140,
        Sound.tap => 45,
        _ => 90,
      },
      player:
          widget.player ??
          AssetSoundPlayer<Sound>(
            assets: {
              for (final sound in Sound.values)
                if (sound != Sound.reset) sound: sound.asset,
            },
          ),
    );
    final musicAsset = widget.musicAsset;
    if (musicAsset != null) {
      _music = BackgroundMusicController(
        project: widget.project,
        player: widget.musicPlayer ?? AssetMusicPlayer(musicAsset),
        preferences: widget.preferences,
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
        oldWidget.preferences != widget.preferences) {
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
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.musicState?.removeListener(_syncMusic);
    unawaited(_audio.dispose());
    unawaited(_music?.dispose());
    super.dispose();
  }
}
