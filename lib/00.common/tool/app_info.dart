import 'package:package_info_plus/package_info_plus.dart';

/// 应用信息适配器
///
/// 通过 package_info_plus 读取打包时的应用版本号（来自 pubspec 的 version），
/// 隔离第三方插件 import，仅限本文件引用。失败时回退到空串。
class AppInfo {
  AppInfo._();

  static String? _version;
  static String? _buildNumber;
  static bool _loaded = false;

  /// 应用版本号（如 1.1.0），加载失败返回 null
  static String? get version => _version;

  /// 构建号（版本号 + 的部分，如 4），加载失败返回 null
  static String? get buildNumber => _buildNumber;

  /// 是否已成功加载
  static bool get isLoaded => _loaded;

  /// 加载应用信息（幂等）
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }
}
