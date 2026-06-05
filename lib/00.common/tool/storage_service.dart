import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 本地 JSON 文件存储服务
///
/// 零依赖方案：使用 dart:io File 读写 JSON 文件。
/// 文件存储在应用运行目录下的 `.treasure/` 文件夹中。
///
/// 如需更可靠的移动端存储路径，可引入 `path_provider` 插件，
/// 将 _baseDir 改为 getApplicationDocumentsDirectory()。
class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  /// 存储根目录
  late final Directory _baseDir;

  /// 是否已初始化
  bool _initialized = false;

  /// 初始化存储目录
  Future<void> init() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        // Web 端不支持文件存储，跳过
        _initialized = true;
        return;
      }
      _baseDir = Directory('${Directory.current.path}/.treasure');
      if (!await _baseDir.exists()) {
        await _baseDir.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[Storage] Init failed: $e');
    }
  }

  /// 读取 JSON 文件，返回 Map，失败返回空 Map
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

  /// 写入 JSON 文件
  Future<void> write(String name, Map<String, dynamic> data) async {
    if (kIsWeb || !_initialized) return;
    try {
      final file = File('${_baseDir.path}/$name.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[Storage] Write $name failed: $e');
    }
  }

  /// 读取 JSON 列表文件，失败返回空列表
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

  /// 写入 JSON 列表文件
  Future<void> writeList(String name, List<dynamic> data) async {
    if (kIsWeb || !_initialized) return;
    try {
      final file = File('${_baseDir.path}/$name.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[Storage] WriteList $name failed: $e');
    }
  }

  /// 删除文件
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
