import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/sound/sound_manager.dart';
import 'package:treasure/18.match_three/middle/combo_praise.dart';
import 'package:treasure/18.match_three/middle/match_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('游戏引用的音效、播报与背景音乐可从资源包加载', () async {
    final assets = {
      for (final sound in Sound.values)
        if (sound != Sound.reset) sound.asset,
      for (final sound in MatchSound.values)
        if (sound != MatchSound.reset) sound.asset,
      for (final praise in ComboPraise.values) praise.asset,
      'audio/voice/bonus_time.wav',
      'audio/music/spaceship.wav',
      'audio/music/tank.wav',
    };
    for (final asset in assets) {
      final data = await rootBundle.load('assets/$asset');
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });
}
