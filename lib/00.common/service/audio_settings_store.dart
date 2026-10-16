import 'json_store.dart';
import 'storage_service.dart';
import 'web_audio_settings_stub.dart'
    if (dart.library.js_interop) 'web_audio_settings.dart'
    as browser;

/// 原生端沿用项目文件存储，Web 音频设置单独保存到浏览器。
class AudioSettingsStore implements JsonStore {
  const AudioSettingsStore();

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async => browser.available
      ? browser.read('$project/$name')
      : StorageService.instance.read(name, project: project);

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {
    if (browser.available) {
      browser.write('$project/$name', data);
    } else {
      await StorageService.instance.write(name, data, project: project);
    }
  }
}
