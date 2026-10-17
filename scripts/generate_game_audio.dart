import 'generate_match_audio.dart' as synthesis;

/// 生成通用游戏音效；三消复用其中的通用短提示，辨识性音效单独生成。
void main() => synthesis.main(['--common']);
