import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// 共用的本地玩家资料；名称为空时，在加入房间时询问名称。
class PlayerSettings {
  PlayerSettings._();
  static final PlayerSettings instance = PlayerSettings._();

  final ValueNotifier<String> defaultName = ValueNotifier('');
  Future<void>? _loadFuture;

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final data = await StorageService.instance.read('settings');
    final name = data['defaultName'];
    defaultName.value = name is String ? name.trim() : '';
  }

  Future<void> setDefaultName(String name) async {
    await load();
    defaultName.value = name.trim();
    final value = defaultName.value;
    try {
      await StorageService.instance.update('settings', (data) {
        data['defaultName'] = value;
      });
    } catch (error) {
      debugPrint('[PlayerSettings] Save failed: $error');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _loadFuture = null;
    defaultName.value = '';
  }
}
