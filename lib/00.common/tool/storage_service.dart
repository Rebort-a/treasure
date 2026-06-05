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

  late final Directory _baseDir;
  bool _initialized = false;

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

      _baseDir = Directory('${appDir.path}/.treasure');
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
