import 'generate_match_audio.dart' as synthesis;

/// 通用游戏音效与三消音效共用合成器，但保留独立的音色和资源目录。
void main() => synthesis.main(['--common']);
