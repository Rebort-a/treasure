import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/03.animal_chess/local_manager.dart';

void main() {
  testWidgets('重开释放旧格子并使旧 AI 延迟失效', (tester) async {
    final manager = LocalManager();
    final previous = manager.displayMap.value.first;
    manager.toggleAiSwitch();
    manager.initGame();
    manager.toggleAiSwitch();
    final snapshot = manager.displayMap.value
        .map((cell) => cell.value.animal?.isHidden)
        .toList();
    expect(() => previous.addListener(() {}), throwsFlutterError);
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      manager.displayMap.value.map((cell) => cell.value.animal?.isHidden),
      snapshot,
    );
    manager.dispose();
    manager.dispose();
    expect(() => manager.currentGamer.addListener(() {}), throwsFlutterError);
    expect(() => manager.winner.addListener(() {}), throwsFlutterError);
    expect(() => manager.displayMap.addListener(() {}), throwsFlutterError);
  });
}
