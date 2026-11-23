import '../../00.common/sound/sound_service.dart';
import 'combo_praise.dart';
import 'match_manager.dart';
import 'match_sound.dart';

/// 保留三消的音效契约，播放与资源管理复用共享服务。
abstract interface class MatchSoundPlayer implements SoundPlayer<MatchSound> {}

class MatchAssetSoundPlayer extends AssetSoundPlayer<MatchSound>
    implements MatchSoundPlayer {
  MatchAssetSoundPlayer()
    : super(
        assets: {
          for (final sound in MatchSound.values)
            if (sound != MatchSound.reset && sound != MatchSound.win)
              sound: sound.asset,
        },
      );
}

class MatchAudioController extends SoundController<MatchSound> {
  final MatchManager manager;
  late final SoundController<MatchSound> _winAudio;
  late final SoundController<ComboPraise> _praiseAudio;
  late final SoundController<MatchSound> _bonusAudio;
  bool _pageActive = true;
  Future<void>? _disposingAll;

  MatchAudioController({
    required this.manager,
    MatchSoundPlayer? player,
    SoundPlayer<MatchSound>? winPlayer,
    SoundPlayer<ComboPraise>? praisePlayer,
    SoundPlayer<MatchSound>? bonusPlayer,
    super.store,
    super.preferences,
  }) : super(
         events: manager.sound,
         currentSound: () {
           final sound = manager.sound.value?.sound;
           return sound == MatchSound.win ? null : sound;
         },
         player: player ?? MatchAssetSoundPlayer(),
         project: '18.match_three',
         resetSound: MatchSound.reset,
         deferUntilReady: (sound) =>
             sound == MatchSound.entrance || sound == MatchSound.appear,
         minimumInterval: (sound) => sound == MatchSound.select ? 45 : 90,
       ) {
    _winAudio = SoundController<MatchSound>(
      events: manager.sound,
      currentSound: () =>
          manager.sound.value?.sound == MatchSound.win ? MatchSound.win : null,
      player:
          winPlayer ??
          AssetSoundPlayer<MatchSound>(
            assets: {MatchSound.win: MatchSound.win.asset},
            voiceCount: 1,
            latestOnly: true,
            waitForCompletion: true,
          ),
      project: '18.match_three',
      preferences: audioPreferences,
      minimumInterval: (_) => 0,
      onPlayback: (_, playback) => manager.trackWinPlayback(playback),
    );
    _praiseAudio = SoundController<ComboPraise>(
      events: manager.praiseVoice,
      currentSound: () => manager.praiseVoice.value?.praise,
      player:
          praisePlayer ??
          AssetSoundPlayer<ComboPraise>(
            assets: {
              for (final praise in ComboPraise.values) praise: praise.asset,
            },
            voiceCount: 1,
            volume: .95,
            latestOnly: true,
            waitForCompletion: true,
          ),
      project: '18.match_three',
      preferences: audioPreferences,
      channel: SoundChannel.voice,
      // 每次结算发布一次事件，连续操作的播报不设间隔。
      minimumInterval: (_) => 0,
      onPlayback: (_, playback) => manager.trackPraisePlayback(playback),
    );
    _bonusAudio = SoundController<MatchSound>(
      // 奖励阶段包含多个转换帧，只在进入阶段时播报一次。
      events: manager.bonusTime,
      currentSound: () => manager.bonusTime.value ? MatchSound.bonus : null,
      player:
          bonusPlayer ??
          AssetSoundPlayer<MatchSound>(
            assets: const {MatchSound.bonus: 'audio/voice/bonus_time.wav'},
            voiceCount: 1,
            volume: .95,
            latestOnly: true,
            waitForCompletion: true,
          ),
      project: '18.match_three',
      preferences: audioPreferences,
      channel: SoundChannel.voice,
      minimumInterval: (_) => 0,
      onPlayback: (_, playback) => manager.trackBonusPlayback(playback),
    );
    manager.bonusTime.addListener(_syncVoices);
    manager.sound.addListener(_onSound);
    _syncVoices();
  }

  @override
  Future<void> get ready async {
    await Future.wait([
      super.ready,
      _winAudio.ready,
      _praiseAudio.ready,
      _bonusAudio.ready,
    ]);
  }

  void _syncVoices() {
    final active = _pageActive;
    // 胜利音效可与本手赞美并行，奖励语音则在赞美结束后独占语音通道。
    _praiseAudio.setActive(active && !manager.bonusTime.value);
    _bonusAudio.setActive(active);
  }

  void _onSound() {
    if (manager.sound.value?.sound == MatchSound.reset) {
      _winAudio.stop();
      _praiseAudio.stop();
      _bonusAudio.stop();
    }
  }

  @override
  void setActive(bool active) {
    _pageActive = active;
    super.setActive(active);
    _winAudio.setActive(active);
    _syncVoices();
  }

  @override
  Future<void> dispose() => _disposingAll ??= _disposeAll();

  Future<void> _disposeAll() async {
    manager.bonusTime.removeListener(_syncVoices);
    manager.sound.removeListener(_onSound);
    await Future.wait([
      _winAudio.dispose(),
      _praiseAudio.dispose(),
      _bonusAudio.dispose(),
      super.dispose(),
    ]);
  }
}
