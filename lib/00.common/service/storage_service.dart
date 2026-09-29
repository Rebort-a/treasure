import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 本地 JSON 文件存储服务。
///
/// 数据按项目保存在 `.treasure/<project>/<name>.json`。
class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  late Directory _baseDir;
  bool _initialized = false;

  /// 覆盖存储目录，仅用于测试隔离。
  @visibleForTesting
  Directory? overrideBaseDir;

  /// 重置状态，仅用于测试。
  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    overrideBaseDir = null;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        _initialized = true;
        return;
      }

      final Directory appDir;
      if (Platform.isAndroid || Platform.isIOS) {
        appDir = await getApplicationDocumentsDirectory();
      } else {
        appDir = Directory.current;
      }

      _baseDir = overrideBaseDir ?? Directory('${appDir.path}/.treasure');
      await _baseDir.create(recursive: true);
      _initialized = true;
      debugPrint('[Storage] Initialized at: ${_baseDir.path}');
    } catch (e) {
      debugPrint('[Storage] Init failed: $e');
    }
  }

  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async {
    if (kIsWeb || !_initialized) return {};
    try {
      final content = await _readContent(name, project);
      if (content == null) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Storage] Read $project/$name failed: $e');
      return {};
    }
  }

  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {
    if (kIsWeb || !_initialized) return;
    await _writeJson(name, data, project: project, operation: 'Write');
  }

  Future<List<dynamic>> readList(
    String name, {
    String project = '00.common',
  }) async {
    if (kIsWeb || !_initialized) return [];
    try {
      final content = await _readContent(name, project);
      if (content == null) return [];
      return jsonDecode(content) as List<dynamic>;
    } catch (e) {
      debugPrint('[Storage] ReadList $project/$name failed: $e');
      return [];
    }
  }

  Future<void> writeList(
    String name,
    List<dynamic> data, {
    String project = '00.common',
  }) async {
    if (kIsWeb || !_initialized) return;
    await _writeJson(name, data, project: project, operation: 'WriteList');
  }

  Future<String?> _readContent(String name, String project) async {
    final file = _file(name, project);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> _writeJson(
    String name,
    Object data, {
    required String project,
    required String operation,
  }) async {
    final projectDir = Directory('${_baseDir.path}/$project');
    final file = _file(name, project);
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final tmp = File('${projectDir.path}/.$name.$nonce.json.tmp');
    try {
      await projectDir.create(recursive: true);
      await tmp.writeAsString(jsonEncode(data));
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('[Storage] $operation $project/$name failed: $e');
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  File _file(String name, String project) =>
      File('${_baseDir.path}/$project/$name.json');

  Future<void> delete(String name, {String project = '00.common'}) async {
    if (kIsWeb || !_initialized) return;
    try {
      final file = _file(name, project);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[Storage] Delete $project/$name failed: $e');
    }
  }
}
