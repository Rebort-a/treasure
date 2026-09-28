/// 第 [attempt] 次重连前的指数退避：1、2、4、8、16 秒。
Duration reconnectDelayForAttempt(int attempt, {int maxExponent = 4}) {
  if (attempt < 0) {
    throw ArgumentError.value(attempt, 'attempt', 'must be non-negative');
  }
  final exponent = attempt > maxExponent ? maxExponent : attempt;
  return Duration(seconds: 1 << exponent);
}
