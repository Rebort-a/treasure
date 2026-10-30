import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'json_store.dart';

/// 本地 JSON 文件存储服务。
///
/// 数据按项目保存在 `.treasure/<project>/<name>.json`。
class StorageService implements JsonStore {
  static final StorageService instance = StorageService._();
  StorageService._();

  late Directory _baseDir;
  bool _initialized = false;
  final Map<(String, String), Future<void>> _writes = {};

  /// 覆盖存储目录，仅用于测试隔离。
  @visibleForTesting
  Directory? overrideBaseDir;

  /// 重置状态，仅用于已经等待所有读写完成的测试。
  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    overrideBaseDir = null;
    _writes.clear();
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

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async {
    if (kIsWeb || !_initialized) return {};
    try {
      return await _enqueue(name, project, () async {
        final content = await _readContent(name, project);
        return content == null
            ? <String, dynamic>{}
            : jsonDecode(content) as Map<String, dynamic>;
      });
    } catch (e) {
      debugPrint('[Storage] Read $project/$name failed: $e');
      return {};
    }
  }

  Future<T> _enqueue<T>(
    String name,
    String project,
    Future<T> Function() action,
  ) {
    final key = (project, name);
    final result = (_writes[key] ?? Future<void>.value()).then((_) => action());
    // 调用方仍得到本次失败，但失败不能阻断下一次保存。
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes[key] = tail;
    // 清理 Future 仅等待已捕获错误的队列尾部，不会再次传播保存错误。
    unawaited(
      tail.then((_) {
        if (identical(_writes[key], tail)) {
          _writes.remove(key);
        }
      }),
    );
    return result;
  }

  void _requireInitialized() {
    if (!_initialized) throw StateError('Storage is not initialized');
  }

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {
    if (kIsWeb) return;
    _requireInitialized();
    final content = jsonEncode(data);
    await _enqueue(name, project, () => _writeContent(name, content, project));
  }

  /// 同一文档的读、修改、写入串行执行；读取失败时不覆盖原有文件。
  Future<void> update(
    String name,
    void Function(Map<String, dynamic> data) change, {
    String project = '00.common',
  }) async {
    if (kIsWeb) return;
    _requireInitialized();
    await _enqueue(name, project, () async {
      final content = await _readContent(name, project);
      final data = content == null
          ? <String, dynamic>{}
          : jsonDecode(content) as Map<String, dynamic>;
      change(data);
      await _writeContent(name, jsonEncode(data), project);
    });
  }

  Future<List<dynamic>> readList(
    String name, {
    String project = '00.common',
  }) async {
    if (kIsWeb || !_initialized) return [];
    try {
      return await _enqueue(name, project, () async {
        final content = await _readContent(name, project);
        return content == null
            ? <dynamic>[]
            : jsonDecode(content) as List<dynamic>;
      });
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
    if (kIsWeb) return;
    _requireInitialized();
    final content = jsonEncode(data);
    await _enqueue(name, project, () => _writeContent(name, content, project));
  }

  Future<String?> _readContent(String name, String project) async {
    final file = _file(name, project);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> _writeContent(
    String name,
    String content,
    String project,
  ) async {
    final projectDir = Directory('${_baseDir.path}/$project');
    final file = _file(name, project);
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final tmp = File('${projectDir.path}/.$name.$nonce.json.tmp');
    try {
      await projectDir.create(recursive: true);
      await tmp.writeAsString(content);
      await tmp.rename(file.path);
    } finally {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (error) {
        debugPrint('[Storage] Temporary file cleanup failed: $error');
      }
    }
  }

  File _file(String name, String project) =>
      File('${_baseDir.path}/$project/$name.json');

  Future<void> delete(String name, {String project = '00.common'}) async {
    if (kIsWeb) return;
    _requireInitialized();
    await _enqueue(name, project, () async {
      final file = _file(name, project);
      if (await file.exists()) await file.delete();
    });
  }
}
