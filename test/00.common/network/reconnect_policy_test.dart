import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/network/reconnect_policy.dart';

void main() {
  test('指数退避为 1/2/4/8/16 秒，并在上限封顶', () {
    expect(List.generate(7, (i) => reconnectDelayForAttempt(i).inSeconds), [
      1,
      2,
      4,
      8,
      16,
      16,
      16,
    ]);
    expect(() => reconnectDelayForAttempt(-1), throwsArgumentError);
  });
}
