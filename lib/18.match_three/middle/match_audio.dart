import '../../00.common/service/sound_service.dart';
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
            if (sound != MatchSound.reset) sound: sound.asset,
        },
      );
}

class MatchAudioController extends SoundController<MatchSound> {
  final MatchManager manager;
  late final SoundController<ComboPraise> _praiseAudio;
  bool _pageActive = true;
  Future<void>? _disposingAll;

  MatchAudioController({
    required this.manager,
    MatchSoundPlayer? player,
    SoundPlayer<ComboPraise>? praisePlayer,
    super.store,
  }) : super(
         events: manager.sound,
         currentSound: () => manager.sound.value?.sound,
         player: player ?? MatchAssetSoundPlayer(),
         project: '18.match_three',
         resetSound: MatchSound.reset,
         minimumInterval: (sound) => sound == MatchSound.select ? 45 : 90,
       ) {
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
          ),
      project: '18.match_three',
      persistSettings: false,
      // 普通消除降低播报频率，高档赞美仍能及时打断低档赞美。
      minimumInterval: (praise) => switch (praise) {
        ComboPraise.good => 5000,
        ComboPraise.great => 1800,
        _ => 600,
      },
    );
    enabled.addListener(_syncPraise);
    manager.sound.addListener(_onGameSound);
    _syncPraise();
  }

  @override
  Future<void> get ready async {
    await Future.wait([super.ready, _praiseAudio.ready]);
  }

  void _syncPraise() => _praiseAudio.setActive(_pageActive && enabled.value);

  void _onGameSound() {
    if (manager.sound.value?.sound == MatchSound.reset) _praiseAudio.stop();
  }

  @override
  void setActive(bool active) {
    _pageActive = active;
    super.setActive(active);
    _syncPraise();
  }

  @override
  Future<void> dispose() => _disposingAll ??= _disposeAll();

  Future<void> _disposeAll() async {
    enabled.removeListener(_syncPraise);
    manager.sound.removeListener(_onGameSound);
    await Future.wait([_praiseAudio.dispose(), super.dispose()]);
  }
}
