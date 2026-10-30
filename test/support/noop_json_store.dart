import 'package:treasure/00.common/service/json_store.dart';

/// 不持久化的测试存储，隔离与当前测试无关的配置加载和保存。
class NoopJsonStore implements JsonStore {
  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async => {};

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {}
}
