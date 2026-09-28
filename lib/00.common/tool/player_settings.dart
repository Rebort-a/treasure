import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// 共用的本地玩家资料；名称为空时，在加入房间时询问名称。
class PlayerSettings {
  PlayerSettings._();
  static final PlayerSettings instance = PlayerSettings._();

  final ValueNotifier<String> defaultName = ValueNotifier('');

  Future<void> load() async {
    final data = await StorageService.instance.read('settings');
    defaultName.value = (data['defaultName'] as String? ?? '').trim();
  }

  Future<void> setDefaultName(String name) async {
    defaultName.value = name.trim();
    final data = await StorageService.instance.read('settings');
    data['defaultName'] = defaultName.value;
    await StorageService.instance.write('settings', data);
  }

  @visibleForTesting
  void resetForTesting() => defaultName.value = '';
}
