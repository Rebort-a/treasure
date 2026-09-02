import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 本地 JSON 文件存储服务
///
/// 使用 path_provider 获取平台专属目录：
/// - Android: 应用内部存储/.treasure/
/// - iOS: Documents/.treasure/
/// - Windows/Linux/macOS: 当前目录/.treasure/
/// - Web: 不支持，自动跳过
class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  late Directory _baseDir;
  bool _initialized = false;

  /// 覆盖存储目录，仅用于测试隔离。
  ///
  /// 测试可将其指向独立临时目录，避免与真实 `.treasure/` 数据及并发测试
  /// 共享同一份文件而竞态。设置后 [init] 优先使用该目录。
  @visibleForTesting
  Directory? overrideBaseDir;

  /// 重置状态，仅用于测试
  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    // 兜底清理测试目录覆盖：若测试遗漏 tearDown，避免泄漏到下一测试用例
    overrideBaseDir = null;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        _initialized = true;
        return;
      }

      Directory appDir;
      if (Platform.isAndroid || Platform.isIOS) {
        appDir = await getApplicationDocumentsDirectory();
      } else {
        appDir = Directory.current;
      }

      _baseDir = overrideBaseDir ?? Directory('${appDir.path}/.treasure');
      if (!await _baseDir.exists()) {
        await _baseDir.create(recursive: true);
      }
      _initialized = true;
      debugPrint('[Storage] Initialized at: ${_baseDir.path}');
    } catch (e) {
      debugPrint('[Storage] Init failed: $e');
    }
  }

  Future<Map<String, dynamic>> read(String name) async {
    if (kIsWeb || !_initialized) return {};
    try {
      final file = File('${_baseDir.path}/$name.json');
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Storage] Read $name failed: $e');
      return {};
    }
  }

  Future<void> write(String name, Map<String, dynamic> data) async {
    if (kIsWeb || !_initialized) return;
    try {
      final file = File('${_baseDir.path}/$name.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[Storage] Write $name failed: $e');
    }
  }

  Future<List<dynamic>> readList(String name) async {
    if (kIsWeb || !_initialized) return [];
    try {
      final file = File('${_baseDir.path}/$name.json');
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      return jsonDecode(content) as List<dynamic>;
    } catch (e) {
      debugPrint('[Storage] ReadList $name failed: $e');
      return [];
    }
  }

  Future<void> writeList(String name, List<dynamic> data) async {
    if (kIsWeb || !_initialized) return;
    try {
      final file = File('${_baseDir.path}/$name.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[Storage] WriteList $name failed: $e');
    }
  }

  Future<void> delete(String name) async {
    if (kIsWeb || !_initialized) return;
    try {
      final file = File('${_baseDir.path}/$name.json');
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[Storage] Delete $name failed: $e');
    }
  }
}
