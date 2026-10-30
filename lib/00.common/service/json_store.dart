/// 游戏逻辑依赖的 JSON 对象存储契约，不暴露文件或插件实现。
abstract interface class JsonStore {
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  });

  /// 写入失败须通过 Future 传播；不支持持久化的平台允许明确的空操作。
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  });
}
