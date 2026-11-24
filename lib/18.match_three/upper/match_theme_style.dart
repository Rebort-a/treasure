import 'package:material_ui/material_ui.dart';

import '../../00.common/l10n/strings.dart';
import '../base/match_board.dart';

extension MatchThemeStyle on MatchTheme {
  String get label => switch (this) {
    MatchTheme.classic => S.matchThemeClassic,
    MatchTheme.frost => S.matchThemeFrost,
    MatchTheme.lightning => S.matchThemeLightning,
    MatchTheme.rainbow => S.matchThemeRainbow,
  };

  IconData get icon => switch (this) {
    MatchTheme.classic => Icons.eco_rounded,
    MatchTheme.frost => Icons.ac_unit_rounded,
    MatchTheme.lightning => Icons.bolt_rounded,
    MatchTheme.rainbow => Icons.color_lens_rounded,
  };

  List<Color> get headerColors => switch (this) {
    MatchTheme.classic => const [Color(0xFF246D56), Color(0xFF469D78)],
    MatchTheme.frost => const [Color(0xFF215580), Color(0xFF367D9B)],
    MatchTheme.lightning => const [Color(0xFF69431C), Color(0xFF96622A)],
    MatchTheme.rainbow => const [Color(0xFF794477), Color(0xFF534A8C)],
  };

  Color get boardBorder => switch (this) {
    MatchTheme.classic => const Color(0xFF8BC7AE),
    MatchTheme.frost => const Color(0xFF74BDE5),
    MatchTheme.lightning => const Color(0xFFE7BA70),
    MatchTheme.rainbow => const Color(0xFFBBA6E9),
  };
}
