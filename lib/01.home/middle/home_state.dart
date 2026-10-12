import 'package:flutter/foundation.dart';

import '../../00.common/model/app_item_type.dart';
import '../../00.common/model/notifiers.dart';
import '../../00.common/service/storage_service.dart';

/// 首页的可观察状态，不持有界面上下文或页面控制器。
class HomeState {
  final ValueNotifier<int> selectedTab = ValueNotifier(0);
  final ValueNotifier<String> searchQuery = ValueNotifier('');
  final ListNotifier<AppItemType> recentApps = ListNotifier([]);
  final ValueNotifier<bool> changingBackground = ValueNotifier(false);
  bool _disposed = false;
  bool _recentAppsChanged = false;

  bool get isDisposed => _disposed;

  Future<void> loadRecentApps() async {
    final list = await StorageService.instance.readList(
      'recent_apps',
      project: '01.home',
    );
    // 读取期间用户可能已打开应用，不能用旧记录覆盖新记录。
    if (_disposed || _recentAppsChanged) return;
    recentApps.value = list
        .whereType<String>()
        .map((key) {
          for (final item in AppItemType.values) {
            if (item.name == key) return item;
          }
          return null;
        })
        .whereType<AppItemType>()
        .toSet()
        .take(3)
        .toList();
  }

  Future<void> rememberApp(AppItemType item) async {
    _recentAppsChanged = true;
    recentApps.value = [
      item,
      ...recentApps.value.where((other) => other != item),
    ].take(3).toList();
    await StorageService.instance.writeList(
      'recent_apps',
      recentApps.value.map((item) => item.name).toList(),
      project: '01.home',
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    selectedTab.dispose();
    searchQuery.dispose();
    recentApps.dispose();
    changingBackground.dispose();
  }
}
